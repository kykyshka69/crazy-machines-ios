import Foundation

@main
struct OriginalWindowsSourceClickGoalSmoke {
    static func main() throws {
        func piece(_ type: String, startOn: Bool, goal: Bool,
                   bits: Int = 176) -> [String: Any] {
            let fields = ["VALB \(bits)"]
                + (startOn ? ["VALF 1.000000"] : [])
                + (goal ? ["GOAL 1"] : [])
            return ["name": type, "fields": fields, "children": []]
        }
        let doc: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 21,
            "title": "Native 0x455241 source snapshot + click goals",
            "scene_sha256": String(repeating: "b", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    piece("tmo_candle", startOn: false, goal: true, bits: 48),
                    piece("tmo_candle_dyn", startOn: true, goal: true, bits: 120),
                    piece("tmo_heat_blowtorch", startOn: false, goal: true),
                    piece("tmo_light_pocketlamp", startOn: false, goal: true),
                    piece("tmo_heat_blowtorch", startOn: true, goal: false)
                ]]
            ]]
        ]
        let original = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: doc))
        var game = CMOriginalGameplaySession(document: original)
        let ids = game.objects.map(\.id)
        var counter = CMOriginalWindowsGoalCounter(session: game)!
        precondition(counter.totalRequired == 4)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[0]) == nil)
        game.start()
        for id in ids.prefix(4) {
            precondition(game.nativeClickedSourceGoalSatisfied(id) == false)
        }
        precondition(game.toggleOriginalHeatSource(ids[0]) == true)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[0]) == true)
        precondition(counter.recordGoalEvent(objectID: ids[0], simulationRunning: true)
            == .credited)
        precondition(game.toggleOriginalHeatSource(ids[0]) == false)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[0]) == false)
        precondition(game.toggleOriginalHeatSource(ids[1]) == false)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[1]) == true)
        precondition(counter.recordGoalEvent(objectID: ids[1], simulationRunning: true)
            == .credited)
        precondition(game.toggleOriginalHeatSource(ids[2]) == true)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[2]) == true)
        precondition(counter.recordGoalEvent(objectID: ids[2], simulationRunning: true)
            == .credited)
        precondition(game.toggleOriginalPocketLamp(ids[3]) == true)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[3]) == true)
        precondition(counter.recordGoalEvent(objectID: ids[3], simulationRunning: true)
            == .allInputsCredited)
        precondition(counter.completed)
        precondition(game.toggleOriginalHeatSource(ids[4]) == false)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[4]) == nil)
        game.reset()
        counter.reset()
        game.start()
        precondition(game.nativeClickedSourceGoalSatisfied(ids[0]) == false)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[1]) == false)
        precondition(game.nativeClickedSourceGoalSatisfied(ids[3]) == false)
        precondition(!counter.completed && counter.credited == 0)
        print("Native Win32 click GOAL: baseline +0xF0, source +0xEC, correct snapshot/polarity/latch/reset")
    }
}
