import Foundation
import CryptoKit

#if DEBUG && targetEnvironment(simulator)
/// Copyright-free iOS simulator fixture for a complete Play -> 3D launch test.
/// The triangle is synthetic and must never be presented as a real PC puzzle.
/// The fixture is installed by the exact production CMASSET1 importer, rather
/// than bypassing original scene loading or faking a successful navigation.
enum CMOriginalCISimulatorFixture {
    static let installArgument = "--cm-ci-install-original-scene"
    // Separate copyright-free physics fixture: four exact CONNECTED_TO
    // links and two editable boards mimic only the first-level signature.
    // No original PC geometry, coordinates or artwork are embedded here.
    static let linkedZoneArgument = "--cm-ci-install-linked-zone-fixture"
    static let clearArgument = "--cm-ci-clear-original-scene"

    static func handleLaunchArguments() throws {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(clearArgument) {
            clearFixture()
        } else if arguments.contains(installArgument)
                    || arguments.contains(linkedZoneArgument) {
            clearFixture()
            _ = try CMOriginalAssetPackImporter.install(
                makePack(linkedZone: arguments.contains(linkedZoneArgument))
            )
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
        let solidModel = originalStorage.appendingPathComponent("cm_ci_solid.ucm")
        try? FileManager.default.removeItem(at: fixtureModel)
        try? FileManager.default.removeItem(at: solidModel)
        // Remove only exact synthetic scenes; NEVER delete imported PC
        // levels (including a real level 2) during CI fixture cleanup.
        for filename in ["level-001.json", "level-002.json", "level-003.json", "level-004.json"] {
            let sceneURL = sceneStorage.appendingPathComponent(filename)
            if let contents = try? Data(contentsOf: sceneURL),
               let content = String(data: contents, encoding: .utf8),
               content.contains("CM synthetic CI") {
                try? FileManager.default.removeItem(at: sceneURL)
            }
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

    /// Closed octahedral UCM geometry for collision testing. The old flat
    /// orange triangle has zero Z span and cannot validate real rigid-body
    /// contacts. This model has finite volume on all three axes, without
    /// using any proprietary PC model or physics engine assets.
    private static func makeSolidModel() -> Data {
        var header = Data(repeating: 0, count: 92)
        header.replaceSubrange(0..<4, with: Data("UCM1".utf8))
        func put(_ value: UInt32, at offset: Int) {
            header.replaceSubrange(offset..<(offset + 4), with: Data([
                UInt8(truncatingIfNeeded: value),
                UInt8(truncatingIfNeeded: value >> 8),
                UInt8(truncatingIfNeeded: value >> 16),
                UInt8(truncatingIfNeeded: value >> 24)
            ]))
        }
        put(1, at: 4)
        put(1, at: 72)  // one group
        put(8, at: 76)  // eight triangular faces
        put(6, at: 80)  // six 3D vertices
        let faces: [[UInt32]] = [
            [4, 0, 2], [4, 2, 1], [4, 1, 3], [4, 3, 0],
            [5, 2, 0], [5, 1, 2], [5, 3, 1], [5, 0, 3]
        ]
        var data = header
        for index in faces.flatMap({ $0 }) { appendU32(index, to: &data) }
        let positions: [[Float]] = [
            [0.5, 0, 0], [-0.5, 0, 0],
            [0, 0.5, 0], [0, -0.5, 0],
            [0, 0, 0.5], [0, 0, -0.5]
        ]
        for position in positions {
            // XYZ + vertex normal XYZ + U/V, all finite 32-bit floats.
            for component in position + position + [0, 0] {
                appendU32(component.bitPattern, to: &data)
            }
        }
        return data
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

    /// The second screen contains no copyrighted media and verifies that a
    /// completed first-level prototype can navigate into the next imported
    /// level rather than just display a hidden/disabled Continue button.
    private static func makeSecondScene() throws -> Data {
        func object(_ name: String, x: Double, y: Double,
                    extra: [String]) -> [String: Any] {
            let fields = ["POS \(x), \(y), 0"] + extra
            return [
                "name": name, "fields": fields,
                "position": [x, y, 0.0],
                "models": ["cm_ci_solid"], "children": []
            ]
        }
        // This explicitly mirrors only the VERIFIED relation signature of
        // authentic PC Professor level 2: one basketball CONNECTED_TO a
        // CRATE (not the separate zone), three editable dominoes. Geometry
        // and object placements are copyright-free synthetic test values.
        let elements: [[String: Any]] = [
            object("tmo_board", x: 0, y: -1.0, extra: ["VALB 64"]),
            object("tmo_crate", x: 0, y: 0.0, extra: ["VALB 72"]),
            object("tmo_ball_basket", x: 0, y: 1.05,
                   extra: ["CONNECTED_TO 1", "VALB 72"]),
            object("tmo_domino", x: -3, y: 0,
                   extra: ["UNLOCKED 1", "VALB 8"]),
            object("tmo_domino", x: -2, y: 0,
                   extra: ["UNLOCKED 1", "VALB 8"]),
            object("tmo_domino", x: -1, y: 0,
                   extra: ["UNLOCKED 1", "VALB 8"]),
            object("tmo_zone", x: 4, y: -1, extra: ["VALB 32"])
        ]
        let scene: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 2,
            "title": "CM synthetic CI level 2",
            "scene_sha256": String(repeating: "c", count: 64),
            "root": [
                "name": "level", "fields": [],
                "children": [[
                    "name": "level_elements", "fields": [],
                    "children": elements
                ]]
            ]
        ]
        return try JSONSerialization.data(
            withJSONObject: scene, options: [.sortedKeys]
        )
    }

    private static func makeThirdScene() throws -> Data {
        func object(_ name: String, x: Double, y: Double,
                    extra: [String]) -> [String: Any] {
            [
                "name": name,
                "fields": ["POS \(x), \(y), 0"] + extra,
                "position": [x, y, 0.0],
                "models": ["cm_ci_solid"], "children": []
            ]
        }
        // Original Professor 3: five linked crates and one editable spring.
        // Original coordinates/mesh files are NOT included. Five synthetic
        // moving solids test distinct SceneKit contacts with the same zone.
        var elements: [[String: Any]] = [
            object("tmo_zone", x: 0, y: -1, extra: ["VALB 32"]),
            object("tmo_board", x: 0, y: -2.5, extra: ["VALB 64"]),
            object("tmo_spring", x: -4, y: -1,
                   extra: ["UNLOCKED 1"])
        ]
        for i in 0..<5 {
            elements.append(object(
                "tmo_crate", x: 0, y: 1.1 + Double(i) * 1.4,
                extra: ["CONNECTED_TO 0", "VALB 72"]))
        }
        let scene: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 3,
            "title": "CM synthetic CI level 3",
            "scene_sha256": String(repeating: "d", count: 64),
            "root": [
                "name": "level", "fields": [],
                "children": [[
                    "name": "level_elements", "fields": [],
                    "children": elements
                ]]
            ]
        ]
        return try JSONSerialization.data(
            withJSONObject: scene, options: [.sortedKeys]
        )
    }

    private static func makeFourthScene() throws -> Data {
        guard var document = try JSONSerialization.jsonObject(
            with: makeScene()
        ) as? [String: Any] else {
            throw NSError(domain: "CMSyntheticScene", code: 4)
        }
        document["index"] = 4
        document["title"] = "CM synthetic CI level 4"
        document["scene_sha256"] = String(repeating: "e", count: 64)
        return try JSONSerialization.data(
            withJSONObject: document, options: [.sortedKeys]
        )
    }

    /// A synthetic physical sensor and moving source exercise the ACTUAL
    /// SCNPhysicsContact -> original object-ID -> CONNECTED_TO -> SwiftUI
    /// delivery path, which the orange triangle rendering smoke never tests.
    private static func makeLinkedZoneScene() throws -> Data {
        func object(_ name: String, x: Double, y: Double,
                    extra: [String] = []) -> [String: Any] {
            let position = [x, y, 0.0]
            let fields = ["POS \(x), \(y), 0"] + extra
            return [
                "name": name, "fields": fields, "position": position,
                "models": ["cm_ci_solid"], "children": []
            ]
        }
        let elements: [[String: Any]] = [
            // CONNECTED_TO indices refer to level_elements children.
            object("tmo_zone", x: 0, y: -1, extra: ["VALB 32"]),
            object("tmo_board", x: -4, y: -2, extra: ["UNLOCKED 1", "VALB 64"]),
            object("tmo_board", x: 4, y: -2, extra: ["UNLOCKED 1", "VALB 64"]),
            object("tmo_ball_tennis", x: 0, y: 1.1,
                   extra: ["CONNECTED_TO 0", "VALB 72"]),
            object("tmo_ball_beach", x: 0, y: 2.5,
                   extra: ["CONNECTED_TO 0", "VALB 72"]),
            object("tmo_ball_basket", x: 0, y: 3.9,
                   extra: ["CONNECTED_TO 0", "VALB 72"]),
            object("tmo_crate", x: 0, y: 5.3,
                   extra: ["CONNECTED_TO 0", "VALB 72"])
        ]
        let root: [String: Any] = [
            "name": "level", "fields": [],
            "children": [[
                "name": "level_elements", "fields": [],
                "children": elements
            ]]
        ]
        let scene: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 1,
            "title": "CM synthetic CI 3D contacts",
            "scene_sha256": String(repeating: "b", count: 64),
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

    private static func makePack(linkedZone: Bool = false) throws -> Data {
        var contents = Data("CMASSET1".utf8)
        let files: [(String, Data)] = linkedZone
            ? [
                ("cm_ci_triangle.ucm", makeModel()),
                ("cm_ci_solid.ucm", makeSolidModel()),
                ("level-001.json", try makeLinkedZoneScene()),
                ("level-002.json", try makeSecondScene()),
                ("level-003.json", try makeThirdScene()),
                ("level-004.json", try makeFourthScene())
            ]
            : [
                ("cm_ci_triangle.ucm", makeModel()),
                ("level-001.json", try makeScene())
            ]
        appendU32(UInt32(files.count), to: &contents)
        for (name, data) in files {
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
