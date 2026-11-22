import Foundation

/// Reversible player edits to original UNLOCKED puzzle-object transforms.
/// Snapshots belong to the iPhone arrangement, not the original PC level
/// files or the experimental SceneKit physics simulation.
struct CMOriginalPlacementHistory {
    struct Pose: Equatable {
        let identifier: String
        let position: [Double]
        let rotation: [Double]

        init?(identifier: String, position: [Double], rotation: [Double]) {
            guard identifier.hasPrefix("original-node-"),
                  position.count == 3, rotation.count == 3,
                  position.allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }),
                  rotation.allSatisfy({ $0.isFinite && abs($0) <= 100_000 })
            else { return nil }
            self.identifier = identifier
            self.position = position
            self.rotation = rotation
        }
    }

    private let capacity: Int
    private var previous: [Pose] = []
    var canUndo: Bool { !previous.isEmpty }
    var count: Int { previous.count }

    init(capacity: Int = 20) {
        self.capacity = max(1, capacity)
    }

    @discardableResult
    mutating func record(before: Pose, after: Pose) -> Bool {
        guard before.identifier == after.identifier, before != after else {
            return false
        }
        previous.append(before)
        if previous.count > capacity {
            previous.removeFirst(previous.count - capacity)
        }
        return true
    }

    mutating func undo() -> Pose? {
        previous.popLast()
    }

    mutating func clear() {
        previous.removeAll(keepingCapacity: true)
    }
}
