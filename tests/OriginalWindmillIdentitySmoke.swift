import Foundation

@main
struct OriginalWindmillIdentitySmoke {
    static func main() throws {
        func part(_ kind: String, children: [[String: Any]] = [],
                  goal: Bool = false) -> [String: Any] {
            // The actual exporter preserves goal_raw separately from the
            // original GOAL field; both must be included in a fixture.
            var node: [String: Any] = [
                "name": kind, "fields": goal ? ["GOAL 1"] : [],
                "children": children
            ]
            if goal { node["goal_raw"] = "1" }
            return node
        }
        let raw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 34,
            "title": "Copyright-free original-format wing/gear scene",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": part("level", children: [
                part("level_elements", children: [
                    part("tmo_windmill", children: [
                        part("tmo_windmill_base"),
                        part("tmo_windmill_wings"),
                        part("tmo_windmill_wheel")
                    ], goal: true),
                    part("tmo_belt_flag", children: [
                        part("tmo_belt_flag_wheel")
                    ], goal: true)
                ])
            ])
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        let session = CMOriginalGameplaySession(document: document)
        let windmill = session.objects.first { $0.type == "tmo_windmill" }!
        let wings = session.objects.first { $0.type == "tmo_windmill_wings" }!
        let transmissionWheel = session.objects.first {
            $0.type == "tmo_windmill_wheel"
        }!
        precondition(wings.parentID == windmill.id)
        precondition(transmissionWheel.parentID == windmill.id)
        precondition(wings.id != transmissionWheel.id)
        precondition(CMOriginalAxleParts.rotatingKinds.contains(wings.type))
        precondition(CMOriginalAxleParts.rotatingKinds.contains(
            transmissionWheel.type))
        precondition(windmill.goalAnnotation == "1")
        precondition(wings.goalAnnotation == nil)
        precondition(transmissionWheel.goalAnnotation == nil)
        precondition(CMOriginalWindowsWindmill.triggersGoal(
            nativeWingsSignal: 0.4))
        print("Original windmill GOAL source = wings +0xE0, not gear wheel")
    }
}
