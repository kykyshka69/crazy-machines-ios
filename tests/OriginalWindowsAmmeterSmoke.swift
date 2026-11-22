import Foundation

@main
struct OriginalWindowsAmmeterSmoke {
    static func main() {
        typealias M = CMOriginalWindowsAmmeter
        precondition(M.displayedPower(incomingPower: 2, sensorInput: 5) == 5)
        precondition(M.displayedPower(incomingPower: 12, sensorInput: 4) == 10)
        precondition(M.displayedPower(incomingPower: 0, sensorInput: -4) == 0)
        precondition(M.displayedPower(incomingPower: -2, sensorInput: -3) == -2)
        precondition(M.displayedPower(incomingPower: .nan, sensorInput: 3) == nil)
        precondition(M.displayedPower(incomingPower: 3, sensorInput: .infinity) == nil)
        precondition(M.needleAngle(incomingPower: 0, sensorInput: 0) ==
            M.zeroNeedleAngle)
        precondition(abs(M.needleAngle(incomingPower: 10, sensorInput: 0)! +
            M.zeroNeedleAngle) < 0.000001)
        precondition(abs(M.needleAngle(incomingPower: 5, sensorInput: 0)!) < 0.000001)
        precondition(!M.triggersGoal(incomingPower: 1, sensorInput: 0))
        precondition(M.triggersGoal(incomingPower: 0, sensorInput: 1.001))
        precondition(!M.triggersGoal(incomingPower: .nan, sensorInput: 10))
        print("Verified Win32 ammeter power max, ten cap, pi/4 needle and strict >1 GOAL")
    }
}
