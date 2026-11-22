import Foundation

/// Visual-only reconstruction of five original PC 3DO glow references that
/// do not have their own UCM geometry in the user's original installation.
/// The installed pack DOES include matching 64x64 TGA light textures.
/// These are SceneKit billboards, never colliders or additional puzzle objects.
enum CMOriginalEffectBillboard {
    struct Specification: Equatable {
        let textureName: String
        let width: Double
        let height: Double
    }

    // The 3DO positions/rotations/scales come from the authentic scene graph.
    // Plane dimensions and generic light_glow reuse are approximate until
    // the original Windows billboard shader/size parameters are recovered.
    static let known: [String: Specification] = [
        "to_candle_glow": .init(
            textureName: "light_glow", width: 0.55, height: 0.55),
        "to_power_lamp_bulb_bb": .init(
            textureName: "light_glow", width: 0.45, height: 0.45),
        "to_light_pocketlamp_glow": .init(
            textureName: "light_pocketlamp_glow",
            width: 0.55, height: 0.55),
        "to_light_magnifier_glow_left": .init(
            textureName: "light_magnifier_glow",
            width: 0.40, height: 0.40),
        "to_light_magnifier_glow_right": .init(
            textureName: "light_magnifier_glow",
            width: 0.40, height: 0.40)
    ]

    static func specification(for modelReference: String) -> Specification? {
        known[modelReference.lowercased()]
    }
}
