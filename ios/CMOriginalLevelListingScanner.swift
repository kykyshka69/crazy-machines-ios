import Foundation

/// Compact, immutable, sendable metadata for one original Professor level.
struct CMOriginalLevelListing: Identifiable, Sendable {
    let index: Int
    let title: String
    let objectCount: Int
    let url: URL
    var id: Int { index }
}

/// Scan privately installed PC scenes without blocking SwiftUI rendering.
enum CMOriginalLevelListingScanner {
    static func scan(directory: URL) -> [CMOriginalLevelListing] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var loaded: [Int: CMOriginalLevelListing] = [:]
        let sorted = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare(
                $1.lastPathComponent) == .orderedAscending
        }
        for url in sorted where url.pathExtension.lowercased() == "json" {
            guard let attr = try? url.resourceValues(
                      forKeys: [.isRegularFileKey, .fileSizeKey]),
                  attr.isRegularFile == true,
                  let size = attr.fileSize, size > 0, size <= 8_000_000,
                  let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
                  let document = try? CMOriginalSceneDocument.read(data)
            else { continue }
            if loaded[document.index] == nil {
                loaded[document.index] = CMOriginalLevelListing(
                    index: document.index, title: document.title,
                    objectCount: document.root.objectCount, url: url)
            }
        }
        return loaded.values.sorted { $0.index < $1.index }
    }
}
