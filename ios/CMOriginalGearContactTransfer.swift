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
        firstMass: Float, secondMass: Float,
        nativeFirstVALF: Float? = nil,
        nativeSecondVALF: Float? = nil
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

        // The actual Win32 VALF/+0xEC transmission ratio is recovered,
        // but mapping native +0xE8 to SCN angular speed is NOT. Use native
        // per-object VALF as the experimental speed-ratio constraint only
        // when BOTH original coefficients exist. Keep contact-point radii
        // to turn bounded corrective slip into physical SceneKit torque.
        // Without original coefficients, fall back to no-slip geometry.
        // In the 102 owner-verified scenes both gear-contact components
        // carry original VALF. If a damaged/new import has only ONE,
        // do not silently replace the known native ratio with a guessed
        // radius-based connection. Preserve legacy all-nil diagnostic
        // fixtures but reject mixed real/unknown evidence.
        guard (nativeFirstVALF == nil) == (nativeSecondVALF == nil)
        else { return nil }
        let slip: Float
        if let firstVALF = nativeFirstVALF,
           let secondVALF = nativeSecondVALF {
            guard let nativeRatio =
                CMOriginalWindowsMechanicalTransfer.transmittedSignal(
                    sourceSignal: 1, sourceVALF: firstVALF,
                    targetVALF: secondVALF),
                  nativeRatio > 0, nativeRatio <= 100 else { return nil }
            let equivalentRadius = (firstRadius / nativeRatio
                                    + secondRadius) * 0.5
            slip = (firstAngularSpeed * nativeRatio
                    + secondAngularSpeed) * equivalentRadius
        } else {
            slip = firstAngularSpeed * firstRadius
                + secondAngularSpeed * secondRadius
        }
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
