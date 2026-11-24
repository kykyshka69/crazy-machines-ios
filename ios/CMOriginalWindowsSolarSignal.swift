import Foundation

/// Exact scalar stages recovered from the user's CrazyMachines.exe solar path.
///
/// Input geometry/ray intersections belong to the original Win32 light solver
/// and are NOT reconstructed here. Callers must supply observed ray evidence;
/// no sunlight or electrical output is generated from a solar model's presence.
public enum CMOriginalWindowsSolarSignal {
    // Original x86: 0x44FD7D divides the emitting lamp's +0x40 by 10;
    // 0x44FD92 multiplies actual ray intersection weight;
    // 0x44FD92/0x44FD98 divide by path length times 5.0.
    public static let referencePower: Float = 10.0
    public static let distanceDivisor: Float = 5.0
    // 0x44FF35..0x44FF52 clamps the accumulated light fraction to 1.0.
    public static let maximumLightFraction: Float = 1.0
    // 0x45005F..0x450092 stores the clamped fraction times 10.0 at +0x40.
    public static let solarGoalCutoff: Float = 1.0

    /// One optical ray contribution only AFTER an independent hit test in
    /// the original geometry. The user's EXE has two symmetric hit branches;
    /// both perform this scalar operation. A missing ray is not a hit.
    public static func rayContribution(
        emitterPower: Float,
        interceptedFraction: Float,
        pathLength: Float
    ) -> Float? {
        guard emitterPower.isFinite, emitterPower >= 0,
              interceptedFraction.isFinite,
              interceptedFraction >= 0, interceptedFraction <= 1,
              pathLength.isFinite, pathLength > 0 else { return nil }
        let distance = pathLength * distanceDivisor
        guard distance.isFinite, distance > 0 else { return nil }
        let sample = (emitterPower / referencePower)
            * interceptedFraction / distance
        guard sample.isFinite, sample >= 0 else { return nil }
        return sample
    }

    /// Unconnected solar-cell level data is NOT enough to provide any power.
    /// Each fraction must originate from ray-intersection evidence. No
    /// fabricated default sunlight, nearby-lamp energy, or VALF voltage.
    public static func collectedPower(rayContributions: [Float]) -> Float? {
        var fraction: Float = 0
        for contribution in rayContributions {
            guard contribution.isFinite, contribution >= 0 else { return nil }
            // Clamping at the accumulator saturation is equivalent to the
            // final x86 upper clamp for nonnegative physical observations.
            fraction = min(maximumLightFraction, fraction + contribution)
        }
        let output = fraction * referencePower
        return output.isFinite ? output : nil
    }

    /// Used at Win32 0x450095..0x4500B9 by tmo_power_solarcell before
    /// calling the original goal dispatcher at 0x44B460.
    public static func triggersGoal(solarPower: Float) -> Bool {
        solarPower.isFinite && solarPower > solarGoalCutoff
    }
}

/// Optical adapters using authentic Light UCM marker coordinates.
/// Original direct lamp branch 0x44FE00..0x44FE23 uses power/10/(distance*5).
/// Pocketlamp branch 0x44FE4D..0x44FF2E requires +0xEC != 0 and adds
/// the cone fraction directly. It is not a 10-unit electrical lamp.
public enum CMOriginalLiveOptics {
    public static func lampContribution(power: Float, pathLength: Float,
                                        unobstructed: Bool) -> Float? {
        guard power.isFinite, power >= 0, pathLength.isFinite, pathLength > 0 else { return nil }
        guard unobstructed else { return 0 }
        return CMOriginalWindowsSolarSignal.rayContribution(
            emitterPower: power, interceptedFraction: 1, pathLength: pathLength)
    }

    /// Native pocketlamp cone constructor 0x45422A..0x454259:
    /// angle 30 degrees, near scale .3, outer extension 1.5.
    /// Like the candle constructor, 0x409860 uses literal 90 in tan.
    public static func pocketContribution(lit: Bool, axis: SIMD3<Float>,
                                          displacement: SIMD3<Float>,
                                          unobstructed: Bool) -> Float? {
        guard [axis.x, axis.y, displacement.x, displacement.y].allSatisfy(\.isFinite)
        else { return nil }
        guard lit, unobstructed else { return 0 }
        let radians: Float = 30 * 0.01745329238474369
        let inner = abs(tan(Float(90) + radians) * 0.3)
        let outer = inner + 1.5
        let minSq = inner * inner, maxSq = outer * outer
        return CMOriginalWindowsWindRegion.measuredFraction(
            nativeDisplacement: .init(displacement.x, displacement.y, 0),
            region: .init(nativeAxis: .init(axis.x, axis.y, 0),
                minRadiusSquared: minSq, maxRadiusSquared: maxSq,
                radialFalloff: 1 / (maxSq - minSq), maximumAngle: radians,
                angularFalloff: 1 / radians))
    }
}


/// Native magnifier 0x44FD13..0x44FDF8, 0x44FED4..0x44FF1C,
/// 0x45011F..0x4503BC: two separate clamped light accumulators.
/// The receiver cones have the same 30-degree/.3/1.5 shape as the
/// pocketlamp (0x454316..0x45442E). Heat is emitted for >=0.5 light
/// at each opposite focus; never relay a magnifier as a solar lamp.
public enum CMOriginalMagnifier {
    public enum Side: Int { case negative = -1, positive = 1 }

    public static func incomingSide(axis: SIMD3<Float>, sourceOffset: SIMD3<Float>) -> Side? {
        guard [axis.x, axis.y, sourceOffset.x, sourceOffset.y].allSatisfy(\.isFinite) else { return nil }
        let d = axis.x * sourceOffset.x + axis.y * sourceOffset.y
        guard d.isFinite, d != 0 else { return nil }
        return d > 0 ? .positive : .negative
    }

    public static func acceptsLamp(axis: SIMD3<Float>, sourceOffset: SIMD3<Float>,
                                   power: Float, pathLength: Float,
                                   unobstructed: Bool) -> Float? {
        guard let side = incomingSide(axis: axis, sourceOffset: sourceOffset),
              let weight = CMOriginalLiveOptics.pocketContribution(lit: true,
                  axis: axis * Float(side.rawValue), displacement: sourceOffset,
                  unobstructed: unobstructed) else { return nil }
        return CMOriginalWindowsSolarSignal.rayContribution(
            emitterPower: power, interceptedFraction: weight, pathLength: pathLength)
    }

    public static func clampedLight(_ rays: [Float]) -> Float? {
        CMOriginalWindowsSolarSignal.collectedPower(rayContributions: rays).map { $0 / 10 }
    }

    /// Native 0x450256/0x450392: inclusive 0.5 input cutoff.
    /// Native focus positions depend on the effect component transform.
    /// The adapter uses the authentic authored +/-0.3 glow positions,
    /// supplied as actual world coordinates by the scene.
    public static func heats(light: Float, focus: SIMD3<Float>,
                             receiver: SIMD3<Float>, radius: Float = 0.05) -> Bool {
        guard light.isFinite, light >= 0.5, light <= 1,
              radius.isFinite, radius > 0,
              [focus.x, focus.y, receiver.x, receiver.y].allSatisfy(\.isFinite) else { return false }
        let d = receiver - focus
        // Native 0x44CEA0/0x44CEBE zero Z; 0x44CF59 strictly <.05.
        return d.x*d.x + d.y*d.y < radius*radius
    }
}
