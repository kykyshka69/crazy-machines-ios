import Foundation

/// Native CrazyMachines.exe 0x409650..0x40985B angular/radial ray kernel.
/// Verified against SHA256 51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6.
/// Actual per-emitter field values and beam orientation must be recovered
/// separately. Do not synthesize a lamp ray, solar voltage or GOAL from mere
/// proximity or a clear SceneKit line-of-sight.
public enum CMOriginalWindowsBeamRegion {
    public struct Vector: Equatable {
        public let x: Float
        public let y: Float
        public let z: Float
        public init(x: Float, y: Float, z: Float = 0) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    /// The native ray object fields, not default or guessed iOS constants.
    public struct Parameters {
        public let innerSquaredDistance: Float // original +0x34
        public let outerSquaredDistance: Float // original +0x38
        public let distanceFalloff: Float       // original +0x3C
        public let maximumAngle: Float          // original +0x40
        public let angleFalloff: Float          // original +0x44

        public init(innerSquaredDistance: Float, outerSquaredDistance: Float,
                    distanceFalloff: Float, maximumAngle: Float,
                    angleFalloff: Float) {
            self.innerSquaredDistance = innerSquaredDistance
            self.outerSquaredDistance = outerSquaredDistance
            self.distanceFalloff = distanceFalloff
            self.maximumAngle = maximumAngle
            self.angleFalloff = angleFalloff
        }
    }

    public struct Hit {
        public let weight: Float
        public let direction: Vector
        public let squaredDistance: Float
        public let angle: Float
    }

    /// Win32 projects XYZ into XY at 0x40966D/0x409688. The real x87 tests
    /// include equality at inner, outer and angular bounds: 0x4096DE uses
    /// parity and 0x4096F5/0x409786 use nonzero status; the prior hypothesis
    /// of STRICT comparisons was wrong. Output weight is clamped to 0...1.
    public static func intersect(
        origin: Vector, forward: Vector, target: Vector, p: Parameters
    ) -> Hit? {
        let values = [origin.x, origin.y, forward.x, forward.y,
                      target.x, target.y, p.innerSquaredDistance,
                      p.outerSquaredDistance, p.distanceFalloff,
                      p.maximumAngle, p.angleFalloff]
        guard values.allSatisfy(\.isFinite),
              p.innerSquaredDistance >= 0,
              p.outerSquaredDistance > p.innerSquaredDistance,
              p.distanceFalloff >= 0,
              p.maximumAngle > 0, p.maximumAngle <= .pi,
              p.angleFalloff >= 0 else { return nil }
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let squaredDistance = dx * dx + dy * dy
        guard squaredDistance.isFinite,
              squaredDistance >= p.innerSquaredDistance,
              squaredDistance <= p.outerSquaredDistance else { return nil }
        let length = sqrt(squaredDistance)
        let forwardLength = sqrt(forward.x * forward.x + forward.y * forward.y)
        guard length.isFinite, length > 0,
              forwardLength.isFinite, forwardLength > 0 else { return nil }
        let cosAngle = (dx * forward.x + dy * forward.y)
            / (length * forwardLength)
        guard cosAngle.isFinite else { return nil }
        let angle = acos(min(1, max(-1, cosAngle)))
        guard angle.isFinite, angle <= p.maximumAngle else { return nil }
        let a = angle * p.angleFalloff
        let angularFraction = 1 - a * a
        let radialFraction = 1 -
            (squaredDistance - p.innerSquaredDistance) * p.distanceFalloff
        let weight = angularFraction * radialFraction
        guard weight.isFinite else { return nil }
        return Hit(weight: min(1, max(0, weight)),
                   direction: Vector(x: dx / length, y: dy / length),
                   squaredDistance: squaredDistance, angle: angle)
    }
}
