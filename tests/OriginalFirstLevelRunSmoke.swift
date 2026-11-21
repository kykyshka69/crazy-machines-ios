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
        precondition(CMOriginalFirstLevelRun(document: try document(2)) == nil)
        precondition(CMOriginalFirstLevelRun(
            document: try document(1, corruptSource: true)) == nil)
        precondition(CMOriginalFirstLevelRun(
            document: try document(1, removeUnlock: true)) == nil)

        print("Original level-1 four-linked-object delivery objective: OK")
    }
}
