import Foundation

@main
struct OriginalWindowsFlowerSmoke {
    static func main() {
        typealias F = CMOriginalWindowsFlower
        func close(_ actual: Float?, _ expected: Float) -> Bool {
            guard let actual else { return false }
            return abs(actual - expected) < 0.00001
        }
        precondition(!F.triggersGoal(observedNativeProgress: 0.501))
        precondition(F.triggersGoal(observedNativeProgress: 0.5))
        precondition(F.triggersGoal(observedNativeProgress: -0.1))
        precondition(!F.triggersGoal(observedNativeProgress: .nan))
        precondition(close(F.nextProgress(previous: 1, observedLightInput: 1,
                                         observedNativeDelta: 1), 0.5))
        precondition(close(F.nextProgress(previous: 0.5, observedLightInput: 1,
                                         observedNativeDelta: 1), 0.25))
        precondition(close(F.nextProgress(previous: 0, observedLightInput: 0,
                                         observedNativeDelta: 1), 0.5))
        precondition(close(F.nextProgress(previous: 0.5, observedLightInput: 0,
                                         observedNativeDelta: 1), 0.75))
        precondition(close(F.nextProgress(previous: -100, observedLightInput: 0,
                                         observedNativeDelta: 1), -99.5))
        precondition(close(F.nextProgress(previous: 0, observedLightInput: 2,
                                         observedNativeDelta: 1), 0))
        precondition(close(F.nextProgress(previous: 1, observedLightInput: 1,
                                         observedNativeDelta: 0), 1))
        precondition(F.nextProgress(previous: 1, observedLightInput: .nan,
                                   observedNativeDelta: 1) == nil)
        precondition(F.nextProgress(previous: 1, observedLightInput: 1,
                                   observedNativeDelta: -1) == nil)
        print("Original Win32 flower light/progress +0x130 and GOAL cutoff: OK")
    }
}
