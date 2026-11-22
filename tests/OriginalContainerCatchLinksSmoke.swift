import Foundation

@main
struct OriginalContainerCatchLinksSmoke {
    static func main() throws {
        func item(_ name: String, _ fields: [String] = []) -> [String: Any] {
            ["name": name, "fields": fields, "children": []]
        }
        let root: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 26, "title": "Synthetic original-format ball Catch/Test refs",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    item("tmo_ball_basket", ["CONNECTED_TO 1"]),
                    item("tmo_rope_cage"),                      // no GOAL
                    item("tmo_ball_steel", ["CONNECTED_TO 3"]),
                    item("tmo_bucket", ["GOAL 1"]),
                    item("tmo_ball_tennis", ["CONNECTED_TO 3"]),
                    item("tmo_crate", ["CONNECTED_TO 3"]),      // not a ball
                    item("tmo_ball_billard", ["CONNECTED_TO 7"]),
                    item("tmo_zone"),                           // not a catch
                    item("tmo_ball_basket", ["CONNECTED_TO 7"])
                ]]
            ]]
        ]
        let doc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: root))
        let session = CMOriginalGameplaySession(document: doc)
        let ids = session.objects.map(\.id)
        let plan = CMOriginalContainerCatchLinks(session: session)
        precondition(plan.goalContainerKindsByID == [ids[3]:"tmo_bucket"])
        precondition(plan.watchedContainerIDs == Set([ids[1], ids[3]]))
        precondition(plan.linkedSourcesByTargetID[ids[1]] == [ids[0]])
        precondition(plan.linkedSourcesByTargetID[ids[3]] == [ids[2], ids[4]])
        precondition(plan.acceptsOriginalLinkedBall(
            sourceID: ids[0], targetID: ids[1]))
        precondition(plan.acceptsOriginalLinkedBall(
            sourceID: ids[2], targetID: ids[3]))
        precondition(plan.acceptsOriginalLinkedBall(
            sourceID: ids[4], targetID: ids[3]))
        precondition(!plan.acceptsOriginalLinkedBall(
            sourceID: ids[0], targetID: ids[3]))
        precondition(!plan.acceptsOriginalLinkedBall(
            sourceID: ids[5], targetID: ids[3]))
        precondition(!plan.acceptsOriginalLinkedBall(
            sourceID: ids[6], targetID: ids[7]))
        precondition(!plan.acceptsOriginalLinkedBall(
            sourceID: ids[8], targetID: ids[7]))
        print("Exact original CONNECTED_TO ball-to-bucket/cage mapping: wall touches cannot win")
    }
}
