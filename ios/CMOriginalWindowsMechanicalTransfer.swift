import Foundation

/// Verified native CrazyMachines.exe mechanical scalar arithmetic.
/// The original encrypted CML VALF parser at 0x4226DE..0x422730 writes
/// the Float into object +0xEC. A linked receiver at 0x44BAB2..0x44BAD0
/// receives: target.+0xE8 = source.+0xE8 * source.+0xEC / target.+0xEC.
/// Original gear link walker 0x44B955..0x44B963 separately negates the
/// receiving +0xE8. This code computes the native scalar only: it does
/// NOT prove any angular velocity or physical torque in SceneKit.
public enum CMOriginalWindowsMechanicalTransfer {
    public static func transmittedSignal(
        sourceSignal: Float, sourceVALF: Float, targetVALF: Float,
        reversesDirection: Bool = false
    ) -> Float? {
        guard sourceSignal.isFinite, sourceVALF.isFinite,
              targetVALF.isFinite, sourceVALF > 0,
              targetVALF > 0 else { return nil }
        let input = reversesDirection ? -Double(sourceSignal)
                                      : Double(sourceSignal)
        let output = input * Double(sourceVALF) / Double(targetVALF)
        guard output.isFinite,
              abs(output) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(output)
    }

    /// Native 0x44BAD8..0x44BB0B: target += (0-target) * native timestep
    /// when an original runtime link flag +0x50 is nonzero. Neither the
    /// runtime flag nor the true +0x128 step is stored in CML; supply
    /// observed values only, never manufacture an activation or GOAL.
    public static func decayedSignal(
        previous: Float, observedNativeStep: Double
    ) -> Float? {
        guard previous.isFinite, observedNativeStep.isFinite,
              observedNativeStep >= 0, observedNativeStep <= 1 else {
            return nil
        }
        let result = Double(previous) * (1 - observedNativeStep)
        guard result.isFinite,
              abs(result) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(result)
    }
}
