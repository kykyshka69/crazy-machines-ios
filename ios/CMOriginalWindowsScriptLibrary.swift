import Foundation

/// Reads the player's authentic encrypted elements.fsc from the original
/// resource directory. No Windows game data is embedded in this iOS target.
public enum CMOriginalWindowsScriptLibrary {
    public static func load(directory: URL) -> [String: CMOriginalElementsTemplateCatalog.Template]? {
        let file = directory.appendingPathComponent("elements.fsc")
        guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              let length = values.fileSize,
              length > 30, length <= 2_000_000,
              let encrypted = try? Data(contentsOf: file, options: [.mappedIfSafe]),
              let decoded = try? CMOriginalElementsScriptDecoder.decode(encrypted),
              let templates = try? CMOriginalElementsTemplateCatalog.parse(decodedBytes: decoded),
              templates.count >= 100 else { return nil }
        return templates
    }
}