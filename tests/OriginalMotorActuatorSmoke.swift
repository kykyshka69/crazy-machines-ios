import Foundation

@main
struct OriginalMotorActuatorSmoke {
    static func main() {
        typealias Motor = CMOriginalMotorActuator
        typealias Win32 = CMOriginalWindowsPowerScalar
        precondition(Win32.motorRotorCommand(from: 10) == -10)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: -10) == -3)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: 10) == 3)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: -50) == -3)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: 50) == 3)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: 0) == 0)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: .nan) == nil)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: .infinity) == nil)

        // Verified Win32 GOAL cutoff does not gate physical rotor command.
        let lowPower: Float = 0.25
        precondition(Win32.motorTriggersGoal(power: lowPower) == false)
        let lowRotorCommand = Win32.motorRotorCommand(from: lowPower)!
        precondition(lowRotorCommand == -0.25)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: lowRotorCommand)! < 0)
        precondition(Motor.prototypeTargetSpeed(rotorCommand: lowRotorCommand)! > -0.1)
        // Motor command can change polarity while rotating.
        precondition(Motor.prototypeStep(signedAngularSpeed: -3,
                                        targetSpeed: 3, elapsedSeconds: 1.0/3.0) == nil)
        let turning = Motor.prototypeStep(signedAngularSpeed: -3,
                                         targetSpeed: 3, elapsedSeconds: 0.2)!
        precondition(turning > -3 && turning < 0)
        // Loss of power decelerates the prior driven rotor in multiple frames.
        let slowing = Motor.prototypeStep(signedAngularSpeed: -3,
                                         targetSpeed: 0, elapsedSeconds: 0.1)!
        precondition(abs(slowing + 2.1) < 0.0001)
        let resting = Motor.prototypeStep(signedAngularSpeed: -0.1,
                                         targetSpeed: 0, elapsedSeconds: 0.1)!
        precondition(resting == 0)
        precondition(Motor.prototypeStep(signedAngularSpeed: .nan,
                                        targetSpeed: 0, elapsedSeconds: 0.1) == nil)
        precondition(Motor.prototypeStep(signedAngularSpeed: 0,
                                        targetSpeed: 0, elapsedSeconds: 0) == nil)
        precondition(Motor.prototypeStep(signedAngularSpeed: 0,
                                        targetSpeed: 0, elapsedSeconds: .infinity) == nil)
        print("Win32 motor command and GOAL cutoff are separate; iOS rotor start, reversal, and power-loss coastdown are bounded")
    }
}
