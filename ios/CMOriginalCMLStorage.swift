import Foundation

/// Persist user-owned, natively decoded original level scenes in the same
/// sandbox location used by the original-level browser. Never overwrite a
/// different existing export with the same level index.
enum CMOriginalCMLStorage {
    struct Result {
        let saved: Int
        let alreadyPresent: Int
        let conflicting: Int
    }

    static func save(_ documents: [CMOriginalSceneDocument], to directory: URL) throws -> Result {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var saved = 0, alreadyPresent = 0, conflicting = 0
        var seen = Set<Int>()
        for document in documents {
            guard (1...102).contains(document.index), seen.insert(document.index).inserted else {
                throw CMOriginalSceneDocument.SceneError.invalid
            }
            let data = try JSONEncoder().encode(document)
            // Validate the exact serialized representation as if it had been
            // imported as an original JSON scene.
            _ = try CMOriginalSceneDocument.read(data)
            let filename = String(format: "level-%03d.json", document.index)
            let destination = directory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) {
                if let old = try? Data(contentsOf: destination),
                   let existing = try? CMOriginalSceneDocument.read(old),
                   existing.sceneSHA256 == document.sceneSHA256 {
                    alreadyPresent += 1
                } else {
                    conflicting += 1
                }
                continue
            }
            try data.write(to: destination, options: .atomic)
            saved += 1
        }
        return Result(saved: saved, alreadyPresent: alreadyPresent, conflicting: conflicting)
    }
}
