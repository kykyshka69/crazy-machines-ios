import Foundation

/// Verified native CrazyMachines.exe mechanical scalar arithmetic.
/// The original encrypted CML VALF parser at 0x4226DE..0x422730 writes
/// the Float into object +0xEC. A linked receiver at 0x44BAB2..0x44BAD0
/// receives: target.+0xE8 = source.+0xE8 * source.+0xEC / target.+0xEC.
/// Original gear link walker 0x44B955..0x44B963 separately negates the
/// receiving +0xE8. This code computes the native scalar only: it does
/// NOT prove any angular velocity or physical torque in SceneKit.
public enum CMOriginalWindowsMechanicalTransfer {
    public static func transmittedSignal(
        sourceSignal: Float, sourceVALF: Float, targetVALF: Float,
        reversesDirection: Bool = false
    ) -> Float? {
        guard sourceSignal.isFinite, sourceVALF.isFinite,
              targetVALF.isFinite, sourceVALF > 0,
              targetVALF > 0 else { return nil }
        let input = reversesDirection ? -Double(sourceSignal)
                                      : Double(sourceSignal)
        let output = input * Double(sourceVALF) / Double(targetVALF)
        guard output.isFinite,
              abs(output) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(output)
    }

    /// Native 0x44BAD8..0x44BB0B: target += (0-target) * native timestep
    /// when an original runtime link flag +0x50 is nonzero. Neither the
    /// runtime flag nor the true +0x128 step is stored in CML; supply
    /// observed values only, never manufacture an activation or GOAL.
    public static func decayedSignal(
        previous: Float, observedNativeStep: Double
    ) -> Float? {
        guard previous.isFinite, observedNativeStep.isFinite,
              observedNativeStep >= 0, observedNativeStep <= 1 else {
            return nil
        }
        let result = Double(previous) * (1 - observedNativeStep)
        guard result.isFinite,
              abs(result) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(result)
    }
}


/// Player-authored rope between exact named attachments in original UCMs.
/// The elastic tension is an iOS reconstruction, not recovered Win32 rope
/// solver constants. CONNECTED_TO objective references never create ropes.
public enum CMOriginalRope {
    public struct Endpoint: Hashable {
        public let objectID: String
        public let marker: String
        public init(objectID: String, marker: String) {
            self.objectID = objectID
            self.marker = marker
        }
    }

    public struct Pair: Hashable {
        public let first: Endpoint
        public let second: Endpoint
        public init?(_ a: Endpoint, _ b: Endpoint) {
            guard a.objectID != b.objectID else { return nil }
            if a.objectID < b.objectID {
                first = a; second = b
            } else {
                first = b; second = a
            }
        }
    }

    /// Names verified in the authentic rope UCMs; case-sensitive.
    public static func accepts(type: String, marker: String) -> Bool {
        switch type {
        case "tmo_rope_hook", "tmo_rope_cage", "tmo_rope_crossbow_lever":
            return marker == "Rope"
        case "tmo_rope_scissors_1", "tmo_rope_scissors_2":
            return marker == "Rope01"
        case "tmo_rope_seesaw_lever":
            return marker == "Rope01" || marker == "Rope02"
        default:
            return false
        }
    }

    /// A rope pulls only while stretched; never pushes, injects tension
    /// at rest, or changes authored length during the simulation.
    public static func tension(distance: Float, restLength: Float) -> Float {
        guard distance.isFinite, restLength.isFinite,
              restLength >= 0.01, restLength <= 30,
              distance > restLength, distance <= 60 else { return 0 }
        return min(25, (distance - restLength) * 35)
    }

    // Win32 rope/fuze-independent cut path 0x456FB0–0x4571D9.
    // 0x457042: rope samples every 0.05; 0x4571BB: blade samples
    // every 0.01; 0x4570F5: strict distance < 0.05. The actual game
    // samples its flexible rope; here the two live UCM endpoints define
    // a straight approximation. No native rope mesh or GOAL is inferred.
    public static func intersectsScissors(
        ropeStart: SIMD3<Float>, ropeEnd: SIMD3<Float>,
        bladeStart: SIMD3<Float>, bladeEnd: SIMD3<Float>
    ) -> Bool {
        guard [ropeStart, ropeEnd, bladeStart, bladeEnd].allSatisfy({
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }) else { return false }
        func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
            a.x*b.x + a.y*b.y + a.z*b.z
        }
        let rope = ropeEnd - ropeStart
        let blade = bladeEnd - bladeStart
        let ropeLength = sqrt(dot(rope, rope))
        let bladeLength = sqrt(dot(blade, blade))
        guard ropeLength.isFinite, bladeLength.isFinite,
              ropeLength > 0, ropeLength <= 60,
              bladeLength > 0, bladeLength <= 4 else { return false }
        let ropeDirection = rope / ropeLength
        let bladeDirection = blade / bladeLength
        let ropeStep = Float(bitPattern: 0x3D4CCCCD)
        let bladeStep = Float(bitPattern: 0x3C23D70A)
        let cutoff = Float(bitPattern: 0x3D4CCCCD)
        // Cheap rejection for distant segments, without inventing
        // a cut based on overlapping bounding boxes alone.
        for axis in 0..<3 {
            if min(ropeStart[axis], ropeEnd[axis]) >
                max(bladeStart[axis], bladeEnd[axis]) + cutoff ||
                min(bladeStart[axis], bladeEnd[axis]) >
                max(ropeStart[axis], ropeEnd[axis]) + cutoff { return false }
        }
        var distance: Float = 0
        while distance < ropeLength {
            let point = ropeStart + ropeDirection * distance
            let projection = dot(point - bladeStart, bladeDirection)
            let index = max(0, min(floor(projection / bladeStep),
                                   ceil(bladeLength / bladeStep) - 1))
            // For a straight blade, its nearest discrete sample is one
            // of these two adjacent indices. Avoid a nested sampling loop.
            for sample in [index, index + 1] {
                let along = sample * bladeStep
                guard along < bladeLength else { continue }
                let difference = point - (bladeStart + bladeDirection * along)
                if sqrt(dot(difference, difference)) < cutoff { return true }
            }
            distance += ropeStep
        }
        return false
    }
}


/// Explicit open-belt link between authentic UCM "Wheel" attachments.
/// Native VALF ratio is recovered; SceneKit torque gain is provisional.
public enum CMOriginalDriveBelt {
    public struct Pair: Hashable {
        public let first: String
        public let second: String
        public init?(_ a: String, _ b: String) {
            guard !a.isEmpty, !b.isEmpty, a != b else { return nil }
            first = min(a, b); second = max(a, b)
        }
    }

    public static func accepts(type: String) -> Bool {
        ["tmo_belt_gear", "tmo_power_motor_rotor", "tmo_power_generator_rotor",
         "tmo_belt_conveyer_wheel", "tmo_power_disrupter_wheel", "tmo_steam_wheel",
         "tmo_windmill_wheel", "tmo_hammer_wheel", "tmo_belt_flag_wheel",
         "tmo_heat_grill_wheel"].contains(type)
    }

    public struct Torque {
        public let first: Float
        public let second: Float
    }

    public static func correction(firstSpeed: Float, secondSpeed: Float,
                                  firstVALF: Float, secondVALF: Float) -> Torque? {
        guard [firstSpeed, secondSpeed, firstVALF, secondVALF].allSatisfy(\.isFinite),
              abs(firstSpeed) <= 80, abs(secondSpeed) <= 80,
              firstVALF >= 0.008, firstVALF <= 3,
              secondVALF >= 0.008, secondVALF <= 3 else { return nil }
        // Same-direction open belt constraint: w1*r1 = w2*r2.
        // Opposing reaction torques dissipate slip rather than generating
        // mechanical energy or spinning two stationary wheels.
        let slip = firstSpeed * firstVALF - secondSpeed * secondVALF
        guard abs(slip) > 0.005 else { return nil }
        let force = max(-8, min(8, slip * 6))
        return Torque(first: -force * firstVALF, second: force * secondVALF)
    }

    /// Unit normal for the two external tangent spans in the puzzle XY plane.
    /// Reject coincident/intersecting or out-of-plane pulley configurations.
    public static func tangentNormals(dx: Float, dy: Float, dz: Float,
                                      firstRadius: Float, secondRadius: Float)
        -> (SIMD2<Float>, SIMD2<Float>)? {
        guard [dx, dy, dz, firstRadius, secondRadius].allSatisfy(\.isFinite),
              abs(dz) <= 0.05, firstRadius > 0, secondRadius > 0,
              firstRadius <= 3, secondRadius <= 3 else { return nil }
        let distance = hypot(dx, dy)
        guard distance.isFinite, distance > firstRadius + secondRadius,
              distance <= 30 else { return nil }
        let unit = SIMD2<Float>(dx, dy) / distance
        let side = SIMD2<Float>(-unit.y, unit.x)
        let cosine = (firstRadius - secondRadius) / distance
        let sine = sqrt(max(0, 1 - cosine * cosine))
        return (unit * cosine + side * sine, unit * cosine - side * sine)
    }
}
