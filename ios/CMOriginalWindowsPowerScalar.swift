import Foundation

/// Evidence-backed scalar operations from the user's original x86 Win32 game.
/// These functions deliberately do NOT solve the electrical network. They
/// operate on the *already-computed* power value at element state +0x40.
/// See docs/windows-original-power-propagation.md for exact PE32 instructions.
public enum CMOriginalWindowsPowerScalar {
    // Win32 0x4504C9: mov dword ptr [eax+0x40], 0x41200000 (float 10).
    public static let batterySource: Float = 10
    // 0x450A53 compares fabs(-power) with a double 0.5, then calls 0x44B460.
    public static let motorGoalCutoff: Float = 0.5
    // 0x44D9C7 compares the lamp's +0x40 with float 3 before channel-0 GOAL.
    public static let lampGoalCutoff: Float = 3
    // 0x450E68 compares the lightning's +0x40 with float 1 before GOAL.
    public static let lightningGoalCutoff: Float = 1
    // 0x44BCC1 stores abs(generator rotor +0xE8) as power at +0x40.
    // 0x44BCCA compares the new power signal with float 1 before GOAL.
    public static let generatorGoalCutoff: Float = 1

    /// Win32 0x44C8F2...0x44C8F8 copies source state +0x40 to target;
    /// 0x44C8E8 sets that source state to zero for a blocking condition.
    /// The caller must determine the blocker from recovered device state.
    public static func transfer(_ source: Float, blocked: Bool) -> Float? {
        guard source.isFinite else { return nil }
        return blocked ? 0 : source
    }

    /// Win32 0x450A2D-0x450A3E: real motor copies -power into rotor +0xE8.
    public static func motorRotorCommand(from power: Float) -> Float? {
        guard power.isFinite else { return nil }
        return -power
    }

    public static func motorTriggersGoal(power: Float) -> Bool {
        guard let command = motorRotorCommand(from: power) else { return false }
        return abs(Double(command)) > Double(motorGoalCutoff)
    }

    public static func lampTriggersGoal(power: Float) -> Bool {
        power.isFinite && power > lampGoalCutoff
    }

    public static func lightningTriggersGoal(power: Float) -> Bool {
        power.isFinite && power > lightningGoalCutoff
    }

    /// Generator is mechanically driven, not a permanent source. Win32
    /// 0x44BCAC-0x44BCC1 copies abs(child rotor command +0xE8) to the
    /// generator's electrical node +0x40. The caller supplies an actual
    /// rotor scalar; SceneKit angular velocity is only a measured proxy.
    public static func generatorSignal(fromRotorCommand rotor: Float) -> Float? {
        guard rotor.isFinite else { return nil }
        return abs(rotor)
    }

    public static func generatorTriggersGoal(rotor: Float) -> Bool {
        guard let output = generatorSignal(fromRotorCommand: rotor) else {
            return false
        }
        return output > generatorGoalCutoff
    }

    /// Win32 0x451E21-0x451E2A: the lamp's visual factor is power / 10.
    /// Original Win32 code does not clamp in this block: keep it raw here.
    public static func lampVisualFactor(power: Float) -> Float? {
        guard power.isFinite else { return nil }
        return power / batterySource
    }
}