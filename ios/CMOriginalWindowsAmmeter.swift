import Foundation

/// Native Win32 tmo_power_amperemeter (0x450F2E..0x45105A):
/// special element +0xFE/+0x40 versus electrical +0x40, max, cap at 10,
/// GOAL only if >1, and target needle angle pi/4-(pi/2)*(power/10).
/// Source inputs must be observed, never inferred from CML proximity.
public enum CMOriginalWindowsAmmeter {
    public static let maximumPower: Float = 10
    public static let zeroNeedleAngle: Float = 0.7853981852531433
    public static let fullNeedleSweep: Float = 1.5707963705062866
    public static let nativeGoalCutoff: Float = 1

    public static func displayedPower(incomingPower: Float, sensorInput: Float) -> Float? {
        guard incomingPower.isFinite, sensorInput.isFinite else { return nil }
        return min(max(incomingPower, sensorInput), maximumPower)
    }

    public static func triggersGoal(incomingPower: Float, sensorInput: Float) -> Bool {
        guard let value = displayedPower(
            incomingPower: incomingPower, sensorInput: sensorInput) else {
            return false
        }
        return value > nativeGoalCutoff
    }

    public static func needleAngle(incomingPower: Float, sensorInput: Float) -> Float? {
        guard let value = displayedPower(
            incomingPower: incomingPower, sensorInput: sensorInput) else {
            return nil
        }
        let angle = zeroNeedleAngle - fullNeedleSweep * value / maximumPower
        return angle.isFinite ? angle : nil
    }
}
