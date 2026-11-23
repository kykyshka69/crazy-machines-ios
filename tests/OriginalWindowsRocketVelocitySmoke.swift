import Foundation

@main
struct OriginalWindowsRocketVelocitySmoke {
    static func main() {
        typealias R = CMOriginalWindowsRocketVelocity
        let original = ["VELOCITY": ["4.0"], "VALF": ["0.125"]]
        func actual(_ type: String = "tmo_heat_rocket_rocket",
                    _ scene: [String: [String]] = [:],
                    _ defaults: [String: [String]]? = original) -> R.Evidence? {
            R.initialChildFC(originalChildType: type, sceneFields: scene,
                             originalTemplateFields: defaults)
        }
        precondition(actual()?.initialChildFC == 4)
        precondition(actual()?.origin == .originalElementsTemplate)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["2.5"]])?.initialChildFC == 2.5)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["2.5"]])?.origin == .originalSceneOverride)
        precondition(actual("tmo_candle") == nil)
        precondition(actual("tmo_heat_rocket_mount") == nil)
        precondition(actual("tmo_heat_rocket_rocket", [:], nil) == nil)
        precondition(actual("tmo_heat_rocket_rocket", [:], ["VALF":["0.125"]]) == nil)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["no"]]) == nil)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["4", "1"]]) == nil)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": []]) == nil)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["infinity"]]) == nil)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["nan"]]) == nil)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["0"]])?.initialChildFC == 0)
        precondition(actual("tmo_heat_rocket_rocket",
                            ["VELOCITY": ["-2"]])?.initialChildFC == -2)
        print("Native initial rocket child +0xFC from authentic VELOCITY: PASS")
    }
}
