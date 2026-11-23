import Foundation

/// Native 0x409650–0x40985B: measured wind-region coverage using original
/// region parameters, not UCM visual proximity or guessed rotor speed.
/// All coordinates must be observed in one native region reference frame.
public enum CMOriginalWindowsWindRegion {
    public struct Vector3 {
        public let x: Float
        public let y: Float
        public let z: Float
        public init(_ x: Float, _ y: Float, _ z: Float = 0) {
            self.x = x; self.y = y; self.z = z
        }
    }

    public struct Parameters {
        public let nativeAxis: Vector3    // original region +0x18..+0x20
        public let minRadiusSquared: Float // +0x34
        public let maxRadiusSquared: Float // +0x38
        public let radialFalloff: Float    // +0x3C
        public let maximumAngle: Float     // +0x40, radians
        public let angularFalloff: Float   // +0x44

        public init(nativeAxis: Vector3, minRadiusSquared: Float,
                    maxRadiusSquared: Float, radialFalloff: Float,
                    maximumAngle: Float, angularFalloff: Float) {
            self.nativeAxis = nativeAxis
            self.minRadiusSquared = minRadiusSquared
            self.maxRadiusSquared = maxRadiusSquared
            self.radialFalloff = radialFalloff
            self.maximumAngle = maximumAngle
            self.angularFalloff = angularFalloff
        }
    }

    /// Nil = unknown or malformed native region; 0 = measured outside.
    /// Win32 checks squared distance, acos of the direction cosine,
    /// multiplies two quadratic attenuations, and clamps to [0, 1].
    public static func measuredFraction(
        nativeDisplacement: Vector3, region: Parameters
    ) -> Float? {
        let v = nativeDisplacement, a = region.nativeAxis
        let fields = [v.x, v.y, v.z, a.x, a.y, a.z,
                      region.minRadiusSquared, region.maxRadiusSquared,
                      region.radialFalloff, region.maximumAngle,
                      region.angularFalloff]
        guard fields.allSatisfy(\.isFinite),
              region.minRadiusSquared >= 0,
              region.maxRadiusSquared >= region.minRadiusSquared,
              region.maximumAngle >= 0,
              region.maximumAngle <= .pi,
              region.radialFalloff >= 0, region.angularFalloff >= 0
        else { return nil }
        let dx = Double(v.x), dy = Double(v.y), dz = Double(v.z)
        let ax = Double(a.x), ay = Double(a.y), az = Double(a.z)
        let distanceSq = dx * dx + dy * dy + dz * dz
        let axisSq = ax * ax + ay * ay + az * az
        guard distanceSq.isFinite, axisSq.isFinite,
              distanceSq > 0, axisSq > 0 else { return nil }
        if distanceSq < Double(region.minRadiusSquared)
            || distanceSq > Double(region.maxRadiusSquared) { return 0 }
        let cosine = (dx * ax + dy * ay + dz * az)
            / sqrt(distanceSq * axisSq)
        guard cosine.isFinite else { return nil }
        let angle = acos(min(1, max(-1, cosine)))
        if angle > Double(region.maximumAngle) { return 0 }
        let angularScale = angle * Double(region.angularFalloff)
        let angularTerm = 1 - angularScale * angularScale
        let radialTerm = 1 - (distanceSq - Double(region.minRadiusSquared))
            * Double(region.radialFalloff)
        let fraction = angularTerm * radialTerm
        guard fraction.isFinite else { return nil }
        return Float(min(1, max(0, fraction)))
    }
}
