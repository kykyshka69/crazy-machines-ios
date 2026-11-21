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

        print("Original level-1 four-linked-object delivery objective: OK")
    }
}
