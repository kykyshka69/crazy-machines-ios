import Foundation

@main
struct OriginalCollisionProxySmoke {
    static func main() {
        func close(_ value: Float, _ expected: Float) -> Bool {
            abs(value - expected) < 0.00001
        }

        // Non-origin UCM geometry: a centered SCNSphere would collide at the
        // wrong place unless its compound-shape matrix adds this local center.
        guard let ball = CMOriginalCollisionProxy.ball(
            low: [-2.0, -3.0, -0.6],
            high: [-1.0, -2.0, 0.4]) else {
            preconditionFailure("Round offset PC ball was rejected")
        }
        precondition(close(ball.radius, 0.5))
        precondition(zip(ball.center, [-1.5, -2.5, -0.1] as [Float]).allSatisfy(close))

        // An offset rectangular zone must use its original mesh center,
        // including the Z plane. The physics sensor alone gets nonzero depth.
        guard let zone = CMOriginalCollisionProxy.zone(
            low: [2.0, 5.0, -1.0],
            high: [6.0, 7.0, -1.0]) else {
            preconditionFailure("Original zero-thickness zone was rejected")
        }
        precondition(zip(zone.center, [4, 6, -1] as [Float]).allSatisfy(close))
        precondition(zone.width == 4 && zone.height == 2 && close(zone.depth, 0.6))

        // Deliberately non-round original objects use their true UCM hull,
        // never a fabricated sphere that extends beyond the visible mesh.
        precondition(CMOriginalCollisionProxy.ball(
            low: [0, 0, 0], high: [2, 1, 1]) == nil)
        precondition(CMOriginalCollisionProxy.ball(
            low: [1, 1, 1], high: [1, 1, 1]) == nil)

        guard let narrowZone = CMOriginalCollisionProxy.zone(
            low: [3, 4, 0], high: [3, 4, 0]) else {
            preconditionFailure("Zero-width original zone should still have a sensor")
        }
        precondition(narrowZone.width == 0.001 && narrowZone.height == 0.001)
        precondition(narrowZone.center == [3, 4, 0])

        // Invalid or overflowing UCM bounds must not reach SceneKit physics.
        let invalid: [([Float], [Float])] = [
            ([1, 0, 0], [0, 1, 1]),
            ([Float.nan, 0, 0], [1, 1, 1]),
            ([0, 0, 0], [1, Float.infinity, 1]),
            ([-Float.greatestFiniteMagnitude, 0, 0],
             [Float.greatestFiniteMagnitude, 1, 1]),
            ([1, 2], [3, 4])
        ]
        for (low, high) in invalid {
            precondition(CMOriginalCollisionProxy.ball(low: low, high: high) == nil)
            precondition(CMOriginalCollisionProxy.zone(low: low, high: high) == nil)
        }
        print("Original PC collision proxy centers and dimensions: OK")
    }
}
