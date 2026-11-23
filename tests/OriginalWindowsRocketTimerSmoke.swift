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
        // Native lit candle->rocket is the physically measured region
        // (0x409650) with STRICT >0.84, not arbitrary mesh contact.
        let threshold = R.candleIgnitionCutoff
        precondition(threshold.bitPattern == 0x3F570A3D)
        func candle(_ fraction: Float, lit: Bool = true,
                    rocketState: Float = 0,
                    sourceType: String = "tmo_candle") -> Bool {
            R.acceptsObservedCandleIgnition(
                nativeRocketType: "tmo_heat_rocket",
                nativeRocketState: rocketState,
                nativeHeatSourceType: sourceType,
                originalCandleLit: lit,
                measuredNativeHeatFraction: fraction)
        }
        precondition(!candle(threshold))
        precondition(candle(threshold.nextUp))
        precondition(candle(1))
        precondition(!candle(0.5))
        precondition(!candle(0.9, lit: false))
        precondition(!candle(0.9, rocketState: 1))
        precondition(!candle(0.9, sourceType: "tmo_windmill"))
        precondition(!candle(.nan))
        precondition(!candle(1.5))
        precondition(R.ignitionAfterObservedCandleEffect(
            nativeRocketType: "tmo_heat_rocket", nativeRocketState: 0,
            nativeHeatSourceType: "tmo_candle", originalCandleLit: true,
            measuredNativeHeatFraction: 0.9,
            originalIgnitionEffectObserved: false,
            observedNativeClock: 4) == nil)
        let lit = R.ignitionAfterObservedCandleEffect(
            nativeRocketType: "tmo_heat_rocket", nativeRocketState: 0,
            nativeHeatSourceType: "tmo_candle", originalCandleLit: true,
            measuredNativeHeatFraction: 0.9,
            originalIgnitionEffectObserved: true,
            observedNativeClock: 4)
        precondition(lit?.state == 1 && lit?.ignitionTime == 4)
        precondition(R.ignitionAfterObservedCandleEffect(
            nativeRocketType: "tmo_heat_rocket", nativeRocketState: 0,
            nativeHeatSourceType: "tmo_candle", originalCandleLit: true,
            measuredNativeHeatFraction: 0.9,
            originalIgnitionEffectObserved: true,
            observedNativeClock: .infinity) == nil)
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

        // Native region geometry -> strict >0.84 ignition -> observed
        // effect and own parent clock, never arbitrary SceneKit contacts.
        let nativeRegion = CMOriginalWindowsWindRegion.Parameters(
            nativeAxis: .init(1, 0),
            minRadiusSquared: 1, maxRadiusSquared: 100,
            radialFalloff: 0.01, maximumAngle: .pi / 2,
            angularFalloff: 2 / .pi)
        func hit(_ displacement: CMOriginalWindowsWindRegion.Vector3,
                 source: String = "tmo_candle",
                 lit: Bool = true, effect: Bool = true,
                 state: Float = 0, clock: Double = 4)
            -> R.ObservedIgnition? {
            R.ignitionAfterObservedNativeCandleRegion(
                nativeRocketState: state,
                nativeHeatSourceType: source,
                originalCandleLit: lit,
                observedNativeHeatRegion: nativeRegion,
                observedNativeDisplacement: displacement,
                originalIgnitionEffectObserved: effect,
                observedNativeClock: clock)
        }
        precondition(hit(.init(4, 0))?.state == 1)
        precondition(hit(.init(4, 0))?.ignitionTime == 4)
        precondition(hit(.init(5, 0)) == nil)
        precondition(hit(.init(-4, 0)) == nil)
        precondition(hit(.init(0, 0)) == nil)
        precondition(hit(.init(.nan, 0)) == nil)
        precondition(hit(.init(4, 0), lit: false) == nil)
        precondition(hit(.init(4, 0), effect: false) == nil)
        precondition(hit(.init(4, 0), state: 1) == nil)
        precondition(hit(.init(4, 0), source: "tmo_windmill") == nil)
        precondition(hit(.init(4, 0), clock: .nan) == nil)

        // The native 0x409650 routine explicitly removes Z before
        // computing overlap: heat ignition must depend on planar XY.
        precondition(hit(.init(4, 0, 50_000))?.state == 1)
        precondition(hit(.init(4, 0, .nan))?.state == 1)
        precondition(hit(.init(0, 0, 4)) == nil)
        print("Native Win32 rocket: actual flying 2, live engine, time >3 sec, terminal state 3")
    }
}
