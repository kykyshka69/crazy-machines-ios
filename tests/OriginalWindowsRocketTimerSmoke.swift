import Foundation

@main
struct OriginalWindowsRocketTimerSmoke {
    static func main() {
        typealias R = CMOriginalWindowsRocketTimer
        func fires(_ state: Float, at time: Double,
                   started: Double = 4, engine: Bool = true) -> Bool {
            R.readyToExplode(nativeRocketState: state,
                             nativeEnginePresent: engine,
                             engineTime: time, originalLaunchTime: started)
        }
        precondition(R.flyingState == 2 && R.explodedState == 3)
        precondition(R.fuseSeconds == 3)
        precondition(!fires(0, at: 10) && !fires(1, at: 10))
        precondition(!fires(3, at: 10))
        precondition(!fires(2, at: 3))
        precondition(!fires(2, at: 4))
        precondition(!fires(2, at: 6.999999))
        precondition(!fires(2, at: 7))  // native strict >3, not >=3
        precondition(fires(2, at: 7.000001))
        precondition(fires(2, at: 8))
        precondition(!fires(2, at: 10, engine: false))
        precondition(!fires(2, at: .nan))
        precondition(!fires(2, at: .infinity))
        precondition(!fires(2, at: 10, started: .nan))
        precondition(!fires(.nan, at: 10))
        precondition(!fires(.infinity, at: 10))
        precondition(R.terminalStateAfterObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7.01, originalLaunchTime: 4) == 3)
        precondition(R.terminalStateAfterObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7, originalLaunchTime: 4) == nil)
        print("Native Win32 rocket: actual flying 2, live engine, time >3 sec, terminal state 3")
    }
}
