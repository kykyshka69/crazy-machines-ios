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
        for mirrored in [false, true] {
            let sign: Float = mirrored ? 1 : -1
            for angle: Float in [-1, -0.301, -0.3, -0.299, 0, 0.299, 0.3, 0.301, 1] {
                precondition(CMOriginalCrossbowRelease.leverReady(angle: angle, mirrored: mirrored)
                    == (angle * sign > 0.3))
            }
            var crossbow = CMOriginalCrossbowRelease()
            let direction = SIMD3<Float>(mirrored ? -1 : 1, 0.25, 0.1)
            precondition(crossbow.release(angle: sign * 0.3, mirrored: mirrored, direction: direction) == nil)
            precondition(crossbow.release(angle: sign * 0.31, mirrored: mirrored, direction: .zero) == nil)
            precondition(crossbow.release(angle: sign * 0.31, mirrored: mirrored, direction: .init(.nan, 0, 0)) == nil)
            precondition(!crossbow.released)
            precondition(crossbow.release(angle: sign * 0.31, mirrored: mirrored, direction: direction)
                == .init(direction.x * 20, direction.y, 0))
            precondition(crossbow.released)
            precondition(crossbow.release(angle: sign * 0.5, mirrored: mirrored, direction: direction) == nil)
        }
        precondition(!CMOriginalCrossbowRelease.leverReady(angle: .nan, mirrored: false))
        typealias HeatSample = CMOriginalBalloonHeatSample
        let origin = SIMD3<Float>(1, 2, 3)
        precondition(HeatSample.candle(origin: origin, axis: .init(0, 2, 0)) == origin + .init(0, 0.15, 0))
        precondition(HeatSample.candle(origin: origin, axis: .init(0, -2, 0)) == origin + .init(0, -0.15, 0))
        precondition(HeatSample.torch(origin: origin, axis: .init(2, 0, 0)) == origin + .init(0.3, 0, 0))
        precondition(HeatSample.torch(origin: origin, axis: .init(-2, 0, 0)) == origin + .init(-0.3, 0, 0))
        precondition(HeatSample.candle(origin: origin, axis: .init(0, 0, 1)) == nil)
        precondition(HeatSample.torch(origin: origin, axis: .init(0, 1, 0)) == nil)
        precondition(HeatSample.candle(origin: .init(.nan, 0, 0), axis: .init(0, 1, 0)) == nil)
        precondition(HeatSample.focus(position: origin, light: Float(0.5).nextDown) == nil)
        precondition(HeatSample.focus(position: origin, light: 0.5) == origin)
        precondition(HeatSample.focus(position: origin, light: 1) == origin)
        precondition(HeatSample.focus(position: origin, light: 1.01) == nil)
        precondition(HeatSample.focus(position: origin, light: .nan) == nil)
        typealias Fuze = CMOriginalFuzePath
        let k1 = Fuze.Knot(index: 1, position: .zero)
        let k2 = Fuze.Knot(index: 2, position: .init(1, 1, 0))
        let k3 = Fuze.Knot(index: 3, position: .init(2, -1, 0))
        precondition(Fuze.ordered([k3, k1, k2]) == [k1.position, k2.position, k3.position])
        precondition(Fuze.ordered([k1, k2]) == [k1.position, k2.position])
        precondition(Fuze.ordered([]) == nil)
        precondition(Fuze.ordered([k1]) == nil)
        precondition(Fuze.ordered([k1, k1]) == nil)
        precondition(Fuze.ordered([k1, k3]) == nil)
        precondition(Fuze.ordered([k1, .init(index: 2, position: .zero)]) == nil)
        precondition(Fuze.ordered([k1, .init(index: 2, position: .init(.nan, 0, 0))]) == nil)
        precondition(Fuze.ordered([k1, .init(index: 2, position: .init(1001, 0, 0))]) == nil)
        // Geometry of the virtual scissors cut is independent of the
        // original route's authored direction and of blade direction.
        for x: Float in [0, 0.25, 0.5, 0.75, 1] {
            let a = SIMD3<Float>(0, 0, 0), b = SIMD3<Float>(1, 0, 0)
            let c = SIMD3<Float>(x, -1, 0), d = SIMD3<Float>(x, 1, 0)
            precondition(abs(Fuze.closestCutFraction(spanStart: a, spanEnd: b,
                bladeStart: c, bladeEnd: d)! - x) < 0.00001)
            precondition(abs(Fuze.closestCutFraction(spanStart: b, spanEnd: a,
                bladeStart: d, bladeEnd: c)! - (1-x)) < 0.00001)
        }
        precondition(Fuze.closestCutFraction(spanStart: .zero, spanEnd: .zero,
            bladeStart: .zero, bladeEnd: .init(1,0,0)) == nil)
        precondition(Fuze.closestCutFraction(spanStart: .zero, spanEnd: .init(1,0,0),
            bladeStart: .init(.nan,0,0), bladeEnd: .init(1,1,0)) == nil)
        precondition(Fuze.visiblePieces(cut: 0.5, gap: 0.25) == [0...0.375,0.625...1])
        precondition(Fuze.visiblePieces(cut: 0, gap: 0.25) == [0.125...1])
        precondition(Fuze.visiblePieces(cut: 1, gap: 0.25) == [0...0.875])
        precondition(Fuze.visiblePieces(cut: 0.5, gap: 1).isEmpty)
        precondition(Fuze.visiblePieces(cut: .nan, gap: 0.25).isEmpty)
        print("Original candle, dynamic candle and blowtorch click states +0xEC and VALF initial/reset: OK")
    }
}
