import Foundation

/// Measured 3D line-of-sight between *real imported* UCM objects.
///
/// This is optical geometry evidence, not a reconstructed Win32 beam source.
/// The original Windows emission angle, surface-hit fraction and reflection
/// rules are still unknown. In particular, a clear line must NEVER be used
/// as an automatic solar ray, solar voltage or GOAL event.
public struct CMOriginalOpticalSightline: Equatable {
    public let emitterID: String
    public let receiverID: String
    public let pathLength: Float
    public let firstBlockingObjectID: String?

    public var isUnobstructed: Bool { firstBlockingObjectID == nil }
}

public enum CMOriginalOpticalSightlineGeometry {
    public struct Point {
        public let x: Float
        public let y: Float
        public let z: Float

        public init(x: Float, y: Float, z: Float) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    /// Inputs are endpoints taken from authentic UCM meshes in world space.
    /// obstructingObjectIDs must be ordered by actual SceneKit segment hit
    /// distance. Hits belonging to either endpoint's owner are not opaque
    /// *intermediate* objects; all other original 3D objects are blockers.
    /// No proximity thresholds, guessed beam angle or light strength.
    public static func measure(
        emitterID: String, receiverID: String,
        emitter: Point, receiver: Point,
        obstructingObjectIDs: [String]
    ) -> CMOriginalOpticalSightline? {
        guard !emitterID.isEmpty, !receiverID.isEmpty,
              emitterID != receiverID else { return nil }
        let components = [emitter.x, emitter.y, emitter.z,
                          receiver.x, receiver.y, receiver.z]
        guard components.allSatisfy(\.isFinite) else { return nil }
        let dx = Double(receiver.x) - Double(emitter.x)
        let dy = Double(receiver.y) - Double(emitter.y)
        let dz = Double(receiver.z) - Double(emitter.z)
        let distance = sqrt(dx * dx + dy * dy + dz * dz)
        guard distance.isFinite, distance > 0.000001,
              distance <= Double(Float.greatestFiniteMagnitude) else {
            return nil
        }
        let first = obstructingObjectIDs.first {
            !$0.isEmpty && $0 != emitterID && $0 != receiverID
        }
        return CMOriginalOpticalSightline(
            emitterID: emitterID, receiverID: receiverID,
            pathLength: Float(distance), firstBlockingObjectID: first)
    }
}
