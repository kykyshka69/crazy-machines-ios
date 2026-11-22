import Foundation

@main
struct OriginalFourthLevelRunSmoke {
    static func main() throws {
        func doc(index: Int = 4, goal: Bool = true,
                 unlocked: Bool = true, ball: String = "tmo_ball_tennis",
                 connected: Bool = false) throws -> CMOriginalSceneDocument {
            func part(_ type: String, _ fields: [String]) -> [String: Any] {
                ["name": type, "fields": fields, "children": []]
            }
            let pieces = [
                part(ball, ["VALB 72"] + (connected ? ["CONNECTED_TO 1"] : [])),
                part("tmo_bucket", ["VALB 104"] + (goal ? ["GOAL 1"] : [])),
                part("tmo_magnetic_permanent", ["VALB 64"] +
                     (unlocked ? ["UNLOCKED 1"] : []))
            ]
            let raw: [String: Any] = [
                "schema": "crazy-machines-original-scene-v1",
                "index": index, "title": "Synthetic metadata-only level four",
                "scene_sha256": String(repeating: "e", count: 64),
                "root": ["name": "level", "fields": [], "children": [
                    ["name": "level_elements", "fields": [], "children": pieces]
                ]]
            ]
            return try CMOriginalSceneDocument.read(
                JSONSerialization.data(withJSONObject: raw))
        }
        guard var run = CMOriginalFourthLevelRun(document: try doc()) else {
            fatalError("Original GOAL bucket and movable magnet not recognized")
        }
        precondition(!run.isSatisfied)
        precondition(!run.recordCapture(ballID: "wrong", bucketID: run.bucketID))
        precondition(!run.recordCapture(ballID: run.ballID, bucketID: "wrong"))
        precondition(run.recordCapture(ballID: run.ballID, bucketID: run.bucketID))
        precondition(run.isSatisfied)
        precondition(!run.recordCapture(ballID: run.ballID, bucketID: run.bucketID))
        run.reset()
        precondition(!run.isSatisfied)
        let negatives = try [
            doc(index: 5), doc(goal: false), doc(unlocked: false),
            doc(ball: "tmo_ball_golf"), doc(connected: true)
        ]
        for mismatch in negatives {
            precondition(CMOriginalFourthLevelRun(document: mismatch) == nil)
        }
        print("Original level-four GOAL bucket model and capture tracking passed")
    }
}
