import Foundation

/// A SINGLE real-native rocket Engine force sample for one SceneKit physics
/// update. Its fields are observations, not the original CML template's
/// VALF/VELOCITY defaults. An unevidenced Engine cannot move the rocket.
public enum CMOriginalRocketForceDelivery {
    public struct Observation {
        public let rocketParentID: String
        public let rocketChildID: String
        public let nativeParentState: Float
        public let actualOriginalEngineActivated: Bool
        public let nativeDirectionVector: CMOriginalWindowsRocketForce.Vector3?
        public let nativeChildFCScalar: Float?
        public let observedNativeBodyCenter: CMOriginalWindowsRocketForce.Vector3?

        public init(rocketParentID: String, rocketChildID: String,
                    nativeParentState: Float,
                    actualOriginalEngineActivated: Bool,
                    nativeDirectionVector: CMOriginalWindowsRocketForce.Vector3?,
                    nativeChildFCScalar: Float?,
                    observedNativeBodyCenter: CMOriginalWindowsRocketForce.Vector3?) {
            self.rocketParentID = rocketParentID
            self.rocketChildID = rocketChildID
            self.nativeParentState = nativeParentState
            self.actualOriginalEngineActivated = actualOriginalEngineActivated
            self.nativeDirectionVector = nativeDirectionVector
            self.nativeChildFCScalar = nativeChildFCScalar
            self.observedNativeBodyCenter = observedNativeBodyCenter
        }
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
        guard !realParentID.isEmpty && !realChildID.isEmpty,
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
