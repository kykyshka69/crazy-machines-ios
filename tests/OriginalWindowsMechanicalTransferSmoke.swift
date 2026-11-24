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
        precondition(R.accepts(type: "tmo_balloon", marker: "Rope"))
        precondition(!R.accepts(type: "tmo_balloon", marker: "Wind"))
        precondition(!R.accepts(type: "tmo_balloon", marker: "Explode"))
        let balloon = R.Endpoint(objectID: "balloon", marker: "Rope")
        let otherBalloon = R.Endpoint(objectID: "balloon-2", marker: "Rope")
        let firstLink = R.Pair(hook, balloon)!
        let secondLink = R.Pair(lever, otherBalloon)!
        let unrelated = R.Pair(hook, lever)!
        let editorLinks: Set<R.Pair> = [firstLink, secondLink, unrelated]
        let retired = R.incidentPairs(in: editorLinks, retiredOwners: ["balloon"])
        precondition(retired == [firstLink])
        precondition(editorLinks.subtracting(retired) == [secondLink, unrelated])
        precondition(editorLinks.count == 3)
        precondition(R.incidentPairs(in: editorLinks, retiredOwners: []) == [])
        precondition(R.incidentPairs(in: editorLinks, retiredOwners: ["missing"]) == [])
        precondition(R.incidentPairs(in: editorLinks, retiredOwners: ["balloon", "balloon-2"]) == [firstLink, secondLink])
        precondition(R.incidentPairs(in: editorLinks, retiredOwners: ["hook"]) == [firstLink, unrelated])
        precondition(R.incidentPairs(in: editorLinks.subtracting(retired), retiredOwners: ["balloon"]) == [])

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
        let savedTypes = ["hook":"tmo_rope_hook", "balloon":"tmo_balloon",
            "lever":"tmo_rope_seesaw_lever", "wheel1":"tmo_belt_gear", "wheel2":"tmo_hammer_wheel"]
        let savedRope = CMOriginalRope.Pair(.init(objectID:"hook",marker:"Rope"),
            .init(objectID:"balloon",marker:"Rope"))!
        let conflictingRope = CMOriginalRope.Pair(.init(objectID:"lever",marker:"Rope01"),
            .init(objectID:"balloon",marker:"Rope"))!
        let savedBelt = CMOriginalDriveBelt.Pair("wheel1","wheel2")!
        let hash = String(repeating:"a",count:64)
        let snapshot = try! CMOriginalMechanicalSnapshot.encode(
            .init(ropes:[savedRope],belts:[savedBelt]),sceneSHA256:hash)
        let restored = CMOriginalMechanicalSnapshot.decode(snapshot,sceneSHA256:hash,
            objectTypes:savedTypes)!
        precondition(restored.ropes == [savedRope] && restored.belts == [savedBelt])
        let conflict = try! CMOriginalMechanicalSnapshot.encode(
            .init(ropes:[savedRope,conflictingRope],belts:[savedBelt]),sceneSHA256:hash)
        precondition(CMOriginalMechanicalSnapshot.decode(conflict,sceneSHA256:hash,objectTypes:savedTypes) == nil)
        precondition(CMOriginalMechanicalSnapshot.decode(snapshot,sceneSHA256:"other",objectTypes:savedTypes) == nil)
        precondition(CMOriginalMechanicalSnapshot.decode(snapshot,sceneSHA256:hash,objectTypes:[:]) == nil)
        precondition(CMOriginalMechanicalSnapshot.decode(Data(repeating:0,count:64001),sceneSHA256:hash,objectTypes:savedTypes) == nil)
        precondition(CMOriginalMechanicalSnapshot.decode(Data("{}".utf8),sceneSHA256:hash,objectTypes:savedTypes) == nil)
        var payload = try! JSONSerialization.jsonObject(with:snapshot) as! [String:Any]
        payload["version"] = 2
        let badVersion = try! JSONSerialization.data(withJSONObject:payload)
        precondition(CMOriginalMechanicalSnapshot.decode(badVersion,sceneSHA256:hash,objectTypes:savedTypes) == nil)
        let originalRadii: [Float] = [0.1,0.125,0.13,0.25]
        func contourLength(_ v: SIMD3<Float>) -> Float {
            sqrt(v.x*v.x+v.y*v.y+v.z*v.z)
        }
        for ra in originalRadii {
            for rb in originalRadii {
                for i in 0..<32 {
                    let theta = Float(i) * .pi / 16
                    for gap: Float in [0.01,0.5,2] {
                        let d = ra+rb+gap
                        let offset = SIMD3<Float>(cos(theta)*d,sin(theta)*d,0.025)
                        let loop = CMOriginalDriveBelt.contour(offset:offset,firstRadius:ra,secondRadius:rb)!
                        precondition(loop.count == CMOriginalDriveBelt.contourSpanCount)
                        for j in loop.indices {
                            precondition(loop[j].end == loop[(j+1)%loop.count].start)
                            precondition(contourLength(loop[j].end-loop[j].start) > 0)
                            if (1...12).contains(j) {
                                precondition(abs(contourLength(loop[j].start-offset)-rb)<0.00001)
                                precondition(abs(contourLength(loop[j].end-offset)-rb)<0.00001)
                            }
                            if (14...25).contains(j) {
                                precondition(abs(contourLength(loop[j].start)-ra)<0.00001)
                                precondition(abs(contourLength(loop[j].end)-ra)<0.00001)
                            }
                        }
                        let v = loop[0].end-loop[0].start
                        precondition(abs(v.x*loop[0].start.x+v.y*loop[0].start.y)<0.00001)
                    }
                }
            }
        }
        precondition(CMOriginalDriveBelt.contour(offset:.zero,firstRadius:0.1,secondRadius:0.2)==nil)
        precondition(CMOriginalDriveBelt.contour(offset:.init(1,0,0.1),firstRadius:0.1,secondRadius:0.2)==nil)
        precondition(CMOriginalDriveBelt.contour(offset:.init(.nan,0,0),firstRadius:0.1,secondRadius:0.2)==nil)
        let axleTypes = ["tmo_belt_gear","tmo_power_motor_rotor","tmo_power_generator_rotor",
            "tmo_belt_conveyer_wheel","tmo_power_disrupter_wheel","tmo_steam_wheel",
            "tmo_windmill_wheel","tmo_hammer_wheel","tmo_belt_flag_wheel","tmo_heat_grill_wheel"]
        for type in axleTypes {
            precondition(CMOriginalDriveBelt.wheelAxisColumn(type:type)
                == (type == "tmo_power_generator_rotor" ? 1 : 2))
        }
        precondition(CMOriginalDriveBelt.wheelAxisColumn(type:"tmo_board") == nil)
        for angle in 0...180 {
            let a = Float(angle) * .pi / 180
            for scale: Float in [0.1,1,5] {
                let axis = SIMD3<Float>(sin(a)*scale,0,cos(a)*scale)
                precondition(CMOriginalDriveBelt.planarAxle(axis) == (abs(cos(a)) >= 0.995))
                for speed: Float in [-20,0,20] {
                    precondition(abs(CMOriginalDriveBelt.planarAngularSpeed(
                        axis:axis,magnitude:speed)! - speed*cos(a)) < 0.00001)
                }
            }
        }
        precondition(!CMOriginalDriveBelt.planarAxle(.zero))
        precondition(!CMOriginalDriveBelt.planarAxle(.init(.nan,0,1)))
        precondition(CMOriginalDriveBelt.planarAngularSpeed(axis:.zero,magnitude:1) == nil)
        precondition(CMOriginalDriveBelt.planarAngularSpeed(axis:.zero,magnitude:0) == 0)
        precondition(CMOriginalDriveBelt.planarAngularSpeed(axis:.init(1,0,0),magnitude:2) == 0)
        precondition(CMOriginalDriveBelt.planarAngularSpeed(axis:.init(0,0,1),magnitude:.infinity) == nil)
        // Original spring adapter: incoming motion and authentic marker
        // frame, no generic launch from a contact with the mounting base.
        for degree in 0..<360 {
            let angle = Float(degree) * .pi/180
            let axis = SIMD3<Float>(cos(angle),sin(angle),0)
            let tangent = SIMD3<Float>(-axis.y,axis.x,0)
            for speed: Float in [0.1,0.5,1,2,4,5,10,20] {
                let incoming = -axis*speed+tangent*0.5
                let current = tangent*0.25
                let result = CMOriginalSpringContact.rebound(incoming:incoming,
                    current:current,axis:axis*2,contact:axis*0.1,marker:.zero)!
                precondition(abs(result.x*axis.x+result.y*axis.y-min(8,1.6*speed))<0.00001)
                precondition(abs(result.x*tangent.x+result.y*tangent.y-0.25)<0.00001)
                precondition(result.z == 0)
                precondition(CMOriginalSpringContact.rebound(incoming:incoming,
                    current:current,axis:axis,contact:-axis*0.1,marker:.zero)==nil)
                precondition(CMOriginalSpringContact.rebound(incoming:axis*speed,
                    current:current,axis:axis,contact:axis*0.1,marker:.zero)==nil)
            }
        }
        // A housing contact must not consume the pair before a later
        // callback reaches the real spring surface.
        var delayedSpringGate = CMOriginalSpringContact.Gate()
        let delayedPair = CMOriginalSpringContact.Pair(spring:"spring",striker:"crate")
        for (point, expected) in [(SIMD3<Float>(0,-0.1,0),false),
                                  (SIMD3<Float>(0,0.02,0),true),
                                  (SIMD3<Float>(0,0.02,0),false)] {
            let valid = CMOriginalSpringContact.rebound(incoming:.init(0,-1,0),
                current:.zero,axis:.init(0,1,0),contact:point,marker:.zero) != nil
            let accepted = valid && delayedSpringGate.accept(delayedPair)
            precondition(accepted == expected)
        }
        delayedSpringGate.end(delayedPair)
        precondition(delayedSpringGate.accept(delayedPair))
        var springGate = CMOriginalSpringContact.Gate()
        let springA = CMOriginalSpringContact.Pair(spring:"spring",striker:"crate-a")
        let springB = CMOriginalSpringContact.Pair(spring:"spring",striker:"crate-b")
        precondition(springGate.accept(springA))
        precondition(!springGate.accept(springA))
        precondition(springGate.accept(springB))
        springGate.end(springA)
        precondition(springGate.accept(springA))
        precondition(!springGate.accept(springB))
        precondition(!springGate.accept(.init(spring:"spring",striker:"spring")))
        precondition(CMOriginalSpringContact.rebound(incoming:.init(0,-1,0),
            current:.init(0,2,0),axis:.init(0,1,0),contact:.zero,marker:.zero)==nil)
        precondition(CMOriginalSpringContact.rebound(incoming:.init(0,-1,0),
            current:.zero,axis:.zero,contact:.zero,marker:.zero)==nil)
        precondition(CMOriginalSpringContact.rebound(incoming:.init(.nan,-1,0),
            current:.zero,axis:.init(0,1,0),contact:.zero,marker:.zero)==nil)
        // Native spring morph: half-sine pulse, exact terminal reset.
        for fps in [30,60,120,240,1000] {
            var animation = CMOriginalSpringContact.Animation()
            precondition(animation.advance(delta: 1/Double(fps)) == nil)
            animation.trigger()
            for i in 1...Int(ceil(Double(Float.pi)/30*Double(fps))) {
                let phase = Double(i)/Double(fps)*30
                let expected: Float = phase >= Double(Float.pi) ? 0 : Float(max(0,sin(phase)*0.5))
                precondition(abs(animation.advance(delta:1/Double(fps))! - expected)<1e-6)
            }
            precondition(animation.elapsed == nil)
            precondition(animation.advance(delta:0.01) == nil)
            animation.trigger()
            precondition(animation.advance(delta:0) == 0)
            precondition(animation.advance(delta:Double.pi/60) == 0.5)
            for bad in [-1.0, .nan, .infinity, 0.251] {
                precondition(animation.advance(delta:bad) == nil)
            }
            animation.trigger()
            precondition(animation.advance(delta:0.25) == 0)
            precondition(animation.elapsed == nil)
        }
        let driveTypes = ["g":"tmo_power_generator_rotor", "G":"tmo_power_generator",
            "g2":"tmo_power_generator_rotor", "G2":"tmo_power_generator",
            "m":"tmo_power_motor_rotor", "M":"tmo_power_motor",
            "a":"tmo_belt_gear", "b":"tmo_belt_gear",
            "w":"tmo_windmill_wheel", "W":"tmo_windmill",
            "s":"tmo_steam_wheel", "S":"tmo_steam_machine", "B":"tmo_boiler",
            "x":"tmo_hammer_wheel", "X":"tmo_hammer"]
        let driveParents = ["g":"G", "g2":"G2", "m":"M", "w":"W", "s":"S", "x":"X"]
        func solveDrive(_ edges: [(String,String)], _ steam: [String:String] = [:]) -> [String:String] {
            CMOriginalDriveBelt.generatorDrivers(
                links: Set(edges.compactMap { CMOriginalDriveBelt.Pair($0.0,$0.1) }),
                types: driveTypes, parentOwners: driveParents, steamBoilers: steam)
        }
        precondition(solveDrive([("m","g")]) == ["G":"M"])
        precondition(solveDrive([("m","a"),("a","b"),("b","g")]) == ["G":"M"])
        precondition(solveDrive([("w","a"),("a","g")]) == ["G":"W"])
        precondition(solveDrive([("s","a"),("a","g")], ["S":"B"]) == ["G":"B"])
        precondition(solveDrive([("s","a"),("a","g")]).isEmpty)
        precondition(solveDrive([("m","a"),("a","g"),("a","w")]).isEmpty)
        precondition(solveDrive([("m","a"),("a","g"),("a","g2")]).isEmpty)
        precondition(solveDrive([("m","a"),("a","g"),("a","b"),("b","m")]).isEmpty)
        precondition(solveDrive([("m","a"),("b","g")]).isEmpty)
        precondition(solveDrive([("m","a"),("a","g"),("a","x")]).isEmpty)
        precondition(solveDrive([("m","g"),("w","g2")]) == ["G":"M","G2":"W"])
        print("Native mechanical VALF ratios, linked sign, observed stop decay: 1000 cases passed")
    }
}
