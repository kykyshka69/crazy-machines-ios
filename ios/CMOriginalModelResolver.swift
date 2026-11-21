import Foundation

/// Resolves 3DO references to user-imported UCM assets without fuzzy matches.
/// An explicit model name is resolved only to the same basename, optionally
/// with the .ucm extension. Duplicate basenames are treated as ambiguous.
enum CMOriginalModelResolver {
    /// Collect only meshes owned by this object. Nested tmo_ nodes are
    /// independent PC objects and must not leak their meshes into the parent.
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
            for child in item.children where !child.name.hasPrefix("tmo_") { visit(child) }
        }
        visit(node)
        var seen = Set<String>()
        return result.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Collect all distinct UCM references for the whole original level.
    /// modelNames(in:) deliberately excludes nested tmo_* owners; a level
    /// browser must visit each owner rather than passing the root only.
    static func allModelNames(in root: CMOriginalSceneDocument.Node) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        func collect(_ names: [String]) {
            for name in names where seen.insert(name.lowercased()).inserted {
                result.append(name)
            }
        }
        func visit(_ node: CMOriginalSceneDocument.Node) {
            // The level's own helper meshes, if any, belong to the root.
            // Each tmo_* owns its meshes independently of nested objects.
            if node.name == "level" || node.name.hasPrefix("tmo_") {
                collect(modelNames(in: node))
            }
            for child in node.children { visit(child) }
        }
        visit(root)
        return result
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
            // Reject traversal and absolute paths before stripping Windows
            // or POSIX directory components from a PC 3DO reference.
            let normalized = modelName.replacingOccurrences(of: "\\", with: "/")
            let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
            guard !normalized.hasPrefix("/"),
                  !normalized.hasPrefix("//"),
                  !normalized.contains(":"),
                  !components.contains(where: { $0 == "." || $0 == ".." }),
                  let last = components.last, !last.isEmpty else { return nil }
            let name = String(last)
            let ext = (name as NSString).pathExtension.lowercased()
            guard ext.isEmpty || ext == "ucm" else { return nil }
            let base = (name as NSString).deletingPathExtension.lowercased()
            guard !base.isEmpty else { return nil }
            let matches = filesByBaseName[base] ?? []
            if matches.count == 1 { return matches[0] }
            if !matches.isEmpty { return nil }
            // The original scene may reference a to_ model while the
            // imported mesh omits the prefix. Do not infer the reverse:
            // an unprefixed PC model must not silently resolve to a
            // potentially different to_ mesh.
            guard base.hasPrefix("to_"), base.count > 3 else { return nil }
            let aliasMatches = filesByBaseName[String(base.dropFirst(3))] ?? []
            return aliasMatches.count == 1 ? aliasMatches[0] : nil
        }
    }

    static func resolve(_ modelName: String, in directory: URL) -> URL? {
        AssetIndex(directory: directory).resolve(modelName)
    }
}
