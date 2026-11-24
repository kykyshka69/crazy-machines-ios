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
              state.observedNetWindForce.isFinite else { return false }
        let windMagnitude = abs(Double(state.observedNetWindForce))
        if state.telescopeIndicator == nativeTelescopeMarker {
            return state.flagState == 0 && windMagnitude >= Double(nativeWindCutoff)
        }
        return state.flagState != 0 && windMagnitude < Double(nativeWindCutoff)
    }

    /// 0x44F993–0x44F9E2: both telescopes get abs(wheel.+E8 * .05).
    /// 0x44FAA6–0x44FB01: positive wheel signal selects .38, else 0.
    /// Integrate the native command using SceneKit seconds as a
    /// provisional clock correspondence; no instantaneous teleport.
    public static func nextExtension(previous: Float, wheelSignal: Float,
                                     delta: Double) -> Float? {
        guard previous.isFinite, (0...nativeTelescopeMarker).contains(previous),
              wheelSignal.isFinite, abs(wheelSignal) <= 80,
              delta.isFinite, delta >= 0, delta <= 0.25 else { return nil }
        let distance = abs(wheelSignal * Float(bitPattern: 0x3D4CCCCD)) * Float(delta)
        return wheelSignal > 0 ? min(nativeTelescopeMarker, previous + distance)
                              : max(0, previous - distance)
    }

    /// Native windmill 0x44BB78 stores the signed wheel signal at +40;
    /// 0x44BBE4–0x44BBF4 sets the cone extension to abs(signal)*.2.
    /// Constructor 0x45480B–0x454833 uses 15 degrees and near scale 1.5.
    public static func windmillRegion(axis: CMOriginalWindowsWindRegion.Vector3,
                                      wheelSignal: Float) -> CMOriginalWindowsWindRegion.Parameters? {
        guard axis.x.isFinite, axis.y.isFinite, wheelSignal.isFinite,
              abs(wheelSignal) <= 80, wheelSignal != 0 else { return nil }
        let angle: Float = 15 * 0.01745329238474369
        let near = abs(tan(Float(90) + angle) * 1.5)
        let outer = near + abs(wheelSignal) * 0.2
        let lo = near * near, hi = outer * outer
        guard lo.isFinite, hi.isFinite, hi > lo else { return nil }
        let sign: Float = wheelSignal > 0 ? 1 : -1
        return .init(nativeAxis: .init(axis.x * sign, axis.y * sign, 0),
                     minRadiusSquared: lo, maxRadiusSquared: hi,
                     radialFalloff: 1 / (hi-lo), maximumAngle: angle,
                     angularFalloff: 1 / angle)
    }
}


/// Original bellows state: 0 ready, 1 exhausting, 2 spent.
/// Win32 0x444C96–0x444D22 sets power 5 on a qualifying lever
/// collision; 0x44DB4D–0x44DC8E decays power by 30*dt and scales
/// the lever's captured angle by remaining power/5.
public struct CMOriginalBellows {
    public enum Phase { case ready, exhausting, spent }
    public private(set) var phase: Phase = .ready
    public private(set) var power: Float = 0
    public private(set) var capturedAngle: Float = 0
    public private(set) var rangeExtension: Float = 0
    public init() {}

    @discardableResult
    public mutating func strike(normalY: Float, leverAngle: Float) -> Bool {
        guard phase == .ready, normalY.isFinite, normalY > Float(bitPattern: 0x3F666666),
              leverAngle.isFinite else { return false }
        phase = .exhausting
        power = 5
        capturedAngle = leverAngle
        return true
    }

    @discardableResult
    public mutating func advance(delta: Double) -> Bool {
        guard delta.isFinite, delta >= 0, delta <= 0.25 else { return false }
        guard phase == .exhausting else { return true }
        rangeExtension = power * 0.5
        power = max(0, Float(Double(power) - 30 * delta))
        if power == 0 {
            rangeExtension = 0
            phase = .spent
        }
        return true
    }

    public var leverAngle: Float { capturedAngle * power / 5 }

    /// Native bellows constructor 0x454A27..0x454A4F.
    public func region(axis: CMOriginalWindowsWindRegion.Vector3)
        -> CMOriginalWindowsWindRegion.Parameters? {
        guard phase == .exhausting, rangeExtension > 0,
              axis.x.isFinite, axis.y.isFinite,
              axis.x*axis.x + axis.y*axis.y > 0 else { return nil }
        let angle: Float = 15 * 0.01745329238474369
        let near = abs(tan(Float(90) + angle) * 0.5)
        let outer = near + rangeExtension
        let lo = near*near, hi = outer*outer
        guard hi.isFinite, hi > lo else { return nil }
        return .init(nativeAxis: axis, minRadiusSquared: lo,
                     maxRadiusSquared: hi, radialFalloff: 1/(hi-lo),
                     maximumAngle: angle, angularFalloff: 1/angle)
    }
}


/// Verified wind receiver dispatch 0x44F528–0x44F7C0.
/// No generic force on arbitrary loose bodies is inferred from this branch.
public enum CMOriginalWindReceiver {
    /// 0x44F749–0x44F775, fabs at 0x409D30 (CRT clears sign bit).
    public static func extinguishesCandle(lit: Bool, fraction: Float, power: Float) -> Bool {
        guard lit, fraction.isFinite, (0...1).contains(fraction),
              power.isFinite else { return false }
        return abs(Double(fraction) * Double(power)) > 2.5
    }

    /// 0x44F5A5–0x44F5F5: receiver power = fraction*sourcePower*.75;
    /// wings target = -source.+104 * receiverPower * receiver.+104.
    public static func wingsTarget(fraction: Float, power: Float,
                                   sourceMirror: Float, receiverMirror: Float) -> Float? {
        guard fraction.isFinite, (0...1).contains(fraction),
              power.isFinite, abs(power) <= 80,
              abs(sourceMirror) == 1, abs(receiverMirror) == 1 else { return nil }
        return -sourceMirror * fraction * power * 0.75 * receiverMirror
    }

    /// 0x44F601–0x44F639 native scalar approaches target by dt.
    public static func nextWingsSignal(previous: Float, target: Float, delta: Double) -> Float? {
        guard previous.isFinite, target.isFinite, delta.isFinite,
              delta >= 0, delta <= 0.25 else { return nil }
        let next = Double(previous) + (Double(target) - Double(previous)) * delta
        guard next.isFinite, abs(next) <= Double(Float.greatestFiniteMagnitude) else { return nil }
        return Float(next)
    }
}
