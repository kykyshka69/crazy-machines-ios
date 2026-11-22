import Foundation

@main
struct OriginalWindowsBeamRegionSmoke {
    static func main() {
        typealias B = CMOriginalWindowsBeamRegion
        let p = B.Parameters(innerSquaredDistance: 0,
            outerSquaredDistance: 25, distanceFalloff: 1/25,
            maximumAngle: acos(Float(0)), angleFalloff: 2 / .pi)
        let origin = B.Vector(x: 0, y: 0)
        let x = B.Vector(x: 1, y: 0)
        let hit = B.intersect(origin: origin, forward: x, target: x, p: p)
        precondition(hit != nil)
        precondition(abs(hit!.weight - 0.96) < 0.00001)
        precondition(hit!.direction == x && hit!.squaredDistance == 1)
        precondition(hit!.angle == 0)
        // x87 comparisons include equal inner and equal outer bounds.
        precondition(B.intersect(origin: origin, forward: x,
            target: .init(x: 5, y: 0), p: p) != nil)
        precondition(B.intersect(origin: origin, forward: x,
            target: .init(x: 6, y: 0), p: p) == nil)
        // Native angular cutoff is inclusive, after Float acos rounding.
        precondition(B.intersect(origin: origin, forward: x,
            target: .init(x: 0, y: 1), p: p) != nil)
        precondition(B.intersect(origin: origin, forward: x,
            target: .init(x: -1, y: 0), p: p) == nil)
        let edge = B.Parameters(innerSquaredDistance: 1,
            outerSquaredDistance: 25, distanceFalloff: 1/25,
            maximumAngle: .pi, angleFalloff: 0)
        precondition(B.intersect(origin: origin, forward: x,
            target: x, p: edge) != nil)
        precondition(B.intersect(origin: origin, forward: x,
            target: origin, p: p) == nil)
        precondition(B.intersect(origin: origin, forward: origin,
            target: x, p: p) == nil)
        precondition(B.intersect(origin: origin, forward: x,
            target: .init(x: .nan, y: 0), p: p) == nil)
        precondition(abs(B.intersect(origin: origin, forward: x,
            target: .init(x: 3, y: 0), p: p)!.weight - 0.64) < 0.00001)
        print("Real Win32 x87 optical region: inclusive radius and angle, normalized beam, falloff OK")
    }
}
