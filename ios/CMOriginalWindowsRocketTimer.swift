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
    // Native x86 0x44E3C6..0x44E3D7 compares the physically measured
    // 0x409650 heat-region fraction STRICTLY ABOVE 0x4EDDE8. 0.84
    // exactly fails. This is not a generic visual/flame contact.
    public static let candleIgnitionCutoff = Float(bitPattern: 0x3F570A3D)

    /// One confirmed Win32 source branch: a LIT tmo_candle (0x44E112)
    /// intersects the authentic rocket's selector-3 heat region.
    /// 0x44E36C requires target +0xEC==0. 0x409650 reports actual
    /// region overlap, not geometry proximity; 0x44E3D7 requires >0.84.
    /// Other heat-emitter kinds/thermal propagation are not claimed.
    public static func acceptsObservedCandleIgnition(
        nativeRocketType: String,
        nativeRocketState: Float,
        nativeHeatSourceType: String,
        originalCandleLit: Bool,
        measuredNativeHeatFraction: Float
    ) -> Bool {
        nativeRocketType == "tmo_heat_rocket"
            && nativeRocketState.isFinite && nativeRocketState == 0
            && nativeHeatSourceType == "tmo_candle"
            && originalCandleLit && measuredNativeHeatFraction.isFinite
            && measuredNativeHeatFraction >= 0
            && measuredNativeHeatFraction <= 1
            && measuredNativeHeatFraction > candleIgnitionCutoff
    }

    /// Original helper 0x44CD30 writes target state 1 and captures the
    /// true native clock in parent +0x130 only AFTER the physical
    /// ignition/effect action. A region scalar alone is not an ignition.
    public struct ObservedIgnition {
        public let state: Float
        public let ignitionTime: Double
    }
    public static func ignitionAfterObservedCandleEffect(
        nativeRocketType: String, nativeRocketState: Float,
        nativeHeatSourceType: String, originalCandleLit: Bool,
        measuredNativeHeatFraction: Float,
        originalIgnitionEffectObserved: Bool,
        observedNativeClock: Double
    ) -> ObservedIgnition? {
        guard originalIgnitionEffectObserved, observedNativeClock.isFinite,
              acceptsObservedCandleIgnition(
                nativeRocketType: nativeRocketType,
                nativeRocketState: nativeRocketState,
                nativeHeatSourceType: nativeHeatSourceType,
                originalCandleLit: originalCandleLit,
                measuredNativeHeatFraction: measuredNativeHeatFraction)
        else { return nil }
        return ObservedIgnition(state: ignitedState,
                                ignitionTime: observedNativeClock)
    }

    /// Original Win32 0x44E39D: selector-3 native heat-region intersection
    /// uses the same 0x409650 evaluator as wind. Never infer thermal
    /// ignition from UCM mesh proximity or an unmeasured source.
    public static func ignitionAfterObservedNativeCandleRegion(
        nativeRocketState: Float,
        nativeHeatSourceType: String,
        originalCandleLit: Bool,
        observedNativeHeatRegion: CMOriginalWindowsWindRegion.Parameters,
        observedNativeDisplacement: CMOriginalWindowsWindRegion.Vector3,
        originalIgnitionEffectObserved: Bool,
        observedNativeClock: Double
    ) -> ObservedIgnition? {
        guard let fraction = CMOriginalWindowsWindRegion.measuredFraction(
            nativeDisplacement: observedNativeDisplacement,
            region: observedNativeHeatRegion) else { return nil }
        return ignitionAfterObservedCandleEffect(
            nativeRocketType: "tmo_heat_rocket",
            nativeRocketState: nativeRocketState,
            nativeHeatSourceType: nativeHeatSourceType,
            originalCandleLit: originalCandleLit,
            measuredNativeHeatFraction: fraction,
            originalIgnitionEffectObserved: originalIgnitionEffectObserved,
            observedNativeClock: observedNativeClock)
    }


    /// Both original objects must use their OWN first linked selector-3
    /// native region (0x44E12E and 0x44E3A4, via 0x420360).
    /// Recorded physical geometry may not be borrowed from any adjacent
    /// or unmatched native region; missing records fail closed.
    public static func ignitionAfterObservedSelectedCandleRegions(
        nativeRocketState: Float,
        nativeHeatSourceType: String,
        originalCandleLit: Bool,
        sourceNativeRegionRecords: [CMOriginalWindowsRegionSelector.Entry],
        rocketNativeRegionRecords: [CMOriginalWindowsRegionSelector.Entry],
        observedSourceRegionRecordIndex: Int,
        observedRocketRegionRecordIndex: Int,
        observedNativeHeatRegion: CMOriginalWindowsWindRegion.Parameters,
        observedNativeDisplacement: CMOriginalWindowsWindRegion.Vector3,
        originalIgnitionEffectObserved: Bool,
        observedNativeClock: Double
    ) -> ObservedIgnition? {
        guard let source = CMOriginalWindowsRegionSelector
                    .matchingEntryIndex(in: sourceNativeRegionRecords),
              let target = CMOriginalWindowsRegionSelector
                    .matchingEntryIndex(in: rocketNativeRegionRecords),
              source == observedSourceRegionRecordIndex,
              target == observedRocketRegionRecordIndex else { return nil }
        return ignitionAfterObservedNativeCandleRegion(
            nativeRocketState: nativeRocketState,
            nativeHeatSourceType: nativeHeatSourceType,
            originalCandleLit: originalCandleLit,
            observedNativeHeatRegion: observedNativeHeatRegion,
            observedNativeDisplacement: observedNativeDisplacement,
            originalIgnitionEffectObserved: originalIgnitionEffectObserved,
            observedNativeClock: observedNativeClock)
    }

    public static let flyingState: Float = 2
    public static let explodedState: Float = 3
    public static let fuseSeconds: Double = 3

    /// Win32 0x44EC48..0x44EC83: parent +0xEC==1 uses its OWN
    /// ignition timestamp +0x130. Only after STRICTLY >3.0 seconds
    /// (not at equality) does 0x44EE2B select the actual rocket kind.
    /// Candle-to-rocket ignition >0.84 is decoded above; other native
    /// heat producers and the SceneKit native-region sampler are not.
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
