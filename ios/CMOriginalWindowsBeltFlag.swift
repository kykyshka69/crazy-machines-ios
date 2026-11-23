import Foundation

/// Win32 0x44F7CF–0x44FAA1: the belt flag is acted on by original wind
/// sources, not by stored wheel travel. [ebp-0x284] is an EBP-relative
/// per-invocation local wind sum, initialized to zero at 0x44F813.
/// It is NOT the object's +0x284 field or cumulative travel.
public enum CMOriginalWindowsBeltFlag {
    public static let nativeTelescopeMarker = Float(bitPattern: 0x3EC28F5C)
    public static let nativeWindCutoff: Float = 2
    public static let nativeWindScale: Float = 0.5

    public struct WindObservation {
        public let originalSourceID: String
        public let originalSourceType: String
        /// Signed result of original 0x409650 source-to-flag intersection.
        public let signedIntersection: Float
        /// Observed native source +0x40, NOT guessed wheel angular velocity.
        public let originalWindPower: Float

        public init(originalSourceID: String, originalSourceType: String,
                    signedIntersection: Float, originalWindPower: Float) {
            self.originalSourceID = originalSourceID
            self.originalSourceType = originalSourceType
            self.signedIntersection = signedIntersection
            self.originalWindPower = originalWindPower
        }
    }

    /// Build an actual Win32-style source observation from independently
    /// measured native region geometry and source power. Original 0x44F8F6
    /// reverses the sign if target region depth exceeds source depth.
    /// Never replace missing region parameters with mesh proximity.
    public static func observedSource(
        originalSourceID: String, originalSourceType: String,
        originalWindPower: Float, observedNativeRegion: CMOriginalWindowsWindRegion.Parameters,
        observedNativeDisplacement: CMOriginalWindowsWindRegion.Vector3,
        sourceDepth: Float, targetDepth: Float
    ) -> WindObservation? {
        guard sourceDepth.isFinite, targetDepth.isFinite,
              originalWindPower.isFinite,
              !originalSourceID.isEmpty,
              originalSourceType == "tmo_windmill"
                || originalSourceType == "tmo_wind_bellows",
              let fraction = CMOriginalWindowsWindRegion.measuredFraction(
                nativeDisplacement: observedNativeDisplacement,
                region: observedNativeRegion)
        else { return nil }
        let signed = targetDepth > sourceDepth ? -fraction : fraction
        return WindObservation(
            originalSourceID: originalSourceID,
            originalSourceType: originalSourceType,
            signedIntersection: signed,
            originalWindPower: originalWindPower)
    }

    /// Win32 0x44F858–0x44F932 enumerates tmo_windmill / tmo_wind_bellows
    /// and sums each physically intersecting wind contribution times 0.5.
    /// A complete observation with no sources is zero; an omitted or
    /// partial physical observation is UNKNOWN and must not credit GOAL.
    public static func nativeWindSum(
        observations: [WindObservation],
        requiredOriginalWindSourceIDs: Set<String>,
        allOriginalWindSourcesObserved: Bool
    ) -> Float? {
        guard allOriginalWindSourcesObserved,
              observations.count <= 1024,
              observations.count == requiredOriginalWindSourceIDs.count,
              !requiredOriginalWindSourceIDs.contains("") else {
            return nil
        }
        var sources = Set<String>()
        var result = Double(0)
        for observation in observations {
            guard !observation.originalSourceID.isEmpty,
                  requiredOriginalWindSourceIDs.contains(observation.originalSourceID),
              sources.insert(observation.originalSourceID).inserted,
                  observation.originalSourceType == "tmo_windmill"
                    || observation.originalSourceType == "tmo_wind_bellows",
                  observation.signedIntersection.isFinite,
                  abs(observation.signedIntersection) <= 1,
                  observation.originalWindPower.isFinite else { return nil }
            result += Double(observation.signedIntersection)
                * Double(observation.originalWindPower)
                * Double(nativeWindScale)
            guard result.isFinite,
                  abs(result) <= Double(Float.greatestFiniteMagnitude)
            else { return nil }
        }
        guard sources == requiredOriginalWindSourceIDs else { return nil }
        return Float(result)
    }

    /// Observed original flag and COMPLETE native wind-source set.
    /// The GOAL resolver recomputes netWind from actual original IDs.
    public struct PhysicalObservation {
        public let telescopeIndicator: Float
        public let flagState: Float
        public let windSources: [WindObservation]
        public let allOriginalSourcesObserved: Bool
        public init(telescopeIndicator: Float, flagState: Float,
                    windSources: [WindObservation],
                    allOriginalSourcesObserved: Bool) {
            self.telescopeIndicator = telescopeIndicator
            self.flagState = flagState
            self.windSources = windSources
            self.allOriginalSourcesObserved = allOriginalSourcesObserved
        }
    }

    public struct ObservedState {
        public let telescopeIndicator: Float // native second telescope +0x90
        public let flagState: Float           // native flag +0xEC
        /// Original [ebp-0x284] instantaneous summed WIND, not travel.
        public let observedNetWindForce: Float

        public init(telescopeIndicator: Float, flagState: Float,
                    observedNetWindForce: Float) {
            self.telescopeIndicator = telescopeIndicator
            self.flagState = flagState
            self.observedNetWindForce = observedNetWindForce
        }
    }

    /// Two native 0x44FA58/0x44FAA1 branches with opposite |wind| bounds.
    /// Inputs require actual measured original wind and telescope state.
    public static func triggersGoal(_ state: ObservedState) -> Bool {
        guard state.telescopeIndicator.isFinite, state.flagState.isFinite,
              state.observedNetWindForce.isFinite,
              state.flagState == 0 else { return false }
        let windMagnitude = abs(Double(state.observedNetWindForce))
        if state.telescopeIndicator == nativeTelescopeMarker {
            return windMagnitude >= Double(nativeWindCutoff)
        }
        return windMagnitude < Double(nativeWindCutoff)
    }
}
