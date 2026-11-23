import Foundation

@main struct OriginalWindowsDynamicCandleTiltSmoke {
    static func main() {
        typealias T = CMOriginalWindowsDynamicCandleTilt
        precondition(T.nativeDownwardThreshold.bitPattern == 0xBF4CCCCD)
        precondition(T.shouldExtinguish(observedDirectionX: 0,
            observedDirectionY: -1, observedDirectionZ: 0) == true)
        precondition(T.shouldExtinguish(observedDirectionX: 0,
            observedDirectionY: 1, observedDirectionZ: 0) == false)
        precondition(T.shouldExtinguish(observedDirectionX: 1,
            observedDirectionY: -1, observedDirectionZ: 0) == false)
        precondition(T.shouldExtinguish(observedDirectionX: 0.1,
            observedDirectionY: -0.9, observedDirectionZ: 0) == true)
        precondition(T.shouldExtinguish(observedDirectionX: 0,
            observedDirectionY: 0, observedDirectionZ: 0) == nil)
        precondition(T.shouldExtinguish(observedDirectionX: .nan,
            observedDirectionY: -1, observedDirectionZ: 0) == nil)
        precondition(T.shouldExtinguish(observedDirectionX: 0,
            observedDirectionY: -.infinity, observedDirectionZ: 0) == nil)
        print("Original Win32 moving candle inverted-flame cutoff PASS")
    }
}
