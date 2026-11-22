import Foundation

@main
struct OriginalWindowsWindmillSmoke {
    static func main() {
        typealias W = CMOriginalWindowsWindmill
        precondition(!W.triggersGoal(nativeWheelSignal: 0))
        precondition(!W.triggersGoal(nativeWheelSignal: 0.3))
        precondition(!W.triggersGoal(nativeWheelSignal: -0.3))
        precondition(W.triggersGoal(nativeWheelSignal: 0.3001))
        precondition(W.triggersGoal(nativeWheelSignal: -0.3001))
        precondition(!W.triggersGoal(nativeWheelSignal: .nan))
        precondition(!W.triggersGoal(nativeWheelSignal: .infinity))
        precondition(!W.triggersGoal(nativeWheelSignal: -.infinity))
        print("Native Windows windmill wheel +0xE0 abs >0.3 GOAL threshold passed")
    }
}
