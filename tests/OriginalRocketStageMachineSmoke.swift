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
        print("Real UCM rocket SceneKit playback stages: PASS")
    }
}
