import Foundation

/// A SINGLE real-native rocket Engine force sample for one SceneKit physics
/// update. Its fields are observations, not the original CML template's
/// VALF/VELOCITY defaults. An unevidenced Engine cannot move the rocket.
public enum CMOriginalRocketForceDelivery {
    public struct Observation {
        /// Increasing native simulation sample ID. Replaying the same
        /// SwiftUI snapshot must not re-apply a physical force.
        public let nativeSampleSequence: UInt64
        public let rocketParentID: String
        public let rocketChildID: String
        public let nativeParentState: Float
        public let actualOriginalEngineActivated: Bool
        public let nativeDirectionVector: CMOriginalWindowsRocketForce.Vector3?
        public let nativeChildFCScalar: Float?
        public let observedNativeBodyCenter: CMOriginalWindowsRocketForce.Vector3?

        public init(nativeSampleSequence: UInt64,
                    rocketParentID: String, rocketChildID: String,
                    nativeParentState: Float,
                    actualOriginalEngineActivated: Bool,
                    nativeDirectionVector: CMOriginalWindowsRocketForce.Vector3?,
                    nativeChildFCScalar: Float?,
                    observedNativeBodyCenter: CMOriginalWindowsRocketForce.Vector3?) {
            self.nativeSampleSequence = nativeSampleSequence
            self.rocketParentID = rocketParentID
            self.rocketChildID = rocketChildID
            self.nativeParentState = nativeParentState
            self.actualOriginalEngineActivated = actualOriginalEngineActivated
            self.nativeDirectionVector = nativeDirectionVector
            self.nativeChildFCScalar = nativeChildFCScalar
            self.observedNativeBodyCenter = observedNativeBodyCenter
        }
    }

    /// A stale or repeated SwiftUI observation must not accelerate a
    /// rocket a second time. Source MUST advance this sequence for each
    /// true original Engine force measurement, even with identical values.
    public static func fresh(
        _ observed: Observation, afterLastApplied last: UInt64?
    ) -> Bool {
        observed.nativeSampleSequence > 0
            && (last.map { observed.nativeSampleSequence > $0 } ?? true)
    }

    /// Validate real per-scene ownership before asking the recovered
    /// Win32 force evaluator for a continuous, NON-impulsive force.
    /// The body must be the physically dynamic genuine rocket child.
    public static func force(
        observed: Observation,
        realParentID: String,
        realChildID: String,
        actualParentType: String,
        actualChildType: String,
        childPhysicsIsDynamic: Bool
    ) -> CMOriginalWindowsRocketForce.Sample? {
        guard fresh(observed, afterLastApplied: nil),
              !realParentID.isEmpty && !realChildID.isEmpty,
              observed.rocketParentID == realParentID,
              observed.rocketChildID == realChildID,
              actualParentType == "tmo_heat_rocket",
              actualChildType == "tmo_heat_rocket_rocket",
              childPhysicsIsDynamic else { return nil }
        return CMOriginalWindowsRocketForce.observedThrust(
            rocketType: actualParentType,
            parentState: observed.nativeParentState,
            nativeEngineChildActive: observed.actualOriginalEngineActivated,
            originalDirectionVector: observed.nativeDirectionVector,
            observedChildForceScalar: observed.nativeChildFCScalar,
            physicsBodyCenter: observed.observedNativeBodyCenter)
    }
}
