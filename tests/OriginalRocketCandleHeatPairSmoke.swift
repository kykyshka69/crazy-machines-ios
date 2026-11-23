import Foundation

@main
struct OriginalRocketCandleHeatPairSmoke {
    static func main() {
        typealias H = CMOriginalRocketCandleHeatPair
        func measure(source: String = "tmo_candle", lit: Bool = true,
                     c: String = "candle-1", p: String = "rocket-1",
                     r: String = "rocket-child-1",
                     pt: String = "tmo_heat_rocket",
                     rt: String = "tmo_heat_rocket_rocket",
                     from: H.Position? = .init(2, 3, 5),
                     to: H.Position? = .init(5, -1, -9)) -> H.Observation? {
            H.measure(candleID: c, sourceType: source, sourceLit: lit,
                      sourceHeatWorld: from, rocketParentID: p,
                      rocketChildID: r, parentType: pt, childType: rt,
                      targetHeatWorld: to)
        }
        precondition(measure()?.sourceToTargetXY == .init(3, -4, 0))
        precondition(measure()?.xyDistanceSquared == 25)
        precondition(measure(lit: false) == nil)
        precondition(measure(source: "tmo_candle_dyn") == nil)
        precondition(measure(source: "tmo_heat_blowtorch") == nil)
        precondition(measure(pt: "tmo_ball") == nil)
        precondition(measure(rt: "tmo_ball") == nil)
        precondition(measure(c: "rocket-1") == nil)
        precondition(measure(c: "rocket-child-1") == nil)
        precondition(measure(p: "rocket-child-1") == nil)
        precondition(measure(from: nil) == nil)
        precondition(measure(to: nil) == nil)
        precondition(measure(from: .init(.nan, 0)) == nil)
        precondition(measure(to: .init(.infinity, 0)) == nil)
        precondition(measure(from: .init(1, 1, 1000),
                             to: .init(1, 1, -1000))?.xyDistanceSquared == 0)
        print("Authentic lit candle/rocket Heat UCM XY pairs: PASS (no fictional ignition)")
    }
}
