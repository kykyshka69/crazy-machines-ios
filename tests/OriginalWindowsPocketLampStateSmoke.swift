import Foundation

@main
struct OriginalWindowsPocketLampStateSmoke {
    static func main() throws {
        func part(_ type: String, startOn: Bool = false) -> [String: Any] {
            ["name": type, "fields": startOn ? ["VALF 1.000000"] : [],
             "children": []]
        }
        let source: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 92,
            "title": "Synthetic genuine-format initial pocketlamp source states",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    part("tmo_light_pocketlamp"),
                    part("tmo_light_pocketlamp", startOn: true),
                    part("tmo_power_switch"),
                    part("tmo_light_flower")
                ]]
            ]]
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: source))
        var session = CMOriginalGameplaySession(document: document)
        let ids = session.objects.map(\.id)
        precondition(session.originalPocketLampStates[ids[0]] == nil)
        precondition(session.originalPocketLampStates[ids[1]] == true)
        precondition(session.toggleOriginalPocketLamp(ids[0]) == nil)
        session.start()
        precondition(session.originalPocketLampStates[ids[0]] == nil)
        precondition(session.originalPocketLampStates[ids[1]] == true)
        precondition(session.toggleOriginalPocketLamp(ids[2]) == nil)
        precondition(session.toggleOriginalPocketLamp("invalid") == nil)
        precondition(session.toggleOriginalPocketLamp(ids[0]) == true)
        precondition(session.originalPocketLampStates[ids[0]] == true)
        precondition(session.toggleOriginalPocketLamp(ids[1]) == false)
        precondition(session.originalPocketLampStates[ids[1]] == nil)
        precondition(session.toggleOriginalPocketLamp(ids[0]) == false)
        precondition(session.originalPocketLampStates[ids[0]] == nil)
        session.pause()
        precondition(session.toggleOriginalPocketLamp(ids[0]) == nil)
        session.reset()
        precondition(session.originalPocketLampStates[ids[1]] == true)
        session.start()
        precondition(session.originalPocketLampStates[ids[1]] == true)
        precondition(session.toggleOriginalPocketLamp(ids[0]) == true)
        print("Original pocketlamp 0/1 native click and authored level-92 VALF 1 startup and reset: OK")
    }
}
