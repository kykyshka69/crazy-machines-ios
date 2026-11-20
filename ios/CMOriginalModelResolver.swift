import Foundation

/// Resolves 3DO references to user-imported UCM assets without fuzzy matches.
/// An explicit model name is resolved only to the same basename, optionally
/// with the .ucm extension. Duplicate basenames are treated as ambiguous.
enum CMOriginalModelResolver {
    static func modelNames(in node: CMOriginalSceneDocument.Node) -> [String] {
        var result: [String] = []
        func visit(_ item: CMOriginalSceneDocument.Node) {
            if let models = item.models { result.append(contentsOf: models) }
            // Each 3DO node contributes exactly one original model reference.
            // Recurse into its children, but never append that same 3DO again
            // from its parent; older exports can also list it in models.
            if item.name.hasPrefix("3DO ") {
                result.append(String(item.name.dropFirst(4)))
            }
            for child in item.children { visit(child) }
        }
        visit(node)
        var seen = Set<String>()
        return result.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Index imported original meshes once for a whole level. Duplicate names
    /// remain ambiguous and are never resolved to an arbitrary file.
    struct AssetIndex {
        private let filesByBaseName: [String: [URL]]

        init(directory: URL) {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            var index: [String: [URL]] = [:]
            for file in files where file.pathExtension.lowercased() == "ucm" {
                guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let key = file.deletingPathExtension().lastPathComponent.lowercased()
                index[key, default: []].append(file)
            }
            filesByBaseName = index
        }

        func resolve(_ modelName: String) -> URL? {
            let name = modelName.replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/").last.map(String.init) ?? ""
            guard !name.isEmpty, name != ".", name != "..",
                  !name.contains("/") else { return nil }
            let ext = (name as NSString).pathExtension.lowercased()
            guard ext.isEmpty || ext == "ucm" else { return nil }
            let base = (name as NSString).deletingPathExtension.lowercased()
            guard !base.isEmpty else { return nil }
            let matches = filesByBaseName[base] ?? []
            if matches.count == 1 { return matches[0] }
            if !matches.isEmpty { return nil }
            guard base.hasPrefix("to_"), base.count > 3 else { return nil }
            let aliasMatches = filesByBaseName[String(base.dropFirst(3))] ?? []
            return aliasMatches.count == 1 ? aliasMatches[0] : nil
        }
    }

    static func resolve(_ modelName: String, in directory: URL) -> URL? {
        AssetIndex(directory: directory).resolve(modelName)
    }
}
