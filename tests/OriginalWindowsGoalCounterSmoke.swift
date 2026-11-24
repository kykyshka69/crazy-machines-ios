import Foundation

@main
struct OriginalWindowsGoalCounterSmoke {
    static func main() throws {
        func doc(goal: Bool = true, connection: Bool = true,
                 index: Int = 4) throws -> CMOriginalSceneDocument {
            func object(_ type: String, _ fields: [String]) -> [String: Any] {
                ["name": type, "fields": fields, "children": []]
            }
            let objects = [
                object("tmo_ball_tennis", connection
                       ? ["CONNECTED_TO 1", "VALB 72"] : ["VALB 72"]),
                object("tmo_bucket", goal ? ["GOAL 1", "VALB 104"] : ["VALB 104"]),
                object("tmo_magnetic_permanent", ["UNLOCKED 1"])
            ]
            let raw: [String: Any] = [
                "schema": "crazy-machines-original-scene-v1",
                "index": index, "title": "Metadata-only original-format fixture",
                "scene_sha256": String(repeating: "d", count: 64),
                "root": ["name": "level", "fields": [], "children": [
                    ["name": "level_elements", "fields": [], "children": objects]
                ]]
            ]
            return try CMOriginalSceneDocument.read(
                JSONSerialization.data(withJSONObject: raw))
        }
        let session = CMOriginalGameplaySession(document: try doc())
        precondition(session.originalConnections.count == 1)
        guard var counter = CMOriginalWindowsGoalCounter(session: session) else {
            fatalError("Actual GOAL/CONNECTED_TO metadata must produce win inputs")
        }
        precondition(counter.totalRequired == 2)
        precondition(counter.requiredGoalCount == 1)
        precondition(counter.requiredConnectionCount == 1)
        let ownerLink = session.originalConnections[0]
        precondition(session.linkedCollisionInputs(ownerLink.sourceID, ownerLink.targetID) == [ownerLink])
        precondition(session.linkedCollisionInputs(ownerLink.targetID, ownerLink.sourceID) == [ownerLink])
        precondition(session.linkedCollisionInputs(ownerLink.sourceID, "unknown").isEmpty)
        precondition(session.linkedCollisionInputs(ownerLink.sourceID, ownerLink.sourceID).isEmpty)
        let nestedRaw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 5, "title": "Synthetic compound collision owners",
            "scene_sha256": String(repeating: "f", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    ["name": "tmo_domino", "fields": ["CONNECTED_TO 1"], "children": [
                        ["name": "tmo_mount_wood", "fields": [], "children": []]
                    ]],
                    ["name": "tmo_light_pocketlamp", "fields": [], "children": [
                        ["name": "tmo_light_pocketlamp_bulb", "fields": [], "children": []]
                    ]],
                    ["name": "tmo_crate", "fields": [], "children": []]
                ]]
            ]]
        ]
        let nested = CMOriginalGameplaySession(document: try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: nestedRaw)))
        let nativeLink = nested.originalConnections[0]
        let childA = nested.objects.first { $0.type == "tmo_mount_wood" }!.id
        let childB = nested.objects.first { $0.type == "tmo_light_pocketlamp_bulb" }!.id
        let unrelated = nested.objects.first { $0.type == "tmo_crate" }!.id
        precondition(nested.linkedCollisionInputs(childA, childB) == [nativeLink])
        precondition(nested.linkedCollisionInputs(childB, childA) == [nativeLink])
        precondition(nested.linkedCollisionInputs(childA, nativeLink.sourceID).isEmpty)
        precondition(nested.linkedCollisionInputs(childA, unrelated).isEmpty)
        let link = session.originalConnections[0]
        let bucket = session.objects.first { $0.type == "tmo_bucket" }!.id
        precondition(counter.recordGoalEvent(objectID: bucket,
                                             simulationRunning: false) == .ignored)
        precondition(counter.recordGoalEvent(objectID: "wrong",
                                             simulationRunning: true) == .ignored)
        precondition(counter.recordConnectedToEvent(
            sourceID: link.targetID, targetID: link.sourceID,
            simulationRunning: true) == .ignored)
        precondition(counter.recordConnectedToEvent(
            sourceID: link.sourceID, targetID: "wrong",
            simulationRunning: true) == .ignored)
        precondition(counter.recordConnectedToEvent(
            sourceID: link.sourceID, targetID: link.targetID,
            simulationRunning: true) == .credited)
        precondition(counter.credited == 1 && !counter.completed)
        precondition(counter.recordConnectedToEvent(
            sourceID: link.sourceID, targetID: link.targetID,
            simulationRunning: true) == .ignored)
        precondition(counter.recordGoalEvent(
            objectID: bucket, simulationRunning: true) == .allInputsCredited)
        precondition(counter.completed && counter.credited == 2)
        precondition(counter.recordGoalEvent(
            objectID: bucket, simulationRunning: true) == .ignored)
        counter.reset()
        precondition(counter.credited == 0 && !counter.completed)
        // Windows counts GOAL and CONNECTED_TO as independent channels.
        guard var alone = CMOriginalWindowsGoalCounter(
            session: CMOriginalGameplaySession(document: try doc(connection: false))) else {
            fatalError("GOAL-only original object should be tracked")
        }
        precondition(alone.totalRequired == 1)
        precondition(alone.recordGoalEvent(
            objectID: bucket, simulationRunning: true) == .allInputsCredited)
        guard let connectedOnly = CMOriginalWindowsGoalCounter(
            session: CMOriginalGameplaySession(document: try doc(goal: false))) else {
            fatalError("CONNECTED_TO-only level must be tracked")
        }
        precondition(connectedOnly.totalRequired == 1)
        let empty = try doc(goal: false, connection: false)
        precondition(CMOriginalWindowsGoalCounter(
            session: CMOriginalGameplaySession(document: empty)) == nil)
        // Original hammer owner contributes a GOAL input, never its nail.
        // The scissors callsite exists in native code but unmarked owners
        // do not increment the counter (as in all eight genuine levels).
        let rawHammer: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 9, "title": "Synthetic hammer terminal GOAL identity",
            "scene_sha256": String(repeating: "e", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    ["name": "tmo_hammer", "fields": ["GOAL 1"], "children": [
                        ["name": "tmo_hammer_nail", "fields": [], "children": []]
                    ]],
                    ["name": "tmo_rope_scissors", "fields": [], "children": []]
                ]]
            ]]
        ]
        let hammerSession = CMOriginalGameplaySession(document: try
            CMOriginalSceneDocument.read(JSONSerialization.data(withJSONObject: rawHammer)))
        var hammerCounter = CMOriginalWindowsGoalCounter(session: hammerSession)!
        let hammer = hammerSession.objects.first { $0.type == "tmo_hammer" }!.id
        let nail = hammerSession.objects.first { $0.type == "tmo_hammer_nail" }!.id
        let scissors = hammerSession.objects.first { $0.type == "tmo_rope_scissors" }!.id
        precondition(hammerCounter.recordGoalEvent(objectID: nail, simulationRunning: true) == .ignored)
        precondition(hammerCounter.recordGoalEvent(objectID: scissors, simulationRunning: true) == .ignored)
        precondition(hammerCounter.recordGoalEvent(objectID: hammer, simulationRunning: false) == .ignored)
        precondition(hammerCounter.recordGoalEvent(objectID: hammer, simulationRunning: true) == .allInputsCredited)
        precondition(hammerCounter.recordGoalEvent(objectID: hammer, simulationRunning: true) == .ignored)
        hammerCounter.reset()
        precondition(!hammerCounter.completed && hammerCounter.credited == 0)
        precondition(hammerCounter.recordGoalEvent(objectID: hammer, simulationRunning: true) == .allInputsCredited)
        print("Original Win32 GOAL/CONNECTED_TO two-channel level-completion counter passed")
    }
}