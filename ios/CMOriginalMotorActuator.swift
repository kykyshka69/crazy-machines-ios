import Foundation

/// SceneKit adapter for the original motor rotor +0xE8 command.
/// The command and GOAL cutoff are disassembled Win32 facts, but this
/// bounded speed/acceleration curve is explicitly an iOS prototype.
/// In particular, GOAL's abs(command)>0.5 is NOT a motor start threshold.
public enum CMOriginalMotorActuator {
    public static let prototypeFullScaleCommand: Float = 10
    public static let prototypeMaximumAngularSpeed: Float = 3
    public static let prototypeMaximumAngularAcceleration: Float = 9

    /// A finite, signed command is always converted to motion, even when
    /// its magnitude is smaller than the original GOAL callback threshold.
    /// The 3/10 conversion is not a Windows torque or RPM constant.
    public static func prototypeTargetSpeed(rotorCommand: Float) -> Float? {
        guard rotorCommand.isFinite else { return nil }
        let unbounded = Double(rotorCommand)
            / Double(prototypeFullScaleCommand)
            * Double(prototypeMaximumAngularSpeed)
        let limit = Double(prototypeMaximumAngularSpeed)
        return Float(max(-limit, min(limit, unbounded)))
    }

    /// When the motor loses its source, the caller supplies targetSpeed=0.
    /// A previously driven rotor coasts down instead of retaining a stale
    /// motor command or stopping by teleporting the mesh rotation.
    public static func prototypeStep(
        signedAngularSpeed: Float, targetSpeed: Float,
        elapsedSeconds: Double
    ) -> Float? {
        guard signedAngularSpeed.isFinite, targetSpeed.isFinite,
              elapsedSeconds.isFinite, elapsedSeconds > 0,
              elapsedSeconds <= 0.25 else { return nil }
        // A caller can bypass prototypeTargetSpeed; keep the integration
        // bounded even for an unexpectedly large (but finite) command.
        // Treat prior speed as measured state, then move it toward a capped
        // target without allowing a single step to overshoot that target.
        let speedLimit = Double(prototypeMaximumAngularSpeed)
        let boundedTarget = max(-speedLimit, min(speedLimit, Double(targetSpeed)))
        let maximumChange = Double(prototypeMaximumAngularAcceleration)
            * elapsedSeconds
        let change = boundedTarget - Double(signedAngularSpeed)
        let boundedChange = max(-maximumChange, min(maximumChange, change))
        let next = Double(signedAngularSpeed) + boundedChange
        guard next.isFinite, abs(next) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(next)
    }
}
