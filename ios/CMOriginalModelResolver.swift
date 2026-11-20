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

    /// Enumerate references across the entire level, including nested tmo_
    /// objects. Use modelNames(in:) instead for one object's own meshes.
    static func allModelNames(in root: CMOriginalSceneDocument.Node) -> [String] {
        var names: [String] = []
        var seen = Set<String>()
        func visit(_ node: CMOriginalSceneDocument.Node) {
            if node.name.hasPrefix("tmo_") {
                for name in modelNames(in: node) {
                    if seen.insert(name.lowercased()).inserted { names.append(name) }
                }
            } else {
                // Root and non-object helpers may also carry mesh references.
                if let models = node.models {
                    for name in models where seen.insert(name.lowercased()).inserted {
                        names.append(name)
                    }
                }
                if node.name.hasPrefix("3DO ") {
                    let name = String(node.name.dropFirst(4))
                    if seen.insert(name.lowercased()).inserted { names.append(name) }
                }
            }
            for child in node.children { visit(child) }
        }
        visit(root)
        return names
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

        enum Resolution {
            case found(URL)
            case missing
            case ambiguous
            case invalidReference
        }

        func resolve(_ modelName: String) -> URL? {
            if case .found(let url) = resolution(for: modelName) { return url }
            return nil
        }

        func resolution(for modelName: String) -> Resolution {
            // Reject traversal and absolute paths before stripping Windows
            // or POSIX directory components from a PC 3DO reference.
            let normalized = modelName.replacingOccurrences(of: "\\", with: "/")
            let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
            guard !normalized.hasPrefix("/"),
                  !normalized.contains(":"),
                  !normalized.contains("\0"),
                  !normalized.contains("\n"),
                  !normalized.contains("\r"),
                  !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                  let last = components.last, !last.isEmpty else { return .invalidReference }
            let name = String(last)
            let ext = (name as NSString).pathExtension.lowercased()
            guard ext.isEmpty || ext == "ucm" else { return .invalidReference }
            let base = (name as NSString).deletingPathExtension.lowercased()
            guard !base.isEmpty, base != ".", base != "..",
                  !base.contains("\0"), !base.contains("\n"), !base.contains("\r") else { return .invalidReference }
            let matches = filesByBaseName[base] ?? []
            if matches.count == 1 { return .found(matches[0]) }
            if !matches.isEmpty { return .ambiguous }
            // The original scene may reference a to_ model while the
            // imported mesh omits the prefix. Do not infer the reverse:
            // an unprefixed PC model must not silently resolve to a
            // potentially different to_ mesh.
            guard base.hasPrefix("to_"), base.count > 3 else { return .missing }
            let aliasMatches = filesByBaseName[String(base.dropFirst(3))] ?? []
            if aliasMatches.count == 1 { return .found(aliasMatches[0]) }
            return aliasMatches.isEmpty ? .missing : .ambiguous
        }
    }

    static func resolve(_ modelName: String, in directory: URL) -> URL? {
        AssetIndex(directory: directory).resolve(modelName)
    }
}
