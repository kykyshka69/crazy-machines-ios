import Foundation

@main struct OriginalRocketStageMachineSmoke {
    static func main() {
        typealias R = CMOriginalRocketStageMachine
        let cutoff = Float(bitPattern: 0x3F570A3D)
        var rocket = R()
        func tick(_ t: Double, heat: Float? = nil, torch: Bool = false,
                  body: Bool = true, direction: Bool = true) -> R.Phase {
            rocket.advance(time: t, projectedCandleHeat: heat,
                           projectedBlowtorchHit: torch, rocketBodyPresent: body,
                           directionAndInitialVelocityUsable: direction)
        }
        precondition(tick(0, heat: cutoff) == .mounted)
        precondition(tick(0.2, heat: .nan) == .mounted)
        precondition(tick(0.3, heat: 0.85) == .fuse)
        precondition(rocket.ignitionTime == 0.3)
        precondition(tick(3.3) == .fuse)
        precondition(tick(3.4, body: false) == .fuse)
        precondition(tick(3.5, direction: false) == .fuse)
        precondition(tick(3.6) == .flying)
        precondition(rocket.launchTime == 3.6)
        precondition(tick(6.6) == .flying)
        precondition(tick(6.7) == .ended)
        precondition(tick(5.0) == .ended) // backwards clock ignored
        precondition(tick(.nan) == .ended)
        var torchRocket = R()
        precondition(torchRocket.advance(time: 1, projectedCandleHeat: nil,
            projectedBlowtorchHit: true, rocketBodyPresent: true,
            directionAndInitialVelocityUsable: true) == .fuse)
        precondition(torchRocket.advance(time: 4, projectedCandleHeat: nil,
            projectedBlowtorchHit: false, rocketBodyPresent: true,
            directionAndInitialVelocityUsable: true) == .fuse)
        precondition(torchRocket.advance(time: 4.01, projectedCandleHeat: nil,
            projectedBlowtorchHit: false, rocketBodyPresent: true,
            directionAndInitialVelocityUsable: true) == .flying)
        var fake = R()
        precondition(fake.advance(time: 1, projectedCandleHeat: 2,
            projectedBlowtorchHit: false, rocketBodyPresent: true,
            directionAndInitialVelocityUsable: true) == .mounted)
        precondition(fake.advance(time: 2, projectedCandleHeat: .infinity,
            projectedBlowtorchHit: false, rocketBodyPresent: true,
            directionAndInitialVelocityUsable: true) == .mounted)
        // The native terminal handler is a one-shot event, not a
        // per-frame repeat. It does not dispatch synthetic puzzle GOAL.
        var terminal = CMOriginalRocketTerminalGate()
        precondition(!terminal.consume(childID: "rocket-1", phase: .fuse))
        precondition(!terminal.consume(childID: "rocket-1", phase: .flying))
        precondition(!terminal.consume(childID: "", phase: .ended))
        precondition(terminal.consume(childID: "rocket-1", phase: .ended))
        precondition(!terminal.consume(childID: "rocket-1", phase: .ended))
        precondition(terminal.consume(childID: "rocket-2", phase: .ended))
        precondition(!terminal.consume(childID: "rocket-2", phase: .ended))
        func goal(type: String = "tmo_heat_rocket",
                  child: String = "tmo_heat_rocket_rocket",
                  flag: String? = "1",
                  phase: R.Phase = .ended,
                  marker: Bool = true, retired: Bool = true) -> Bool {
            CMOriginalRocketTerminalGate.supportsReconstructedGoal(
                originalParentType: type,
                originalChildType: child,
                originalParentGoal: flag,
                phase: phase,
                genuineOriginalExplodeMarker: marker,
                originalChildPhysicsRetired: retired)
        }
        precondition(goal())
        precondition(goal(flag: " 1 "))
        precondition(!goal(flag: "0"))
        precondition(!goal(flag: nil))
        precondition(!goal(flag: "GOAL"))
        precondition(!goal(type: "tmo_crate"))
        precondition(!goal(child: "tmo_heat_rocket_mount"))
        precondition(!goal(phase: .flying))
        // An original UCM Explode anchor, NOT a successfully loaded
        // optional rocket_effect.tga sprite, is the gameplay requirement.
        precondition(goal(marker: true))
        precondition(!goal(marker: false))
        precondition(!goal(retired: false))
        print("Real UCM rocket terminal cleanup and reconstructed Win32 goal gate: PASS")
    }
}
