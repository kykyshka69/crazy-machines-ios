import Foundation

/// Authentic moving UCM marker frames from the imported rocket child.
/// This measures SceneKit model/world coordinates only, not unrecovered
/// Win32 selector-3 region radii, original +0xFC, ignition or rocket GOAL.
public enum CMOriginalRocketAnchorTelemetry {
    public struct Vector3: Equatable {
        public let x: Float
        public let y: Float
        public let z: Float
        public init(_ x: Float, _ y: Float, _ z: Float) {
            self.x = x; self.y = y; self.z = z
        }
        public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
        public var lengthSquared3D: Double {
            Double(x) * Double(x) + Double(y) * Double(y)
                + Double(z) * Double(z)
        }
    }
    public struct Frame: Equatable {
        public let rocketChildID: String
        public let name: String
        /// Literal original UCM attachment name, not the lowercase
        /// SceneKit node name used to locate the anchor.
        public let originalUCMMarkerName: String
        public let worldOrigin: Vector3
        /// The original marker's world-space local-Y basis, including
        /// its UCM rotation and imported scene transforms. The native
        /// runtime Direction +0x30 vector remains a separate input.
        public let worldYAxis: Vector3
        public init(rocketChildID: String, name: String,
                    originalUCMMarkerName: String,
                    worldOrigin: Vector3, worldYAxis: Vector3) {
            self.rocketChildID = rocketChildID
            self.name = name
            self.originalUCMMarkerName = originalUCMMarkerName
            self.worldOrigin = worldOrigin
            self.worldYAxis = worldYAxis
        }
    }
    public struct Complete: Equatable {
        public let rocketChildID: String
        /// Live SceneKit dynamic rigid body's center in WORLD space.
        /// Not an invented native Win32 COM or +0xFC engine signal.
        public let worldDynamicBodyCenter: Vector3?
        public let heat: Frame
        public let engine: Frame
        public let explode: Frame
        public let direction: Frame
    }
    /// Reject missing/duplicated, nonfinite or wrong-owner records.
    /// World-space rocket marker Y may point purely along Z in the
    /// owner's original UCM; do NOT reject it using XY-only length.
    public static func complete(
        rocketChildID: String, originalParentType: String,
        frames: [Frame], observedDynamicBodyCenter: Vector3? = nil
    ) -> Complete? {
        guard !rocketChildID.isEmpty,
              originalParentType == "tmo_heat_rocket",
              frames.count <= 64,
              observedDynamicBodyCenter?.isFinite ?? true else { return nil }
        let required: Set<String> = ["Heat", "Engine", "Explode", "Direction"]
        var seen: [String: Frame] = [:]
        for frame in frames where required.contains(frame.name) {
            guard frame.rocketChildID == rocketChildID,
                  // A synthesized SceneKit name cannot authenticate
                  // a native UCM attachment's original spelling.
                  frame.originalUCMMarkerName == frame.name,
                  frame.worldOrigin.isFinite,
                  frame.worldYAxis.isFinite,
                  frame.worldYAxis.lengthSquared3D > 0,
                  seen.updateValue(frame, forKey: frame.name) == nil
            else { return nil }
        }
        guard let heat = seen["Heat"], let engine = seen["Engine"],
              let explode = seen["Explode"],
              let direction = seen["Direction"] else { return nil }
        return Complete(rocketChildID: rocketChildID,
                        worldDynamicBodyCenter: observedDynamicBodyCenter,
                        heat: heat,
                        engine: engine, explode: explode,
                        direction: direction)
    }
}
