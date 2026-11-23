import Foundation

/// The native rocket branch 0x44F1DD..0x44F27D reads the original
/// Direction frame's runtime vector, multiplies it by child +0xFC via
/// 0x404460, and applies the result at the genuine physics body center
/// through 0x426470 -> 0x486400. The bridge uses only planar x/y.
/// This module does not fabricate ignition, thrust observations, or GOAL.
public enum CMOriginalWindowsRocketForce {
    public struct Vector3: Equatable {
        public let x: Float
        public let y: Float
        public let z: Float
        public init(_ x: Float, _ y: Float, _ z: Float = 0) {
            self.x = x; self.y = y; self.z = z
        }
        public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    }

    public struct Sample: Equatable {
        public let force: Vector3
        public let bodyCenter: Vector3
    }

    /// Requires live ORIGINAL parent state=2, activated Engine child,
    /// the runtime +0xFC scalar and native Direction vector. Neither
    /// the authored VELOCITY 4.0 nor VALF 0.125 proves runtime +0xFC.
    public static func observedThrust(
        rocketType: String,
        parentState: Float,
        nativeEngineChildActive: Bool,
        originalDirectionVector: Vector3?,
        observedChildForceScalar: Float?,
        physicsBodyCenter: Vector3?
    ) -> Sample? {
        guard rocketType == "tmo_heat_rocket",
              parentState.isFinite, parentState == 2,
              nativeEngineChildActive,
              let originalDirectionVector, originalDirectionVector.isFinite,
              let observedChildForceScalar, observedChildForceScalar.isFinite,
              let physicsBodyCenter, physicsBodyCenter.isFinite else {
            return nil
        }
        let forceX = originalDirectionVector.x * observedChildForceScalar
        let forceY = originalDirectionVector.y * observedChildForceScalar
        guard forceX.isFinite, forceY.isFinite else { return nil }
        // Original 0x426470 supplies X,Y and literal Z=0 to the 3D body.
        // The native application point is the body center read by 0x4261C0.
        return Sample(force: Vector3(forceX, forceY, 0),
                      bodyCenter: physicsBodyCenter)
    }
}
