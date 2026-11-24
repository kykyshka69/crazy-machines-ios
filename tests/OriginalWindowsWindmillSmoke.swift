import Foundation

@main
struct OriginalWindowsWindmillSmoke {
    static func main() {
        typealias W = CMOriginalWindowsWindmill
        precondition(!W.triggersGoal(nativeWingsSignal: 0))
        precondition(!W.triggersGoal(nativeWingsSignal: 0.3))
        precondition(!W.triggersGoal(nativeWingsSignal: -0.3))
        precondition(W.triggersGoal(nativeWingsSignal: 0.3001))
        precondition(W.triggersGoal(nativeWingsSignal: -0.3001))
        precondition(!W.triggersGoal(nativeWingsSignal: .nan))
        precondition(!W.triggersGoal(nativeWingsSignal: .infinity))
        precondition(!W.triggersGoal(nativeWingsSignal: -.infinity))
        precondition(W.linkedSignal(2) == -2)
        precondition(W.linkedSignal(-2) == 2)
        precondition(W.linkedSignal(.nan) == nil)
        precondition(W.coupledTorque(wheelSpeed: 0, wingsSpeed: 0) == nil)
        precondition(W.coupledTorque(wheelSpeed: 2, wingsSpeed: -2) == nil)
        precondition(W.coupledTorque(wheelSpeed: 2, wingsSpeed: 0) == -1)
        precondition(W.coupledTorque(wheelSpeed: 0, wingsSpeed: -2) == 1)
        precondition(W.coupledTorque(wheelSpeed: .infinity, wingsSpeed: 0) == nil)
        for a in -80...80 {
            for b in -80...80 {
                let w = Float(a), v = Float(b)
                if let torque = W.coupledTorque(wheelSpeed: w, wingsSpeed: v) {
                    precondition(abs(torque) <= 2)
                    precondition(torque * (w + v) <= 0)
                }
            }
        }
        print("Native windmill GOAL threshold and 25921 passive speed pairs passed")
    }
}
