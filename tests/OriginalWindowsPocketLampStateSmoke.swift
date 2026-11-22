import Foundation

@main
struct OriginalWindowsPocketLampStateSmoke {
    static func main() throws {
        func object(_ name: String) -> [String: Any] {
            ["name": name, "fields": [], "children": []]
        }
        let root: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 47,
            "title": "Synthetic genuine-format click source state",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": [
                "name": "level", "fields": [], "children": [
                    ["name": "level_elements", "fields": [], "children": [
                        object("tmo_light_pocketlamp"),
                        object("tmo_light_pocketlamp"),
                        object("tmo_power_switch"),
                        object("tmo_light_flower")
                    ]]
                ]
            ]
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: root))
        var game = CMOriginalGameplaySession(document: document)
        let ids = game.objects.map(\.id)
        precondition(game.toggleOriginalPocketLamp(ids[0]) == nil)
        game.start()
        precondition(game.originalPocketLampStates.isEmpty)
        precondition(game.toggleOriginalPocketLamp(ids[2]) == nil)
        precondition(game.toggleOriginalPocketLamp("unknown") == nil)
        precondition(game.toggleOriginalPocketLamp(ids[0]) == true)
        precondition(game.originalPocketLampStates[ids[0]] == true)
        precondition(game.originalPocketLampStates[ids[1]] == nil)
        precondition(game.toggleOriginalPocketLamp(ids[1]) == true)
        precondition(game.toggleOriginalPocketLamp(ids[0]) == false)
        precondition(game.originalPocketLampStates[ids[0]] == nil)
        precondition(game.originalPocketLampStates[ids[1]] == true)
        game.pause()
        precondition(game.toggleOriginalPocketLamp(ids[0]) == nil)
        game.reset()
        precondition(game.originalPocketLampStates.isEmpty)
        game.start()
        precondition(game.toggleOriginalPocketLamp(ids[0]) == true)
        print("Authentic Win32 pocketlamp click +0xEC: 0->1->0, distinct original IDs, pause and restart OK")
    }
}
