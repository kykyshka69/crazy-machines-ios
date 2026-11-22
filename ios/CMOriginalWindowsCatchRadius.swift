import Foundation

/// Native CrazyMachines.exe 0x44D874–0x44D9A2 gives the distance rule
/// for GOAL-marked tmo_bucket and tmo_rope_cage objects.
/// It compares ball original transform +0x80 with the container
/// Test/Catch anchor +0x24 to immutable float 0.1 at 0x4E9BD8.
/// x87 test-ah-0x05 followed by JP at 0x44D98F rejects equality and
/// larger distances: only STRICTLY LESS THAN 0.1 dispatches GOAL.
/// Mapping the native Test/Catch anchor to an iOS marker remains separate.
public enum CMOriginalWindowsCatchRadius {
    public static let goalRadius: Float = 0.1

    public static func withinGoalRadius(
        ballX: Float, ballY: Float, ballZ: Float,
        targetX: Float, targetY: Float, targetZ: Float
    ) -> Bool {
        let fields = [ballX, ballY, ballZ, targetX, targetY, targetZ]
        guard fields.allSatisfy(\.isFinite) else { return false }
        let dx = ballX - targetX
        let dy = ballY - targetY
        let dz = ballZ - targetZ
        let distance = sqrt(dx * dx + dy * dy + dz * dz)
        return distance.isFinite && distance < goalRadius
    }
}
