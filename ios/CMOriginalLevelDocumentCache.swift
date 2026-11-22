import Foundation

/// Bounded cache of authentic, privately installed Professor JSON scenes.
///
/// SwiftUI asks whether previous/next levels exist on every body refresh.
/// Without a cache those checks repeatedly read and JSON-decode the same
/// levels (even when only a SceneKit contact counter changes).
/// Keep at most five verified scenes in memory so browsing all 102 levels
/// doesn't accumulate their entire original object graphs.
final class CMOriginalLevelDocumentCache {
    private let sceneDirectory: URL
    private let capacity: Int
    private var documents: [Int: CMOriginalSceneDocument] = [:]
    private var leastRecentFirst: [Int] = []

    init(initial: CMOriginalSceneDocument, sceneDirectory: URL,
         capacity: Int = 5) {
        self.sceneDirectory = sceneDirectory
        self.capacity = max(3, capacity)
        documents[initial.index] = initial
        leastRecentFirst = [initial.index]
    }

    func scene(at index: Int) -> CMOriginalSceneDocument? {
        guard (1...102).contains(index) else { return nil }
        if let cached = documents[index] {
            touch(index)
            return cached
        }

        let url = sceneDirectory.appendingPathComponent(
            String(format: "level-%03d.json", index))
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              let document = try? CMOriginalSceneDocument.read(data),
              document.index == index else { return nil }
        documents[index] = document
        touch(index)
        while leastRecentFirst.count > capacity {
            let evicted = leastRecentFirst.removeFirst()
            documents.removeValue(forKey: evicted)
        }
        return document
    }

    private func touch(_ index: Int) {
        leastRecentFirst.removeAll { $0 == index }
        leastRecentFirst.append(index)
    }
}
