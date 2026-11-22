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
        print("Native Windows windmill wings +0xE0 abs >0.3 GOAL threshold passed")
    }
}
