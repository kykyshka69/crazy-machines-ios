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
            allOriginalWindSourcesObserved: false) == nil)
        precondition(F.nativeWindSum(observations: [],
            allOriginalWindSourcesObserved: true) == 0)
        let actual = [wind("windmill-1", "tmo_windmill", 0.8, 4),
                      wind("bellows-1", "tmo_wind_bellows", -0.4, 2)]
        precondition(F.nativeWindSum(observations: actual,
            allOriginalWindSourcesObserved: true) == 1.2)
        precondition(F.nativeWindSum(observations: actual,
            allOriginalWindSourcesObserved: false) == nil)
        precondition(F.nativeWindSum(observations: [actual[0], actual[0]],
            allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [
            wind("x", "tmo_belt_gear", 1, 10)],
            allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [
            wind("x", "tmo_windmill", .nan, 1)],
            allOriginalWindSourcesObserved: true) == nil)
        precondition(F.nativeWindSum(observations: [
            wind("x", "tmo_windmill", 1, .infinity)],
            allOriginalWindSourcesObserved: true) == nil)
        print("Original flag: true measured wind sum, two native GOAL bounds, unknown fails closed")
    }
}
