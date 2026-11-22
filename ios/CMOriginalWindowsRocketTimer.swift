import Foundation

/// Verified Windows CrazyMachines.exe x86 original rocket sequence:
/// 0x44F03B–0x44F04E requires actual flying element +0xEC=2.
/// 0x44F1A2 selects the literal tmo_heat_rocket.
/// 0x44F288–0x44F2A7 subtracts engine launch time +0x130
/// from a real clock and requires elapsed STRICTLY GREATER than 3.0s.
/// After the genuine Engine/Explode effects, 0x44F33C stores +0xEC=3
/// and 0x44F354 invokes GOAL 0x44B460.
/// This does not create a fictional ignition or original rocket motion.
public enum CMOriginalWindowsRocketTimer {
    public static let flyingState: Float = 2
    public static let explodedState: Float = 3
    public static let fuseSeconds: Double = 3

    /// Only original, independently verified flying and engine states
    /// are eligible; a timer or GOAL annotation alone must not win.
    public static func readyToExplode(
        nativeRocketState: Float,
        nativeEnginePresent: Bool,
        engineTime: Double,
        originalLaunchTime: Double
    ) -> Bool {
        guard nativeEnginePresent, nativeRocketState.isFinite,
              nativeRocketState == flyingState, engineTime.isFinite,
              originalLaunchTime.isFinite,
              engineTime >= originalLaunchTime else { return false }
        let duration = engineTime - originalLaunchTime
        return duration.isFinite && duration > fuseSeconds
    }

    public static func terminalStateAfterObservedExplosion(
        nativeRocketState: Float,
        nativeEnginePresent: Bool,
        engineTime: Double,
        originalLaunchTime: Double
    ) -> Float? {
        readyToExplode(
            nativeRocketState: nativeRocketState,
            nativeEnginePresent: nativeEnginePresent,
            engineTime: engineTime,
            originalLaunchTime: originalLaunchTime
        ) ? explodedState : nil
    }
}
