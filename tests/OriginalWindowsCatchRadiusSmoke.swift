import Foundation

@main
struct OriginalWindowsCatchRadiusSmoke {
    static func main() {
        typealias Catch = CMOriginalWindowsCatchRadius
        func inside(_ x: Float, _ y: Float, _ z: Float = 0) -> Bool {
            Catch.withinGoalRadius(
                ballX: x, ballY: y, ballZ: z,
                targetX: 0, targetY: 0, targetZ: 0
            )
        }
        precondition(Catch.goalRadius == 0.1)
        precondition(inside(0, 0))
        precondition(inside(0.0999, 0))
        precondition(inside(0.05, 0.05))
        // Original x87 test-ah-05 at 0x44D98F SKIPS equality.
        precondition(!inside(0.1, 0))
        precondition(!inside(-0.1, 0))
        precondition(!inside(0.08, 0.08))
        precondition(!inside(0, 0, 0.1001))
        precondition(!inside(.nan, 0))
        precondition(!inside(.infinity, 0))
        precondition(!Catch.withinGoalRadius(
            ballX: 0, ballY: 0, ballZ: 0,
            targetX: 0, targetY: .nan, targetZ: 0
        ))
        print("Authentic native Win32 0x44D9A2 GOAL Catch/Test strict radius 0.1 validated")
    }
}
