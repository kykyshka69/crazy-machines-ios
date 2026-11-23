import Foundation

@main struct OriginalRocketSceneHeatSourcesSmoke {
    static func main() {
        let types = [
            "c": "tmo_candle",
            "dynamic": "tmo_candle_dyn",
            "off": "tmo_candle_dyn",
            "fake": "tmo_heat_blowtorch",
            "other": "tmo_candle_dyn_fake",
            "rocket": "tmo_heat_rocket"
        ]
        let observed = CMOriginalRocketSceneHeatSources.litCandleIDs(
            sourceStates: ["c": true, "dynamic": true, "off": false,
                           "fake": true, "other": true, "rocket": true,
                           "": true, "missing": true],
            originalTypesByID: types)
        precondition(observed == ["c", "dynamic"])
        precondition(CMOriginalRocketSceneHeatSources.litCandleIDs(
            sourceStates: ["dynamic": true],
            originalTypesByID: types) == ["dynamic"])
        precondition(CMOriginalRocketSceneHeatSources.litCandleIDs(
            sourceStates: ["dynamic": true, "c": true],
            originalTypesByID: types, maximum: 1) == ["c"])
        precondition(CMOriginalRocketSceneHeatSources.litCandleIDs(
            sourceStates: ["dynamic": true],
            originalTypesByID: types, maximum: -1).isEmpty)
        print("Original mobile/static candle source selection PASS")
    }
}
