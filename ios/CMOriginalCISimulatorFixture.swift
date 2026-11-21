import Foundation
import CryptoKit

#if DEBUG && targetEnvironment(simulator)
/// Copyright-free iOS simulator fixture for a complete Play -> 3D launch test.
/// The triangle is synthetic and must never be presented as a real PC puzzle.
/// The fixture is installed by the exact production CMASSET1 importer, rather
/// than bypassing original scene loading or faking a successful navigation.
enum CMOriginalCISimulatorFixture {
    static let installArgument = "--cm-ci-install-original-scene"
    static let clearArgument = "--cm-ci-clear-original-scene"

    static func handleLaunchArguments() throws {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(clearArgument) {
            clearFixture()
        } else if arguments.contains(installArgument) {
            clearFixture()
            _ = try CMOriginalAssetPackImporter.install(makePack())
        }
    }

    private static var originalStorage: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("OriginalGame", isDirectory: true)
    }

    private static var sceneStorage: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("OriginalScenes", isDirectory: true)
    }

    private static func clearFixture() {
        let fixtureModel = originalStorage.appendingPathComponent("cm_ci_triangle.ucm")
        let sceneURL = sceneStorage.appendingPathComponent("level-001.json")
        try? FileManager.default.removeItem(at: fixtureModel)
        // Remove only the exact synthetic scene, never delete a user's
        // authentic imported level-001.json or other original game files.
        if let contents = try? Data(contentsOf: sceneURL),
           let content = String(data: contents, encoding: .utf8),
           content.contains("CM synthetic CI 3D scene") {
            try? FileManager.default.removeItem(at: sceneURL)
        }
    }

    private static func makeModel() -> Data {
        var header = Data(repeating: 0, count: 92)
        header.replaceSubrange(0..<4, with: Data("UCM1".utf8))
        func writeU32(_ n: UInt32, at offset: Int) {
            header.replaceSubrange(offset..<(offset + 4), with: Data([
                UInt8(truncatingIfNeeded: n),
                UInt8(truncatingIfNeeded: n >> 8),
                UInt8(truncatingIfNeeded: n >> 16),
                UInt8(truncatingIfNeeded: n >> 24)
            ]))
        }
        writeU32(1, at: 4)  // version
        writeU32(1, at: 72) // group count
        writeU32(1, at: 76) // face count
        writeU32(3, at: 80) // vertices per group
        writeU32(0, at: 84) // extra records

        var contents = header
        for index in [UInt32(0), 1, 2] {
            appendU32(index, to: &contents)
        }
        let vertices: [[Float]] = [
            [-0.7, -0.5, 0, 0, 0, -1, 0, 0],
            [0.7, -0.5, 0, 0, 0, -1, 1, 0],
            [0, 0.7, 0, 0, 0, -1, 0.5, 1]
        ]
        for vertex in vertices {
            for value in vertex { appendU32(value.bitPattern, to: &contents) }
        }
        return contents
    }

    private static func makeScene() throws -> Data {
        let root: [String: Any] = [
            "name": "level", "fields": [],
            "children": [[
                "name": "tmo_board",
                "fields": ["POS 0, 0, 0"],
                "position": [0.0, 0.0, 0.0],
                "models": ["cm_ci_triangle"],
                "children": []
            ]]
        ]
        let scene: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 1,
            "title": "CM synthetic CI 3D scene",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": root
        ]
        return try JSONSerialization.data(withJSONObject: scene, options: [.sortedKeys])
    }

    private static func appendU16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private static func appendU32(_ value: UInt32, to data: inout Data) {
        for offset in [0, 8, 16, 24] {
            data.append(UInt8(truncatingIfNeeded: value >> offset))
        }
    }

    private static func makePack() throws -> Data {
        var contents = Data("CMASSET1".utf8)
        appendU32(2, to: &contents)
        for (name, data) in [
            ("cm_ci_triangle.ucm", makeModel()),
            ("level-001.json", try makeScene())
        ] {
            let nameBytes = Data(name.utf8)
            appendU16(UInt16(nameBytes.count), to: &contents)
            contents.append(nameBytes)
            appendU32(UInt32(data.count), to: &contents)
            contents.append(contentsOf: SHA256.hash(data: data))
            contents.append(data)
        }
        return contents
    }
}
#endif
