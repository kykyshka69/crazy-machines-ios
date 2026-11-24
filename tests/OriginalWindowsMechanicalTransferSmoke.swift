import Foundation

@main
struct OriginalWindowsMechanicalTransferSmoke {
    static func main() {
        typealias M = CMOriginalWindowsMechanicalTransfer
        func close(_ value: Float?, _ expected: Float) -> Bool {
            guard let value else { return false }
            return abs(value - expected) < 0.00001
        }
        // Values from original PC CML: motor rotor/gear VALF=0.125;
        // original conveyor wheel VALF=0.100.
        precondition(close(M.transmittedSignal(sourceSignal: 2,
            sourceVALF: 0.125, targetVALF: 0.125), 2))
        precondition(close(M.transmittedSignal(sourceSignal: 2,
            sourceVALF: 0.125, targetVALF: 0.1), 2.5))
        precondition(close(M.transmittedSignal(sourceSignal: 2,
            sourceVALF: 0.125, targetVALF: 0.1,
            reversesDirection: true), -2.5))
        precondition(close(M.transmittedSignal(sourceSignal: -2,
            sourceVALF: 0.1, targetVALF: 0.125), -1.6))
        precondition(M.transmittedSignal(sourceSignal: 0,
            sourceVALF: 0.125, targetVALF: 0.1) == 0)
        precondition(M.transmittedSignal(sourceSignal: 10,
            sourceVALF: 0.125, targetVALF: 0) == nil)
        precondition(M.transmittedSignal(sourceSignal: 10,
            sourceVALF: 0.125, targetVALF: -0.1) == nil)
        precondition(M.transmittedSignal(sourceSignal: .nan,
            sourceVALF: 0.125, targetVALF: 0.1) == nil)
        precondition(M.transmittedSignal(sourceSignal: Float.greatestFiniteMagnitude,
            sourceVALF: Float.greatestFiniteMagnitude,
            targetVALF: 0.01) == nil)
        precondition(close(M.decayedSignal(previous: 4,
            observedNativeStep: 0.25), 3))
        precondition(close(M.decayedSignal(previous: -4,
            observedNativeStep: 0.5), -2))
        precondition(close(M.decayedSignal(previous: 4,
            observedNativeStep: 1), 0))
        precondition(M.decayedSignal(previous: 4,
            observedNativeStep: -0.01) == nil)
        precondition(M.decayedSignal(previous: 4,
            observedNativeStep: .nan) == nil)
        typealias R = CMOriginalRope
        let hook = R.Endpoint(objectID: "hook", marker: "Rope")
        let lever = R.Endpoint(objectID: "lever", marker: "Rope02")
        precondition(R.Pair(hook, lever) == R.Pair(lever, hook))
        precondition(R.Pair(hook, hook) == nil)
        precondition(R.accepts(type: "tmo_rope_hook", marker: "Rope"))
        precondition(R.accepts(type: "tmo_rope_cage", marker: "Rope"))
        precondition(R.accepts(type: "tmo_rope_seesaw_lever", marker: "Rope02"))
        precondition(R.accepts(type: "tmo_rope_scissors_1", marker: "Rope01"))
        precondition(R.accepts(type: "tmo_rope_crossbow_lever", marker: "Rope"))
        precondition(!R.accepts(type: "tmo_rope_hook", marker: "rope"))
        precondition(!R.accepts(type: "tmo_rope_scissors_2", marker: "Cut01"))
        precondition(!R.accepts(type: "tmo_belt_gear", marker: "Rope"))
        precondition(R.tension(distance: 1, restLength: 1) == 0)
        precondition(R.tension(distance: 0.5, restLength: 1) == 0)
        precondition(abs(R.tension(distance: 1.1, restLength: 1) - 3.5) < 0.00001)
        precondition(R.tension(distance: 4, restLength: 1) == 25)
        precondition(R.tension(distance: .nan, restLength: 1) == 0)
        precondition(R.tension(distance: 1, restLength: 0) == 0)
        let ropeStart = SIMD3<Float>(0, 0, 0)
        let ropeEnd = SIMD3<Float>(1, 0, 0)
        func cut(_ x: Float, _ depth: Float = 0) -> Bool {
            R.intersectsScissors(ropeStart: ropeStart, ropeEnd: ropeEnd,
                bladeStart: .init(x, -0.2, depth), bladeEnd: .init(x, 0.2, depth))
        }
        precondition(cut(0.5))
        precondition(cut(0.525))
        precondition(cut(0.5, 0.04))
        precondition(!cut(0.5, 0.051))
        precondition(!cut(1.2))
        precondition(!cut(.nan))
        precondition(!R.intersectsScissors(ropeStart: ropeStart, ropeEnd: ropeStart,
            bladeStart: .init(0, -1, 0), bladeEnd: .init(0, 1, 0)))
        typealias B = CMOriginalDriveBelt
        precondition(B.Pair("a", "b") == B.Pair("b", "a"))
        precondition(B.Pair("a", "a") == nil)
        precondition(B.accepts(type: "tmo_power_generator_rotor"))
        precondition(!B.accepts(type: "tmo_windmill_wings"))
        func beltTorque(_ a: Float, _ b: Float) -> B.Torque? {
            B.correction(firstSpeed: a, secondSpeed: b, firstVALF: 0.125, secondVALF: 0.1)
        }
        precondition(beltTorque(0, 0) == nil)
        precondition(beltTorque(2, 2.5) == nil)
        precondition(beltTorque(2, 0)!.first < 0 && beltTorque(2, 0)!.second > 0)
        precondition(beltTorque(-2, 0)!.first > 0 && beltTorque(-2, 0)!.second < 0)
        precondition(beltTorque(.nan, 0) == nil)
        precondition(B.tangentNormals(dx: 0.2, dy: 0, dz: 0,
            firstRadius: 0.125, secondRadius: 0.1) == nil)
        precondition(B.tangentNormals(dx: 1, dy: 0, dz: 0.1,
            firstRadius: 0.125, secondRadius: 0.1) == nil)
        let normals = B.tangentNormals(dx: 1, dy: 0, dz: 0,
            firstRadius: 0.125, secondRadius: 0.1)!
        for n in [normals.0, normals.1] {
            precondition(abs(n.x*n.x + n.y*n.y - 1) < 0.00001)
            let tangent = SIMD2<Float>(1, 0) + n * (0.1 - 0.125)
            precondition(abs(n.x*tangent.x + n.y*tangent.y) < 0.00001)
        }
        for i in -80...80 {
            for j in -80...80 {
                let a = Float(i), b = Float(j)
                if let t = beltTorque(a, b) {
                    precondition(t.first*a + t.second*b <= 0.0001)
                    precondition(abs(t.first) <= 1 && abs(t.second) <= 0.80001)
                }
            }
        }
        typealias Grill = CMOriginalGrillDrive
        typealias Hammer = CMOriginalHammerDrive
        precondition(Grill.phase(previous: 0, wheelSpeed: 2, delta: 0.25) == -0.5)
        precondition(Grill.phase(previous: 0, wheelSpeed: -2, delta: 0.25) == 0.5)
        precondition(Grill.phase(previous: 1, wheelSpeed: 0, delta: 0.1) == 1)
        precondition(Grill.phase(previous: 0, wheelSpeed: .nan, delta: 0.1) == nil)
        precondition(Grill.phase(previous: 0, wheelSpeed: 2, delta: 0.26) == nil)
        for v in -80...80 {
            var phase: Float = 0
            for _ in 0..<100 {
                phase = Grill.phase(previous: phase, wheelSpeed: Float(v), delta: 0.25)!
                precondition(phase.isFinite && abs(phase) < 2 * .pi)
            }
        }
        precondition(Hammer.lift(angle: 0, wheelSignal: -2, direction: 1, step: 0.5)?.angle == 0.5)
        precondition(Hammer.lift(angle: 0, wheelSignal: -2, direction: -1, step: 0.5)?.angle == -0.5)
        precondition(Hammer.lift(angle: Hammer.liftLimit.nextDown, wheelSignal: 0, direction: 1, step: 0)?.releases == false)
        precondition(Hammer.lift(angle: Hammer.liftLimit, wheelSignal: 0, direction: 1, step: 0)?.releases == true)
        precondition(Hammer.lift(angle: -Hammer.liftLimit, wheelSignal: 0, direction: -1, step: 0)?.releases == true)
        precondition(Hammer.lift(angle: 0, wheelSignal: 2, direction: 0, step: 0.5) == nil)
        precondition(Hammer.release(angle: Hammer.liftLimit, direction: 1, step: 0.25) == 0)
        precondition(Hammer.release(angle: -Hammer.liftLimit, direction: -1, step: 0.25) == 0)
        precondition(Hammer.strike(nailY: 0, observedGap: Hammer.strikeGap.nextDown) == nil)
        precondition(Hammer.strike(nailY: 0, observedGap: Hammer.strikeGap)?.nailY == -Hammer.strikeGap)
        var nail: Float = -0.01017
        for _ in 0..<6 {
            let hit = Hammer.strike(nailY: nail, observedGap: Hammer.strikeGap)!
            precondition(!hit.terminal)
            nail = hit.nailY
        }
        let last = Hammer.strike(nailY: nail, observedGap: Hammer.strikeGap)!
        precondition(last.terminal && last.nailY == Hammer.nailLimit)
        // Real UCM Nail marker coordinates and common original CML
        // hammer assembly POSREL, from levels 9, 19 and 101. This
        // exercises the bridge geometry without claiming SceneKit parity.
        precondition(abs(Hammer.correctedAngle(angle: 0, direction: 1,
            gap: 0.5, scale: 1)! - Float.pi / 6) < 0.00001)
        precondition(abs(Hammer.correctedAngle(angle: 0, direction: -1,
            gap: 0.5, scale: 1)! + Float.pi / 6) < 0.00001)
        precondition(Hammer.correctedAngle(angle: 0, direction: 1,
            gap: 1.01, scale: 1) == nil)
        precondition(Hammer.correctedAngle(angle: 0, direction: 1,
            gap: 0, scale: 0) == nil)
        let armX: Float = 0.607897937297821
        let armY: Float = -0.11681382358074188
        let armRadius = hypot(armX, armY)
        for step in [1.0/120, 1.0/60, 1.0/30] {
            for speed in [Float(0.5), 1, 2, 5, 10, 20, 40, 80, -0.5, -2, -10, -80] {
                var angle: Float = 0.1, nailY: Float = -0.01017
                var releasing = false, finished = false, hits = 0
                for _ in 0..<200_000 {
                    if finished { break }
                    if !releasing {
                        let lift = Hammer.lift(angle: angle, wheelSignal: speed,
                            direction: 1, step: step)!
                        angle = lift.angle
                        releasing = lift.releases
                    } else {
                        angle = max(-Hammer.liftLimit, Hammer.release(
                            angle: angle, direction: 1, step: step)!)
                        let tip = 0.22990 + armX*sin(angle) + armY*cos(angle)
                        let head = nailY + 0.18134614825248718
                        let gap = head - tip
                        if let hit = Hammer.strike(nailY: nailY, observedGap: gap),
                           let corrected = Hammer.correctedAngle(angle: angle,
                            direction: 1, gap: gap, scale: armRadius) {
                            angle = corrected
                            nailY = hit.nailY
                            finished = hit.terminal
                            releasing = false
                            hits += 1
                        }
                    }
                }
                precondition(finished && hits == 7 && nailY == Hammer.nailLimit)
            }
        }
        typealias Heat = CMOriginalGrillHeat
        let cold = Heat.State()
        for rate in [30,60,120] {
            for speed: Float in [-5,-1,1,5] {
                for fraction: Float in [0.25,0.5,1] {
                    var state = cold
                    for _ in 0..<(rate*45) {
                        state = Heat.advance(state, fraction: fraction,
                            spitSignal: speed, delta: 1/Double(rate))!
                    }
                    precondition(state.completed && state.shade == 1)
                }
            }
            for speed: Float in [-0.99,0,0.99] {
                var state = cold
                for _ in 0..<(rate*45) {
                    state = Heat.advance(state, fraction: 1,
                        spitSignal: speed, delta: 1/Double(rate))!
                }
                precondition(!state.completed && state.shade < 0.75)
            }
        }
        precondition(Heat.advance(cold, fraction: 0, spitSignal: 5, delta: 0.25)!.heat == 0)
        precondition(Heat.advance(cold, fraction: .nan, spitSignal: 5, delta: 0.25) == nil)
        for i in 0..<1000 {
            let input = Float(i - 500) * 0.005
            let next = M.transmittedSignal(sourceSignal: input,
                sourceVALF: 0.125, targetVALF: 0.1)!
            precondition(next.isFinite)
            let old = M.decayedSignal(previous: input,
                observedNativeStep: 0.25)!
            precondition(abs(old) <= abs(input) + 0.00001)
        }
        print("Native mechanical VALF ratios, linked sign, observed stop decay: 1000 cases passed")
    }
}
