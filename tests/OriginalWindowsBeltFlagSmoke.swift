import Foundation

@main
struct OriginalWindowsBeltFlagSmoke {
    static func main() {
        typealias F = CMOriginalWindowsBeltFlag
        func goal(_ indicator: Float, _ state: Float, _ wind: Float) -> Bool {
            F.triggersGoal(.init(telescopeIndicator: indicator,
                                 flagState: state, observedNetWindForce: wind))
        }
        let marker = F.nativeTelescopeMarker
        precondition(marker.bitPattern == 0x3ec28f5c)
        precondition(!goal(marker, 0, 1.999))
        precondition(goal(marker, 0, 2))
        precondition(goal(marker, 0, -2))
        precondition(!goal(marker, 1, 2))
        precondition(!goal(marker, 0, 0))
        precondition(!goal(0, 0, 1.999))
        precondition(goal(0, 1, 1.999))
        precondition(!goal(0, 0, 2))
        precondition(!goal(0, 0, -2.001))
        precondition(goal(0, 1, 0))
        precondition(!goal(0, 1, 2))
        precondition(!goal(.nan, 0, 1))
        precondition(!goal(0, 0, .infinity))
        precondition(!goal(0, .nan, 1))
        func wind(_ id: String, _ kind: String,
                  _ factor: Float, _ power: Float) -> F.WindObservation {
            .init(originalSourceID: id, originalSourceType: kind,
                  signedIntersection: factor, originalWindPower: power)
        }
        precondition(F.nativeWindSum(observations: [],
            requiredOriginalWindSourceIDs: [], allOriginalWindSourcesObserved: false) == nil)
        precondition(F.nativeWindSum(observations: [],
            requiredOriginalWindSourceIDs: [], allOriginalWindSourcesObserved: true) == 0)
        let actual = [wind("windmill-1", "tmo_windmill", 0.8, 4),
                      wind("bellows-1", "tmo_wind_bellows", -0.4, 2)]
        precondition(F.nativeWindSum(observations: actual,
            requiredOriginalWindSourceIDs: ["windmill-1", "bellows-1"],
            allOriginalWindSourcesObserved: true) == 1.2)
        precondition(F.nativeWindSum(observations: actual,
            requiredOriginalWindSourceIDs: ["windmill-1", "bellows-1"],
            allOriginalWindSourcesObserved: false) == nil)
        precondition(F.nativeWindSum(observations: [actual[0], actual[0]],
            requiredOriginalWindSourceIDs: [], allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [
            wind("x", "tmo_belt_gear", 1, 10)],
            requiredOriginalWindSourceIDs: [], allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [
            wind("x", "tmo_windmill", .nan, 1)],
            requiredOriginalWindSourceIDs: [], allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [
            wind("x", "tmo_windmill", 1, .infinity)],
            requiredOriginalWindSourceIDs: [], allOriginalWindSourcesObserved: true) == nil)
        // Level 34 really contains ONE native tmo_windmill emitter. A
        // missing observation must not turn the flag's low-wind branch on.
        precondition(F.nativeWindSum(observations: [],
            requiredOriginalWindSourceIDs: ["native-level-34-windmill"],
            allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [actual[0]],
            requiredOriginalWindSourceIDs: ["windmill-1", "bellows-1"],
            allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [actual[0]],
            requiredOriginalWindSourceIDs: ["unknown"],
            allOriginalWindSourcesObserved: true) == nil)
        let nativeRegion = CMOriginalWindowsWindRegion.Parameters(
            nativeAxis: .init(1, 0),
            minRadiusSquared: 1, maxRadiusSquared: 100,
            radialFalloff: 0.01,
            maximumAngle: .pi / 2, angularFalloff: 2 / .pi)
        let sample = F.observedSource(
            originalSourceID: "native-level-34-windmill",
            originalSourceType: "tmo_windmill",
            originalWindPower: 10,
            observedNativeRegion: nativeRegion,
            observedNativeDisplacement: .init(5, 0),
            sourceDepth: 0, targetDepth: 1)!
        precondition(sample.signedIntersection < 0)
        let measured = F.nativeWindSum(observations: [sample],
            requiredOriginalWindSourceIDs: ["native-level-34-windmill"],
            allOriginalWindSourcesObserved: true)!
        precondition(abs(measured + 3.8) < 0.00001)
        precondition(F.triggersGoal(.init(
            telescopeIndicator: F.nativeTelescopeMarker,
            flagState: 0, observedNetWindForce: measured)))
        for hz in [30, 60, 120] {
            var height: Float = 0
            for _ in 0..<(hz*3) {
                height = F.nextExtension(previous: height, wheelSignal: 5, delta: 1/Double(hz))!
                precondition((0...marker).contains(height))
            }
            precondition(height == marker)
            for _ in 0..<(hz*3) {
                height = F.nextExtension(previous: height, wheelSignal: -5, delta: 1/Double(hz))!
            }
            precondition(height == 0)
        }
        precondition(F.nextExtension(previous: marker, wheelSignal: 0, delta: 0.1) == marker)
        precondition(F.nextExtension(previous: 0, wheelSignal: .nan, delta: 0.1) == nil)
        let forward = F.windmillRegion(axis: .init(1, 0), wheelSignal: 5)!
        let reverse = F.windmillRegion(axis: .init(1, 0), wheelSignal: -5)!
        precondition(forward.nativeAxis.x == 1 && reverse.nativeAxis.x == -1)
        precondition(abs(sqrt(forward.maxRadiusSquared) - sqrt(forward.minRadiusSquared) - 1) < 0.00001)
        precondition(F.windmillRegion(axis: .init(1, 0), wheelSignal: 0) == nil)
        for hz in [30,60,120] {
            for sign: Float in [-1,1] {
                var bellows = CMOriginalBellows()
                precondition(!bellows.strike(normalY: 0.9, leverAngle: sign * 0.37))
                precondition(!bellows.strike(normalY: .nan, leverAngle: 0))
                precondition(bellows.strike(normalY: 1, leverAngle: sign * 0.37))
                precondition(!bellows.strike(normalY: 1, leverAngle: 0))
                for _ in 0..<hz {
                    let old = bellows.power
                    precondition(bellows.advance(delta: 1/Double(hz)))
                    precondition(bellows.power <= old && bellows.power >= 0)
                    precondition(abs(bellows.leverAngle - sign * 0.37 * bellows.power / 5) < 0.00001)
                    if bellows.power > 0 {
                        let region = bellows.region(axis: .init(sign,0))!
                        precondition(abs(sqrt(region.maxRadiusSquared) -
                            sqrt(region.minRadiusSquared) - old*0.5) < 0.00001)
                    }
                }
                precondition(bellows.phase == .spent && bellows.power == 0 && bellows.leverAngle == 0)
                precondition(!bellows.strike(normalY: 1, leverAngle: 0))
            }
        }
        typealias W = CMOriginalWindReceiver
        precondition(!W.extinguishesCandle(lit: true, fraction: 0.5, power: 5))
        precondition(W.extinguishesCandle(lit: true, fraction: Float(0.5).nextUp, power: 5))
        precondition(W.extinguishesCandle(lit: true, fraction: 1, power: -5))
        precondition(!W.extinguishesCandle(lit: false, fraction: 1, power: 5))
        precondition(!W.extinguishesCandle(lit: true, fraction: .nan, power: 5))
        precondition(!W.extinguishesCandle(lit: true, fraction: 1.1, power: 5))
        for source: Float in [-1,1] {
            for receiver: Float in [-1,1] {
                for power: Float in [-5,5] {
                    let desired = W.wingsTarget(fraction: 0.8, power: power,
                        sourceMirror: source, receiverMirror: receiver)!
                    precondition(desired == -source * receiver * power * 0.6)
                    for hz in [30,60,120] {
                        var current: Float = 0
                        for _ in 0..<(hz*3) {
                            let next = W.nextWingsSignal(previous: current, target: desired,
                                delta: 1/Double(hz))!
                            precondition(abs(desired-next) <= abs(desired-current))
                            current = next
                        }
                        precondition(abs(current-desired) < 0.16)
                    }
                }
            }
        }
        precondition(W.wingsTarget(fraction: 1, power: 5, sourceMirror: 0, receiverMirror: 1) == nil)
        precondition(W.nextWingsSignal(previous: 0, target: 1, delta: -1) == nil)
        print("Original flag: measured wind region, complete source inventory, native GOAL bounds OK")
    }
}
