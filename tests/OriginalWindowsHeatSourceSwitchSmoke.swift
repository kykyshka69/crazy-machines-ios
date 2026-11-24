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
        precondition(session.originalHeatSourceStates[ids[0]] == true)
        precondition(session.originalHeatSourceStates[ids[1]] == nil)
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
        // Focus ignition bypasses the click bit; the click API stays gated.
        precondition(session.igniteOriginalCandleFromFocus(ids[4]))
        precondition(session.originalHeatSourceStates[ids[4]] == true)
        precondition(!session.igniteOriginalCandleFromFocus(ids[4]))
        precondition(session.toggleOriginalHeatSource(ids[4]) == nil)
        precondition(session.igniteOriginalCandleFromFocus(ids[0]))
        precondition(!session.igniteOriginalCandleFromFocus(ids[1]))
        precondition(!session.igniteOriginalCandleFromFocus(ids[2]))
        precondition(!session.igniteOriginalCandleFromFocus(ids[3]))
        precondition(!session.igniteOriginalCandleFromFocus("missing"))
        session.pause()
        precondition(!session.igniteOriginalCandleFromFocus(ids[0]))
        precondition(session.toggleOriginalHeatSource(ids[1]) == nil)
        session.reset()
        precondition(session.originalHeatSourceStates[ids[0]] == true)
        precondition(session.originalHeatSourceStates[ids[1]] == nil)
        precondition(session.originalHeatSourceStates[ids[2]] == nil)
        precondition(session.originalHeatSourceStates[ids[4]] == nil)
        precondition(!session.igniteOriginalCandleFromFocus(ids[4]))
        session.start()
        precondition(session.igniteOriginalCandleFromFocus(ids[4]))
        precondition(session.toggleOriginalHeatSource(ids[0]) == false)
        for (type, marker, radius) in [
            ("tmo_nail", "Pike", Float(0.05)),
            ("tmo_hammer_nail", "Pike", Float(0.14)),
            ("tmo_rope_crossbow_arrow", "Cut", Float(0.09))
        ] {
            let rule = CMOriginalBalloonPuncture.rule(for: type)!
            precondition(rule.marker == marker && rule.radius == radius)
            for axis in 0..<3 {
                for sign: Float in [-1, 1] {
                    for scale: Float in [0, 0.5, 0.999, 1, 1.001, 2] {
                        var p = SIMD3<Float>.zero
                        p[axis] = sign * radius * scale
                        precondition(CMOriginalBalloonPuncture.hits(
                            point: p, marker: .zero, radius: radius) == (scale < 1))
                    }
                }
            }
        }
        for type in ["tmo_ball_basket", "tmo_board", "tmo_rope_crossbow", "tmo_hammer"] {
            precondition(CMOriginalBalloonPuncture.rule(for: type) == nil)
        }
        precondition(!CMOriginalBalloonPuncture.hits(
            point: .init(.nan, 0, 0), marker: .zero, radius: 0.05))
        precondition(!CMOriginalBalloonPuncture.hits(
            point: .zero, marker: .zero, radius: 0))
        for axis in 0..<3 {
            for sign: Float in [-1, 1] {
                for scale: Float in [0, 0.5, 0.999, 1, 1.001, 2] {
                    var p = SIMD3<Float>.zero
                    p[axis] = sign * 0.1 * scale
                    var stroke = CMOriginalCatapultStroke()
                    precondition(stroke.trigger(contact: p, button: .zero) == (scale < 1))
                }
            }
        }
        for fps in [30, 60, 120, 240] {
            var stroke = CMOriginalCatapultStroke()
            let dt = 1.0 / Double(fps)
            precondition(stroke.advance(delta: dt) == nil)
            precondition(stroke.trigger(contact: .zero, button: .zero))
            precondition(!stroke.trigger(contact: .zero, button: .zero))
            for invalid in [0, -1, Double.nan, 0.26] {
                precondition(stroke.advance(delta: invalid) == nil)
            }
            var last: Float = 0
            var steps = 0
            while let angle = stroke.advance(delta: dt) {
                precondition(angle > last && angle <= .pi / 4)
                last = angle
                steps += 1
                precondition(steps <= fps)
            }
            precondition(stroke.phase == .finished && last == .pi / 4)
            precondition(!stroke.trigger(contact: .zero, button: .zero))
        }
        print("Original candle, dynamic candle and blowtorch click states +0xEC and VALF initial/reset: OK")
    }
}
