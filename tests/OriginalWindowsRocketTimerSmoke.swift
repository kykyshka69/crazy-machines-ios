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
        precondition(R.ignitedState == 1 && R.flyingState == 2
                     && R.explodedState == 3)
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
        // Two distinct native clocks: rocket ignition time at parent
        // +0x130, Engine child launch time at its own +0x130.
        func launches(_ state: Float, at clock: Double,
                      kind: String = "tmo_heat_rocket") -> Bool {
            R.readyToLaunch(nativeRocketState: state,
                nativeObjectType: kind, clockTime: clock,
                originalIgnitionTime: 4)
        }
        precondition(!launches(0, at: 12))
        precondition(!launches(2, at: 12))
        precondition(!launches(1, at: 7))
        precondition(!launches(1, at: 6.9999))
        precondition(launches(1, at: 7.000001))
        precondition(!launches(1, at: 10, kind: "tmo_heat_dynamite"))
        precondition(!launches(1, at: .nan))
        precondition(R.flyingStateAfterObservedLaunch(
            nativeRocketState: 1, nativeObjectType: "tmo_heat_rocket",
            clockTime: 7.0001, originalIgnitionTime: 4,
            originalEngineChildActivated: false) == nil)
        precondition(R.flyingStateAfterObservedLaunch(
            nativeRocketState: 1, nativeObjectType: "tmo_heat_rocket",
            clockTime: 7.0001, originalIgnitionTime: 4,
            originalEngineChildActivated: true) == 2)
        // A separate launch clock resets at Engine creation. It cannot
        // simply reuse the parent's old ignition clock to trigger GOAL.
        precondition(!fires(2, at: 10.0001, started: 7.0001))
        precondition(fires(2, at: 10.000101, started: 7.0001))
        precondition(R.terminalStateAfterObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7.01, originalLaunchTime: 4) == nil)
        precondition(R.terminalStateAfterObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7.01, originalLaunchTime: 4,
            originalExplosionEffectObserved: true) == 3)
        precondition(R.terminalStateAfterObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7, originalLaunchTime: 4,
            originalExplosionEffectObserved: true) == nil)
        func observed(_ time: Double, effect: Bool,
                      state: Float = 2) -> R.ObservedExplosion {
            .init(nativeRocketState: state, nativeEnginePresent: true,
                  engineTime: time, originalLaunchTime: 4,
                  actualExplosionEffectObserved: effect)
        }
        precondition(!R.triggersGoal(observed(7, effect: true)))
        precondition(!R.triggersGoal(observed(8, effect: false)))
        precondition(!R.triggersGoal(observed(8, effect: true, state: 1)))
        precondition(R.triggersGoal(observed(8, effect: true)))
        print("Native Win32 rocket: actual flying 2, live engine, time >3 sec, terminal state 3")
    }
}
