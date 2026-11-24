import Foundation

/// Win32 0x44F4B7..0x44F4D2: when tmo_windmill has an actual
/// tmo_windmill_wings physics component, compare fabs(component +0xE0)
/// against exact float constant at 0x4E737C = 0.3. A strictly greater
/// value calls native GOAL dispatcher channel zero.
/// +0xE0's precise SceneKit analog and wind force remain provisional.
public enum CMOriginalWindowsWindmill {
    public static let nativeGoalCutoff: Float = 0.30000001192092896
    public static func triggersGoal(nativeWingsSignal: Float) -> Bool {
        nativeWingsSignal.isFinite &&
            abs(nativeWingsSignal) > nativeGoalCutoff
    }

    /// Actual Win32 0x44BB49–0x44BB57: wheel +0xE8 is negated into
    /// wings +0xE0. Reverse direction at 0x451201–0x451215 and
    /// 0x44F657–0x44F66B performs the inverse with the same unit ratio.
    public static func linkedSignal(_ source: Float) -> Float? {
        source.isFinite ? -source : nil
    }

    /// SceneKit adapter: enforce the recovered opposite unit ratio with
    /// bounded passive torques. Native signal-to-physical torque calibration
    /// is not known. Both bodies receive the same signed reaction torque,
    /// so total mechanical power is -gain * slip² (or capped equivalent).
    public static func coupledTorque(wheelSpeed: Float, wingsSpeed: Float) -> Float? {
        guard wheelSpeed.isFinite, wingsSpeed.isFinite,
              abs(wheelSpeed) <= 80, abs(wingsSpeed) <= 80,
              let targetWings = linkedSignal(wheelSpeed) else { return nil }
        let slip = wingsSpeed - targetWings
        guard abs(slip) > 0.005 else { return nil }
        return max(-2, min(2, -slip * 0.5))
    }
}
