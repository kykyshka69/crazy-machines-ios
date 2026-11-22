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