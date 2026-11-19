import Foundation

/// Resolves 3DO references to user-imported UCM assets without fuzzy matches.
/// An explicit model name is resolved only to the same basename, optionally
/// with the .ucm extension. Duplicate basenames are treated as ambiguous.
enum CMOriginalModelResolver {
    static func modelNames(in node: CMOriginalSceneDocument.Node) -> [String] {
        var result: [String] = []
        func visit(_ item: CMOriginalSceneDocument.Node) {
            if let models = item.models { result.append(contentsOf: models) }
            for child in item.children {
                if child.name.hasPrefix("3DO ") {
                    result.append(String(child.name.dropFirst(4)))
                }
                visit(child)
            }
        }
        visit(node)
        var seen = Set<String>()
        return result.filter { seen.insert($0.lowercased()).inserted }
    }

    static func resolve(_ modelName: String, in directory: URL) -> URL? {
        let name = modelName.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last.map(String.init) ?? ""
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/") else { return nil }
        let base = (name as NSString).deletingPathExtension.lowercased()
        guard !base.isEmpty else { return nil }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let matches = files.filter {
            $0.pathExtension.lowercased() == "ucm" &&
            $0.deletingPathExtension().lastPathComponent.lowercased() == base
        }
        return matches.count == 1 ? matches[0] : nil
    }
}
