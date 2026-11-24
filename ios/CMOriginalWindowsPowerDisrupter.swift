import Foundation

/// Read-only x86 reconstruction of the original power_disrupter wheel gate.
///
/// Win32 0x44CA59 loads the wheel's +0xD0 angle and passes it with the exact
/// float Pi (0x40490FDB) to the fmodf CRT wrapper at 0x403160/0x403180.
/// 0x44CA73..0x44CAC8 then conditionally clears the electrical state +0x40.
/// This models THAT predicate, not the original gear torque or its wiring.
public enum CMOriginalWindowsPowerDisrupter {
    /// Distinguish a measured open contact from missing wheel data. Both
    /// block power, but only a measured phase can enter order consensus.
    public enum Observation: Equatable {
        case unavailable
        case blocked
        case conducting
    }

    public static func observation(rotorAngle: Float) -> Observation {
        guard rotorAngle.isFinite else { return .unavailable }
        return conducts(rotorAngle: rotorAngle) ? .conducting : .blocked
    }

    public static let period = Float(bitPattern: 0x40490FDB)
    public static let halfTurnGate = Float(bitPattern: 0x3FC90FDB)

    /// Returns the original +0x40 transmission gate for a finite rotor angle.
    /// The original fmod phase is signed: positive and negative wheel motion
    /// have different conducting intervals. Unknown/NaN angle fails closed.
    public static func conducts(rotorAngle: Float) -> Bool {
        guard rotorAngle.isFinite else { return false }
        let phase = rotorAngle.truncatingRemainder(dividingBy: period)
        guard phase.isFinite else { return false }
        if phase < 0 {
            // Win32 0x44CA83..0x44CAAD: -Pi < phase < -Pi/2.
            return phase < -halfTurnGate
        }
        // Win32 0x44CAAF..0x44CAC8: 0 <= phase < Pi/2.
        return phase < halfTurnGate
    }
}