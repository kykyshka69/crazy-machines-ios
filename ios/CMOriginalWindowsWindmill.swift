import Foundation

/// Win32 0x44F4B7..0x44F4D2: when tmo_windmill has an actual
/// tmo_windmill_wheel physics component, compare fabs(component +0xE0)
/// against exact float constant at 0x4E737C = 0.3. A strictly greater
/// value calls native GOAL dispatcher channel zero.
/// +0xE0's precise SceneKit analog and wind force remain provisional.
public enum CMOriginalWindowsWindmill {
    public static let nativeGoalCutoff: Float = 0.30000001192092896
    public static func triggersGoal(nativeWheelSignal: Float) -> Bool {
        nativeWheelSignal.isFinite &&
            abs(nativeWheelSignal) > nativeGoalCutoff
    }
}
