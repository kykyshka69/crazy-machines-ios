import Foundation

/// Preflight native CML laboratories from an original CMASSET1 pack before
/// modifying any of the user's installed game files. Game levels remain
/// private; the temporary directory is deleted after decoding.
enum CMOriginalPackScenePlanner {
    struct Scene {
        let name: String
        let bytes: Data
    }

    /// Only called for a pack which has NO pre-exported JSON scenes. A CML
    /// laboratory then becomes a playable set of original levels on-device,
    /// without requiring the user to run PC-side JSON export scripts.
    static func prepare(
        laboratories: [(name: String, bytes: Data)],
        sha256: (Data) -> String
    ) throws -> [Scene] {
        guard !laboratories.isEmpty else { return [] }
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent(
            "cm-original-pack-scenes-" + UUID().uuidString,
            isDirectory: true)
        defer { try? fm.removeItem(at: directory) }

        for laboratory in laboratories {
            _ = try CMOriginalLaboratorySceneInstaller.install(
                laboratory.bytes, into: directory, sha256: sha256)
        }
        let files = (try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles])) ?? []
        var scenes: [Scene] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard file.pathExtension.lowercased() == "json",
                  (try file.resourceValues(
                    forKeys: [.isRegularFileKey])).isRegularFile == true else {
                continue
            }
            let bytes = try Data(contentsOf: file)
            // The same parser and scene size limits used by Play validate
            // the staged records before they enter the destination sandbox.
            _ = try CMOriginalSceneDocument.read(bytes)
            scenes.append(Scene(name: file.lastPathComponent, bytes: bytes))
        }
        return scenes
    }
}
