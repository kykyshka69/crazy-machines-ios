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
    public static let ignitedState: Float = 1
    public static let flyingState: Float = 2
    public static let explodedState: Float = 3
    public static let fuseSeconds: Double = 3

    /// Win32 0x44EC48..0x44EC83: parent +0xEC==1 uses its OWN
    /// ignition timestamp +0x130. Only after STRICTLY >3.0 seconds
    /// (not at equality) does 0x44EE2B select the actual rocket kind.
    /// The heat-collision/thermal rule that sets state 1 is NOT decoded.
    public static func readyToLaunch(
        nativeRocketState: Float,
        nativeObjectType: String,
        clockTime: Double,
        originalIgnitionTime: Double
    ) -> Bool {
        guard nativeObjectType == "tmo_heat_rocket",
              nativeRocketState.isFinite,
              nativeRocketState == ignitedState,
              clockTime.isFinite, originalIgnitionTime.isFinite,
              clockTime >= originalIgnitionTime else { return false }
        let elapsed = clockTime - originalIgnitionTime
        return elapsed.isFinite && elapsed > fuseSeconds
    }

    /// At 0x44EF59..0x44EF73 the ORIGINAL Engine child starts with a
    /// separate launch timestamp. Only after its actual physical action
    /// does 0x44F029 write the parent +0xEC=2. A timer alone is not thrust.
    public static func flyingStateAfterObservedLaunch(
        nativeRocketState: Float,
        nativeObjectType: String,
        clockTime: Double,
        originalIgnitionTime: Double,
        originalEngineChildActivated: Bool
    ) -> Float? {
        guard originalEngineChildActivated,
              readyToLaunch(
                nativeRocketState: nativeRocketState,
                nativeObjectType: nativeObjectType,
                clockTime: clockTime,
                originalIgnitionTime: originalIgnitionTime)
        else { return nil }
        return flyingState
    }

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
        originalLaunchTime: Double,
        originalExplosionEffectObserved: Bool = false
    ) -> Float? {
        guard originalExplosionEffectObserved else { return nil }
        return readyToExplode(
            nativeRocketState: nativeRocketState,
            nativeEnginePresent: nativeEnginePresent,
            engineTime: engineTime,
            originalLaunchTime: originalLaunchTime
        ) ? explodedState : nil
    }

    /// Native GOAL 0x44F354 happens AFTER Engine/Explode activity and
    /// parent state +0xEC=3 (0x44F33C). The clock by itself cannot win.
    public struct ObservedExplosion {
        public let nativeRocketState: Float
        public let nativeEnginePresent: Bool
        public let engineTime: Double
        public let originalLaunchTime: Double
        public let actualExplosionEffectObserved: Bool

        public init(nativeRocketState: Float, nativeEnginePresent: Bool,
                    engineTime: Double, originalLaunchTime: Double,
                    actualExplosionEffectObserved: Bool) {
            self.nativeRocketState = nativeRocketState
            self.nativeEnginePresent = nativeEnginePresent
            self.engineTime = engineTime
            self.originalLaunchTime = originalLaunchTime
            self.actualExplosionEffectObserved = actualExplosionEffectObserved
        }
    }

    public static func triggersGoal(_ observed: ObservedExplosion) -> Bool {
        observed.actualExplosionEffectObserved
            && readyToExplode(
                nativeRocketState: observed.nativeRocketState,
                nativeEnginePresent: observed.nativeEnginePresent,
                engineTime: observed.engineTime,
                originalLaunchTime: observed.originalLaunchTime)
    }
}
