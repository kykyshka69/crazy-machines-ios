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
        for name in ["cm_ci_authored_ball.ucm", "cm_ci_authored_crate.ucm", "cm_ci_wide_zone.ucm"] {
            try? FileManager.default.removeItem(at: originalStorage.appendingPathComponent(name))
        }
        let syntheticGlow = originalStorage.appendingPathComponent("light_glow.tga")
        if let data = try? Data(contentsOf: syntheticGlow),
           data == makeSyntheticGlowTGA() {
            // Never remove a user's real light_glow.tga.
            try? FileManager.default.removeItem(at: syntheticGlow)
        }
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
    private static func makeSolidModel(authoredSphere: Bool = false) -> Data {
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
        if authoredSphere {
            // Synthetic collision metadata, never a proprietary UCM payload.
            appendU32(1, to: &data)
            appendU32(0, to: &data)
            for value: Float in [0,0,0,0.5] { appendU32(value.bitPattern, to: &data) }
        }
        return data
    }

    /// Closed box with a real, synthetic UCM1 OBB table. A wide sensor
    /// spans independent falling lanes; collected objects are NOT deleted.
    private static func makeAuthoredBox(halfX: Float, halfY: Float, halfZ: Float) -> Data {
        var header = Data(repeating: 0, count: 92)
        header.replaceSubrange(0..<4, with: Data("UCM1".utf8))
        func put(_ value: UInt32, at offset: Int) {
            header.replaceSubrange(offset..<(offset+4), with: [
                UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8),
                UInt8(truncatingIfNeeded: value >> 16), UInt8(truncatingIfNeeded: value >> 24)
            ])
        }
        put(1, at: 4); put(1, at: 72); put(12, at: 76); put(8, at: 80)
        var data = header
        let faces: [UInt32] = [0,2,1,0,3,2, 4,5,6,4,6,7,
                               0,1,5,0,5,4, 3,7,6,3,6,2,
                               0,4,7,0,7,3, 1,2,6,1,6,5]
        for index in faces { appendU32(index, to: &data) }
        let points: [[Float]] = [
            [-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],
            [-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]
        ]
        for p in points {
            let vertex: [Float] = [p[0]*halfX,p[1]*halfY,p[2]*halfZ,
                                   p[0]/sqrt(3),p[1]/sqrt(3),p[2]/sqrt(3),0,0]
            for component in vertex { appendU32(component.bitPattern,to:&data) }
        }
        appendU32(0,to:&data); appendU32(1,to:&data)
        let record: [Float] = [0,0,0,halfX,halfY,halfZ,1,0,0,0,1,0,0,0,1]
        for component in record { appendU32(component.bitPattern,to:&data) }
        return data
    }

    private static func makeSyntheticGlowTGA() -> Data {
        // Uncompressed 4x4 BGR24, black perimeter + white center.
        // Copyright-free test texture; matches the original glow format,
        // never the user's proprietary TGA pixels.
        var data = Data(repeating: 0, count: 18)
        data[2] = 2
        data[12] = 4
        data[14] = 4
        data[16] = 24
        data[17] = 0x20
        for y in 0..<4 {
            for x in 0..<4 {
                let intensity: UInt8 =
                    (x == 1 || x == 2) && (y == 1 || y == 2) ? 180 : 0
                data.append(contentsOf: [intensity, intensity, intensity])
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
                "children": [[
                    "name": "3DO to_candle_glow",
                    "fields": ["POSREL 0.25, 0.4, -0.2"],
                    "position_relative": [0.25, 0.4, -0.2],
                    "children": []
                ]]
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
            // In this copyright-free *test* scene, anchor the receiving
            // crate and leave an actual gap above it. Previously both
            // dynamic bodies could free-fall together before ever touching,
            // so a missing event did not distinguish a bad test arrangement
            // from a broken original CONNECTED_TO contact callback.
            // This is NOT a change to the authentic PC level's crate role.
            object("tmo_crate", x: 0, y: 0.0, extra: ["VALB 64"]),
            object("tmo_ball_basket", x: 0, y: 1.8,
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
                    extra: [String], model: String = "cm_ci_solid") -> [String: Any] {
            [
                "name": name,
                "fields": ["POS \(x), \(y), 0"] + extra,
                "position": [x, y, 0.0],
                "models": [model], "children": []
            ]
        }
        // Original Professor 3: five linked crates and one editable spring.
        // Original coordinates/mesh files are NOT included. Five synthetic
        // moving solids test distinct SceneKit contacts with the same zone.
        var elements: [[String: Any]] = [
            object("tmo_zone", x: 0, y: -1, extra: ["VALB 32"], model: "cm_ci_wide_zone"),
            object("tmo_board", x: 0, y: -4, extra: ["VALB 64"]),
            object("tmo_spring", x: -4, y: -1,
                   extra: ["UNLOCKED 1"])
        ]
        for i in 0..<5 {
            elements.append(object(
                "tmo_crate", x: Double(i - 2) * 1.6, y: 1.1 + Double(i) * 0.45,
                extra: ["CONNECTED_TO 0", "VALB 72"], model: "cm_ci_authored_crate"))
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
        // Copyright-free original-format magnet + metal bucket, matching
        // only the tmo_ categories/VALB roles of PC Professor level four.
        // The positions and solid meshes below are synthetic CI fixtures.
        guard var root = document["root"] as? [String: Any],
              var objects = root["children"] as? [[String: Any]] else {
            throw NSError(domain: "CMSyntheticScene", code: 5)
        }
        objects.append([
            "name": "tmo_magnetic_permanent",
            "fields": ["POS -1, 0, 0", "UNLOCKED 1", "VALB 64"],
            "position": [-1.0, 0.0, 0.0],
            "models": ["cm_ci_solid"],
            "children": []
        ])
        objects.append([
            "name": "tmo_bucket",
            "fields": ["POS 0.6, 0, 0", "GOAL 1", "VALB 104"],
            "position": [0.6, 0.0, 0.0],
            "models": ["cm_ci_solid"],
            "children": []
        ])
        root["children"] = objects
        document["root"] = root
        return try JSONSerialization.data(
            withJSONObject: document, options: [.sortedKeys]
        )
    }

    /// A synthetic physical sensor and moving source exercise the ACTUAL
    /// SCNPhysicsContact -> original object-ID -> CONNECTED_TO -> SwiftUI
    /// delivery path, which the orange triangle rendering smoke never tests.
    private static func makeLinkedZoneScene() throws -> Data {
        func object(_ name: String, x: Double, y: Double,
                    extra: [String] = [], model: String = "cm_ci_solid") -> [String: Any] {
            let position = [x, y, 0.0]
            let fields = ["POS \(x), \(y), 0"] + extra
            return [
                "name": name, "fields": fields, "position": position,
                "models": [model], "children": []
            ]
        }
        let elements: [[String: Any]] = [
            // CONNECTED_TO indices refer to level_elements children.
            object("tmo_zone", x: 0, y: -1, extra: ["VALB 32"], model: "cm_ci_wide_zone"),
            object("tmo_board", x: -4, y: -2, extra: ["UNLOCKED 1", "VALB 64"]),
            object("tmo_board", x: 4, y: -2, extra: ["UNLOCKED 1", "VALB 64"]),
            object("tmo_ball_tennis", x: -2.7, y: 1.1,
                   extra: ["CONNECTED_TO 0", "VALB 72"], model: "cm_ci_authored_ball"),
            object("tmo_ball_beach", x: -0.9, y: 2.5,
                   extra: ["CONNECTED_TO 0", "VALB 72"], model: "cm_ci_authored_ball"),
            object("tmo_ball_basket", x: 0.9, y: 3.9,
                   extra: ["CONNECTED_TO 0", "VALB 72"], model: "cm_ci_authored_ball"),
            object("tmo_crate", x: 2.7, y: 5.3,
                   extra: ["CONNECTED_TO 0", "VALB 72"], model: "cm_ci_authored_crate")
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
                ("cm_ci_authored_ball.ucm", makeSolidModel(authoredSphere: true)),
                ("cm_ci_authored_crate.ucm", makeAuthoredBox(halfX: 0.4, halfY: 0.4, halfZ: 0.4)),
                ("cm_ci_wide_zone.ucm", makeAuthoredBox(halfX: 4, halfY: 0.35, halfZ: 0.6)),
                ("level-001.json", try makeLinkedZoneScene()),
                ("level-002.json", try makeSecondScene()),
                ("level-003.json", try makeThirdScene()),
                ("level-004.json", try makeFourthScene())
            ]
            : [
                ("cm_ci_triangle.ucm", makeModel()),
                ("light_glow.tga", makeSyntheticGlowTGA()),
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
