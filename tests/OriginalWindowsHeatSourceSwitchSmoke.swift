import Foundation

@main
struct OriginalWindowsHeatSourceSwitchSmoke {
    static func main() throws {
        func part(_ type: String, valf: Float? = nil, bits: Int = 176) -> [String: Any] {
            let fields = ["VALB \(bits)"] + (valf.map { ["VALF \($0)"] } ?? [])
            return ["name": type, "fields": fields, "children": []]
        }
        let source: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 21,
            "title": "Synthetic original-format thermal click states",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    part("tmo_candle", valf: 1, bits: 48),
                    part("tmo_candle_dyn", bits: 120),
                    part("tmo_heat_blowtorch"),
                    part("tmo_power_switch"),
                    part("tmo_candle", bits: 0)
                ]]
            ]]
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: source))
        var session = CMOriginalGameplaySession(document: document)
        let ids = session.objects.map(\.id)
        precondition(session.toggleOriginalHeatSource(ids[0]) == nil)
        session.start()
        precondition(session.originalHeatSourceStates[ids[0]] == true)
        precondition(session.originalHeatSourceStates[ids[1]] == nil)
        precondition(session.toggleOriginalHeatSource(ids[0]) == false)
        precondition(session.originalHeatSourceStates[ids[0]] == nil)
        precondition(session.toggleOriginalHeatSource(ids[1]) == true)
        precondition(session.toggleOriginalHeatSource(ids[2]) == true)
        precondition(session.toggleOriginalHeatSource(ids[3]) == nil)
        precondition(session.toggleOriginalHeatSource(ids[4]) == nil)
        precondition(session.originalHeatSourceStates[ids[1]] == true)
        precondition(session.originalHeatSourceStates[ids[2]] == true)
        session.pause()
        precondition(session.toggleOriginalHeatSource(ids[1]) == nil)
        session.reset()
        precondition(session.originalHeatSourceStates[ids[0]] == true)
        precondition(session.originalHeatSourceStates[ids[1]] == nil)
        precondition(session.originalHeatSourceStates[ids[2]] == nil)
        session.start()
        precondition(session.toggleOriginalHeatSource(ids[0]) == false)
        print("Original candle, dynamic candle and blowtorch click states +0xEC and VALF initial/reset: OK")
    }
}
