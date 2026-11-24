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
        struct Node {
            let id: Int
            let parent: Int?
            let unlocked: Bool
        }
        let nodes = [
            Node(id: 0, parent: nil, unlocked: false),
            Node(id: 1, parent: 0, unlocked: true),
            Node(id: 2, parent: 1, unlocked: false),
            Node(id: 3, parent: 2, unlocked: false),
            Node(id: 4, parent: 0, unlocked: false),
            Node(id: 5, parent: 1, unlocked: true),
            Node(id: 6, parent: 5, unlocked: false)
        ]
        func editable(_ id: Int?) -> Int? {
            CMOriginalPlacementHistory.editableAncestor(
                startingAt: id, parent: { nodes[$0].parent },
                unlocked: { nodes[$0].unlocked })
        }
        for (id, expected) in [(0,nil),(1,1),(2,1),(3,1),(4,nil),(5,5),(6,5)] as [(Int,Int?)] {
            precondition(editable(id) == expected)
        }
        precondition(editable(nil) == nil)
        print("Original placement undo smoke passed")
    }
}
