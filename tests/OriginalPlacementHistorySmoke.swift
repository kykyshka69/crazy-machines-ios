import Foundation

@main
struct OriginalPlacementHistorySmoke {
    static func main() {
        func pose(_ id: String, _ x: Double, _ rotation: Double = 0) -> CMOriginalPlacementHistory.Pose {
            guard let value = CMOriginalPlacementHistory.Pose(
                identifier: "original-node-\(id)", position: [x, 2, 0],
                rotation: [0, 0, rotation]) else { fatalError("Bad test pose") }
            return value
        }
        var history = CMOriginalPlacementHistory(capacity: 3)
        assert(!history.canUndo && history.undo() == nil)
        assert(!history.record(before: pose("5", 1), after: pose("5", 1)))
        assert(!history.record(before: pose("5", 1), after: pose("6", 2)))
        assert(history.record(before: pose("5", 1), after: pose("5", 2)))
        assert(history.record(before: pose("5", 2), after: pose("5", 2, 1)))
        assert(history.record(before: pose("8", 0), after: pose("8", 3)))
        assert(history.record(before: pose("9", 3), after: pose("9", 4)))
        assert(history.count == 3)
        assert(history.undo() == pose("9", 3))
        assert(history.undo() == pose("8", 0))
        assert(history.undo() == pose("5", 2))
        assert(history.undo() == nil && !history.canUndo)
        assert(history.record(before: pose("5", 0), after: pose("5", 1)))
        history.clear()
        assert(!history.canUndo)
        assert(CMOriginalPlacementHistory.Pose(identifier: "../../escape", position: [0, 0, 0], rotation: [0, 0, 0]) == nil)
        assert(CMOriginalPlacementHistory.Pose(identifier: "original-node-1", position: [Double.infinity, 0, 0], rotation: [0, 0, 0]) == nil)
        assert(CMOriginalPlacementHistory.Pose(identifier: "original-node-1", position: [0, 0, 0], rotation: [0, Double.nan, 0]) == nil)
        print("Original placement undo smoke passed")
    }
}
