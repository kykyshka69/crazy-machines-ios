import Foundation

@main
struct OriginalFirstLevelRunSmoke {
    static func main() throws {
        // Original Professor level-1 relationship signature, reconstructed
        // with NON-proprietary generated JSON. Nested mounting meshes ensure
        // source IDs are derived from the real hierarchy, not indexes.
        let kinds = [
            "tmo_board", "tmo_board", "tmo_board", "tmo_board",
            "tmo_board", "tmo_board", "tmo_ball_tennis", "tmo_board",
            "tmo_ball_beach", "tmo_ball_basket", "tmo_crate",
            "tmo_zone", "tmo_arrow", "tmo_arrow", "tmo_arrow"
        ]

        func document(_ level: Int = 1,
                      corruptSource: Bool = false,
                      removeUnlock: Bool = false) throws -> CMOriginalSceneDocument {
            var children: [[String: Any]] = []
            for (index, kind) in kinds.enumerated() {
                var fields: [String] = []
                if [6, 8, 9, 10].contains(index) {
                    fields.append("CONNECTED_TO \(corruptSource && index == 10 ? 12 : 11)")
                }
                if !removeUnlock && [5, 7].contains(index) {
                    fields.append("UNLOCKED 1")
                }
                // Use exactly the original first-level moving bit, fixed
                // board flag and non-solid capture-zone classification.
                if ["tmo_ball_tennis", "tmo_ball_beach",
                    "tmo_ball_basket", "tmo_crate"].contains(kind) {
                    fields.append("VALB 72")
                } else if kind == "tmo_zone" {
                    fields.append("VALB 32")
                } else if kind == "tmo_board" {
                    fields.append("VALB 64")
                }
                var subnodes: [[String: Any]] = []
                if kind == "tmo_board" {
                    subnodes.append([
                        "name": "tmo_mount_bar",
                        "fields": ["POSREL 0.1, 0, 0"],
                        "children": []
                    ])
                }
                children.append(["name": kind, "fields": fields, "children": subnodes])
            }
            let raw: [String: Any] = [
                "schema": "crazy-machines-original-scene-v1",
                "index": level,
                "title": "Synthetic original relationship test",
                "scene_sha256": String(repeating: "a", count: 64),
                "root": [
                    "name": "level", "fields": [],
                    "children": [
                        ["name": "level_elements", "fields": [],
                         "children": children]
                    ]
                ]
            ]
            return try CMOriginalSceneDocument.read(
                JSONSerialization.data(withJSONObject: raw))
        }

        let source = try document()
        guard var run = CMOriginalFirstLevelRun(document: source) else {
            preconditionFailure("Original four-source/one-zone signature absent")
        }
        // The genuine first PC level has nested mount objects. Their
        // preorder IDs must not cause physics roles to drift away from the
        // authoritative object registry when SceneKit creates bodies.
        let session = CMOriginalGameplaySession(document: source)
        let roles = CMOriginalPhysicsRolePlanner.roles(for: session)
        precondition(roles.count == session.objects.count)
        precondition(Set(roles.keys) == Set(session.objects.map(\.id)))
        for object in session.objects {
            let role = roles[object.id]
            switch object.type {
            case "tmo_zone":
                precondition(role == .sensor)
            case "tmo_ball_tennis", "tmo_ball_beach",
                 "tmo_ball_basket", "tmo_crate":
                precondition(role == .movable)
            case "tmo_board", "tmo_mount_bar", "tmo_arrow":
                precondition(role == .fixed)
            default:
                preconditionFailure("Unexpected synthetic source type \(object.type)")
            }
        }
        precondition(run.targets.allSatisfy { target in
            roles[target.sourceID] == .movable
                && roles[target.zoneID] == .sensor
        })
        // Reject malformed VALB and preserve axle rotation when metadata
        // does not specify any bit-8 movement.
        let altered: [String: Any] = [
            "schema": source.schema, "index": source.index,
            "title": source.title, "scene_sha256": source.sceneSHA256,
            "root": [
                "name": "level", "fields": [],
                "children": [[
                    "name": "level_elements", "fields": [],
                    "children": [
                        ["name": "tmo_power_motor_rotor", "fields": [], "children": []],
                        ["name": "tmo_rope_seesaw_lever", "fields": [], "children": []],
                        ["name": "tmo_board", "fields": ["VALB invalid"], "children": []],
                        ["name": "tmo_zone", "fields": ["VALB 72"], "children": []]
                    ]
                ]]
            ]
        ]
        // Keep fixture generation explicit: no proprietary UCM or CML data
        // enters source-controlled tests.
        let special = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: altered))
        let specialSession = CMOriginalGameplaySession(document: special)
        let specialRoles = CMOriginalPhysicsRolePlanner.roles(for: specialSession)
        precondition(specialSession.objects.map { specialRoles[$0.id]! }
            == [.movable, .movable, .fixed, .sensor])

        precondition(run.totalCount == 4 && run.deliveredCount == 0)
        precondition(!run.isSatisfied)
        precondition(Set(run.targets.map(\.sourceType)) == [
            "tmo_ball_tennis", "tmo_ball_beach", "tmo_ball_basket", "tmo_crate"
        ])
        precondition(Set(run.targets.map(\.zoneID)).count == 1)
        precondition(run.targets.map(\.sourceID).allSatisfy {
            $0 != "object-6" // Nested mounts change true object ordinal.
        })
        let first = run.targets[0]
        precondition(!run.recordContact(sourceID: "unknown", zoneID: first.zoneID))
        precondition(!run.recordContact(sourceID: first.zoneID, zoneID: first.sourceID))
        precondition(!run.recordContact(sourceID: first.sourceID, zoneID: "other-zone"))
        precondition(run.recordContact(sourceID: first.sourceID, zoneID: first.zoneID))
        precondition(!run.recordContact(sourceID: first.sourceID, zoneID: first.zoneID))
        precondition(run.deliveredCount == 1 && !run.isSatisfied)
        for target in run.targets.dropFirst() {
            precondition(run.recordContact(sourceID: target.sourceID,
                                           zoneID: target.zoneID))
        }
        precondition(run.deliveredCount == 4 && run.isSatisfied)
        precondition(run.targets.allSatisfy(run.isDelivered))
        precondition(run.storageKey.contains(String(repeating: "a", count: 64)))
        run.reset()
        precondition(run.deliveredCount == 0 && !run.isSatisfied)
        precondition(run.targets.allSatisfy { !run.isDelivered($0) })

        // Never apply level-one prototype rules to another original level
        // or to different data merely because there is a collection zone.
        let otherLevel = try document(2)
        let wrongTarget = try document(1, corruptSource: true)
        let noEditableBoards = try document(1, removeUnlock: true)
        precondition(CMOriginalFirstLevelRun(document: otherLevel) == nil)
        precondition(CMOriginalFirstLevelRun(document: wrongTarget) == nil)
        precondition(CMOriginalFirstLevelRun(document: noEditableBoards) == nil)

        // Actual Professor level 2 has one basketball CONNECTED_TO a
        // crate, plus three UNLOCKED dominoes. In particular, its tmo_zone
        // is not the linked target. These values were audited from the
        // user-owned scene, but the test fixture contains no original media.
        func secondDocument(
            level: Int = 2, targetIsZone: Bool = false,
            editableDominoes: Int = 3
        ) throws -> CMOriginalSceneDocument {
            func object(_ name: String, fields: [String]) -> [String: Any] {
                ["name": name, "fields": fields, "children": []]
            }
            var elements: [[String: Any]] = [
                object(targetIsZone ? "tmo_zone" : "tmo_crate",
                       fields: ["VALB \(targetIsZone ? 32 : 72)"]),
                object("tmo_ball_basket",
                       fields: ["CONNECTED_TO 0", "VALB 72"]),
                object("tmo_zone", fields: ["VALB 32"])
            ]
            for _ in 0..<editableDominoes {
                elements.append(object(
                    "tmo_domino", fields: ["UNLOCKED 1", "VALB 8"]))
            }
            let raw: [String: Any] = [
                "schema": "crazy-machines-original-scene-v1",
                "index": level,
                "title": "Synthetic original second-level relationship test",
                "scene_sha256": String(repeating: "c", count: 64),
                "root": [
                    "name": "level", "fields": [],
                    "children": [[
                        "name": "level_elements", "fields": [],
                        "children": elements
                    ]]
                ]
            ]
            return try CMOriginalSceneDocument.read(
                JSONSerialization.data(withJSONObject: raw))
        }
        let authenticSecondSignature = try secondDocument()
        guard var second = CMOriginalSecondLevelRun(
            document: authenticSecondSignature
        ) else {
            preconditionFailure("Second-level basket to crate signature absent")
        }
        let secondSession = CMOriginalGameplaySession(
            document: authenticSecondSignature)
        precondition(secondSession.originalConnections.count == 1)
        let onlyLink = secondSession.originalConnections[0]
        precondition(onlyLink.sourceType == "tmo_ball_basket")
        precondition(onlyLink.targetType == "tmo_crate")
        precondition(second.sourceID == onlyLink.sourceID)
        precondition(second.targetID == onlyLink.targetID)
        precondition(!second.isSatisfied)
        precondition(!second.recordContact(
            sourceID: second.targetID, targetID: second.sourceID))
        precondition(!second.recordContact(
            sourceID: second.sourceID, targetID: "another-crate"))
        precondition(second.recordContact(
            sourceID: second.sourceID, targetID: second.targetID))
        precondition(second.isSatisfied)
        precondition(!second.recordContact(
            sourceID: second.sourceID, targetID: second.targetID))
        precondition(second.storageKey.contains(
            String(repeating: "c", count: 64)))
        second.reset()
        precondition(!second.isSatisfied)
        // XCTest's precondition is a non-throwing autoclosure; construct
        // the failing signatures outside it so Swift 6 can typecheck.
        let wrongLevel = try secondDocument(level: 3)
        let wrongSecondTarget = try secondDocument(targetIsZone: true)
        let missingDomino = try secondDocument(editableDominoes: 2)
        precondition(CMOriginalSecondLevelRun(document: wrongLevel) == nil)
        precondition(CMOriginalSecondLevelRun(document: wrongSecondTarget) == nil)
        precondition(CMOriginalSecondLevelRun(document: missingDomino) == nil)

        // Genuine Professor level 3 has FIVE distinct crates linked to a
        // single zone and ONE unlocked spring. Negative variants must not
        // accidentally activate a collection challenge on other puzzles.
        func thirdDocument(
            level: Int = 3, crates: Int = 5,
            sourceIsBasket: Bool = false, editable: String = "tmo_spring"
        ) throws -> CMOriginalSceneDocument {
            func object(_ name: String, fields: [String]) -> [String: Any] {
                ["name": name, "fields": fields, "children": []]
            }
            var elements = [object("tmo_zone", fields: ["VALB 32"])]
            for _ in 0..<crates {
                elements.append(object(
                    sourceIsBasket ? "tmo_ball_basket" : "tmo_crate",
                    fields: ["CONNECTED_TO 0", "VALB 72"]))
            }
            elements.append(object(editable, fields: ["UNLOCKED 1"]))
            let scene: [String: Any] = [
                "schema": "crazy-machines-original-scene-v1",
                "index": level,
                "title": "Synthetic third original-level signature",
                "scene_sha256": String(repeating: "d", count: 64),
                "root": [
                    "name": "level", "fields": [],
                    "children": [[
                        "name": "level_elements", "fields": [],
                        "children": elements
                    ]]
                ]
            ]
            return try CMOriginalSceneDocument.read(
                JSONSerialization.data(withJSONObject: scene))
        }
        let thirdDocumentValid = try thirdDocument()
        guard var third = CMOriginalThirdLevelRun(
            document: thirdDocumentValid
        ) else {
            preconditionFailure("Level 3 five-crate original signature not detected")
        }
        precondition(third.totalCount == 5 && third.deliveredCount == 0)
        precondition(third.targets.allSatisfy { $0.zoneID == third.targets[0].zoneID })
        let firstCrate = third.targets[0]
        precondition(!third.recordContact(
            sourceID: firstCrate.zoneID, zoneID: firstCrate.sourceID))
        precondition(!third.recordContact(
            sourceID: "foreign-crate", zoneID: firstCrate.zoneID))
        precondition(!third.recordContact(
            sourceID: firstCrate.sourceID, zoneID: "wrong-zone"))
        precondition(third.recordContact(
            sourceID: firstCrate.sourceID, zoneID: firstCrate.zoneID))
        precondition(!third.recordContact(
            sourceID: firstCrate.sourceID, zoneID: firstCrate.zoneID))
        precondition(third.deliveredCount == 1 && !third.isSatisfied)
        for target in third.targets.dropFirst() {
            precondition(third.recordContact(
                sourceID: target.sourceID, zoneID: target.zoneID))
        }
        precondition(third.deliveredCount == 5 && third.isSatisfied)
        third.reset()
        precondition(third.deliveredCount == 0 && !third.isSatisfied)

        let levelFour = try thirdDocument(level: 4)
        let fourCrates = try thirdDocument(crates: 4)
        let wrongSourceKind = try thirdDocument(sourceIsBasket: true)
        let wrongEditable = try thirdDocument(editable: "tmo_domino")
        precondition(CMOriginalThirdLevelRun(document: levelFour) == nil)
        precondition(CMOriginalThirdLevelRun(document: fourCrates) == nil)
        precondition(CMOriginalThirdLevelRun(document: wrongSourceKind) == nil)
        precondition(CMOriginalThirdLevelRun(document: wrongEditable) == nil)
        print("Original linked-object prototypes for levels 1, 2 and 3: OK")
    }
}
