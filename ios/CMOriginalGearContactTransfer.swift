import Foundation

/// Experimental *physical-contact* correction between imported original
/// circular mechanisms. Runs only after SceneKit reports a REAL UCM-body
/// contact; never invent a selector-5 link from distance, matching type, or
/// CONNECTED_TO objective metadata.
///
/// Native 0x44B955 inverts the attached gear's +0xE8 signal. Here we use the
/// external-rolling no-slip constraint (omegaA*rA + omegaB*rB ~= 0) and the
/// actual contact point's radial lever arms. The damping gain is NOT a native
/// Windows torque constant. It is an opt-in SceneKit bridge for actual motion.
public enum CMOriginalGearContactTransfer {
    public struct TorquePair {
        public let first: Float
        public let second: Float
    }

    public static func accepts(_ a: String, _ b: String) -> Bool {
        let circular: Set<String> = [
            "tmo_belt_gear",
            "tmo_power_motor_rotor",
            "tmo_power_generator_rotor",
            "tmo_belt_conveyer_wheel"
        ]
        // Any motor/generator/conveyor involvement must touch an actual
        // original gear UCM; two unrelated powered axles are not connected.
        return (a == "tmo_belt_gear" || b == "tmo_belt_gear")
            && circular.contains(a) && circular.contains(b)
    }

    public static func correction(
        firstKind: String, secondKind: String,
        firstRadius: Float, secondRadius: Float,
        firstAngularSpeed: Float, secondAngularSpeed: Float,
        firstMass: Float, secondMass: Float
    ) -> TorquePair? {
        guard accepts(firstKind, secondKind) else { return nil }
        let values = [firstRadius, secondRadius, firstAngularSpeed,
                      secondAngularSpeed, firstMass, secondMass]
        guard values.allSatisfy(\.isFinite),
              firstRadius >= 0.008, firstRadius <= 3,
              secondRadius >= 0.008, secondRadius <= 3,
              firstMass > 0, secondMass > 0,
              firstMass <= 1000, secondMass <= 1000,
              abs(firstAngularSpeed) <= 80,
              abs(secondAngularSpeed) <= 80 else { return nil }

        // A REAL physics contact exists when called from SceneKit.
        // Surface velocities at the external tangency must cancel.
        let slip = firstAngularSpeed * firstRadius
            + secondAngularSpeed * secondRadius
        guard slip.isFinite, abs(slip) > 0.005 else { return nil }

        // Damped opposing contact forces act with opposite linear sign,
        // but both produce the same signed axle torque (rA and rB point
        // in opposite directions at the contact). The driven rotor must
        // supply energy; this never turns a stationary pair spontaneously.
        // The 6.0 gain and 16.0 cap are bounded SceneKit-only constants.
        let reducedMass = (firstMass * secondMass)
            / (firstMass + secondMass)
        guard reducedMass.isFinite else { return nil }
        let force = max(-16, min(16, -slip * 6 * reducedMass))
        let tA = force * firstRadius
        let tB = force * secondRadius
        guard tA.isFinite, tB.isFinite else { return nil }
        return TorquePair(first: tA, second: tB)
    }
}
