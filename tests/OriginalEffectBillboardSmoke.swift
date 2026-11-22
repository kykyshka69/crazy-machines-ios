import Foundation

@main
struct OriginalEffectBillboardSmoke {
    static func main() {
        let expected: [String: String] = [
            "to_candle_glow": "light_glow",
            "to_power_lamp_bulb_bb": "light_glow",
            "to_light_pocketlamp_glow": "light_pocketlamp_glow",
            "to_light_magnifier_glow_left": "light_magnifier_glow",
            "to_light_magnifier_glow_right": "light_magnifier_glow"
        ]
        precondition(CMOriginalEffectBillboard.known.count == 5)
        precondition(Set(CMOriginalEffectBillboard.known.keys) ==
                     Set(expected.keys))
        for (reference, texture) in expected {
            guard let spec = CMOriginalEffectBillboard.specification(
                for: reference
            ) else { preconditionFailure("missing original glow: " + reference) }
            precondition(spec.textureName == texture)
            precondition(spec.width > 0 && spec.width < 2)
            precondition(spec.height > 0 && spec.height < 2)
            precondition(spec.width == spec.height)
            precondition(CMOriginalEffectBillboard.specification(
                for: reference.uppercased()) == spec)
        }
        precondition(CMOriginalEffectBillboard.specification(
            for: "to_ball_tennis") == nil)
        precondition(CMOriginalEffectBillboard.specification(
            for: "to_nonexistent_effect") == nil)
        // The 85 references in 48 private PC levels must not become
        // synthetic physics bodies just because they have a TGA image.
        print("Five original visual-only glow references mapped: OK")
    }
}
