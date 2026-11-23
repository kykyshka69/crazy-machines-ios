import Foundation

/// Exact Win32 0x44FF35..0x450039 from the owner's original PE32.
/// Inputs are OBSERVED native light and clock scalars only: this does
/// not invent optical rays, direction, intercepted fractions, or power.
public enum CMOriginalWindowsFlower {
    public static let nativeGoalCutoff: Float = 0.5
    public static let nativeGrowthRate: Float = 0.5

    /// Original flower progress at +0x130: target 1 - min(light, 1);
    /// per-frame positive increment is capped at +0.5 before the
    /// native frame multiplier +0x128 is applied.
    public static func nextProgress(
        previous: Float,
        observedLightInput: Float,
        observedNativeDelta: Double
    ) -> Float? {
        guard previous.isFinite, observedLightInput.isFinite,
              observedNativeDelta.isFinite,
              observedNativeDelta >= 0 else { return nil }
        let light = min(Double(observedLightInput), 1)
        let target = 1 - light
        let increment = min(
            (target - Double(previous)) * Double(nativeGrowthRate),
            Double(nativeGrowthRate)
        )
        let next = Double(previous) + increment * observedNativeDelta
        guard next.isFinite,
              abs(next) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(next)
    }

    /// Native x87 GOAL branch 0x450018–0x450039 includes equality.
    public static func triggersGoal(observedNativeProgress: Float) -> Bool {
        observedNativeProgress.isFinite
            && observedNativeProgress <= nativeGoalCutoff
    }
}
