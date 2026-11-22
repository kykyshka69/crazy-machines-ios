import Foundation

@main
struct OriginalSceneCacheSmoke {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-scene-cache-\(UUID().uuidString)",
                                  isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        func bytes(index: Int, title: String? = nil) throws -> Data {
            let dictionary: [String: Any] = [
                "schema": "crazy-machines-original-scene-v1",
                "index": index,
                "title": title ?? "Synthetic test scene \(index)",
                "scene_sha256": String(repeating: "a", count: 64),
                "root": ["name": "level", "fields": [],
                         "children": []] as [String: Any]
            ]
            return try JSONSerialization.data(
                withJSONObject: dictionary, options: [.sortedKeys])
        }

        func write(_ fileIndex: Int, representedIndex: Int? = nil,
                   title: String? = nil) throws {
            let name = String(format: "level-%03d.json", fileIndex)
            try bytes(index: representedIndex ?? fileIndex, title: title)
                .write(to: directory.appendingPathComponent(name))
        }

        try write(1)
        for index in 2...8 { try write(index) }
        let first = try CMOriginalSceneDocument.read(bytes(index: 1))
        let cache = CMOriginalLevelDocumentCache(
            initial: first, sceneDirectory: directory, capacity: 3)

        precondition(cache.scene(at: 0) == nil)
        precondition(cache.scene(at: 103) == nil)
        precondition(cache.scene(at: 1)?.index == 1)
        precondition(cache.scene(at: 2)?.index == 2)

        // Cached documents must survive a missing/replaced on-disk scene,
        // avoiding repeated synchronous File I/O on SwiftUI state updates.
        try FileManager.default.removeItem(
            at: directory.appendingPathComponent("level-002.json"))
        precondition(cache.scene(at: 2)?.index == 2)
        try write(2, title: "Updated after eviction")

        // Bounded LRU: navigating five more levels evicts older document 2.
        for index in 3...8 {
            precondition(cache.scene(at: index)?.index == index)
        }
        precondition(
            cache.scene(at: 2)?.title == "Updated after eviction",
            "The old level must be evicted and reloaded when visited again"
        )

        // Never accept a file with a mismatched scene index or corrupt JSON.
        try write(9, representedIndex: 8)
        precondition(cache.scene(at: 9) == nil)
        try Data("not original JSON".utf8)
            .write(to: directory.appendingPathComponent("level-010.json"))
        precondition(cache.scene(at: 10) == nil)
        precondition(cache.scene(at: 11) == nil)

        print("Bounded authentic-scene navigation cache: OK")
    }
}
