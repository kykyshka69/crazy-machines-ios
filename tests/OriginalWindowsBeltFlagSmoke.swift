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
        precondition(goal(0, 0, 1.999))
        precondition(!goal(0, 0, 2))
        precondition(!goal(0, 0, -2.001))
        precondition(!goal(0, 1, 0))
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
        print("Original flag: measured wind region, complete source inventory, native GOAL bounds OK")
    }
}
