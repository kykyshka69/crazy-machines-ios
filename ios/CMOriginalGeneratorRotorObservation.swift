import Foundation

/// Renderer reporting for an authentic original tmo_power_generator_rotor.
/// Native output remains abs(+0xE8). These are ONLY conservative SceneKit
/// reporting tolerances, not recovered Windows drivetrain constants.
public enum CMOriginalGeneratorRotorObservation {
    public static let prototypeRestEpsilon: Float = 0.01
    public static let prototypePollDelta: Float = 0.05

    /// Nil means 'no change'. Non-nil zero is a required stop transition.
    /// Otherwise a cached 0.03 speed could electrically power a device
    /// forever once the measured wheel stopped, since 0.03 < poll delta.
    public static func report(previous: Float?, measured: Float) -> Float? {
        guard measured.isFinite, previous?.isFinite != false else { return nil }
        let speed: Float = abs(measured) <= prototypeRestEpsilon ? 0 : measured
        if let previous {
            if speed == 0 && previous != 0 { return 0 }
            if speed == 0 && previous == 0 { return nil }
            // Native power is abs(rotor +0xE8), not a binary
            // 0.05-threshold switch. The ordinary display debounce must
            // never suppress a first nonzero observed rotor movement or
            // a real reversal of direction at low speed.
            if previous == 0 && speed != 0 { return speed }
            if previous.sign != speed.sign { return speed }
            if abs(previous - speed) < prototypePollDelta { return nil }
        } else if speed == 0 {
            // No source exists yet: avoid inventing a start event at zero.
            return nil
        }
        return speed
    }
}
