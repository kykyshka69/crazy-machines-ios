import Foundation

/// Bounds-only proxy geometry for the experimental SceneKit collision layer.
/// The imported UCM mesh stays authoritative for rendering. A centered
/// SCNSphere/SCNBox must be translated to the visual mesh's local bounds
/// midpoint before its owner transforms are applied; not every original UCM
/// puts its geometry center at (0, 0, 0).
enum CMOriginalCollisionProxy {
    struct Sphere {
        let center: [Float]
        let radius: Float
    }

    struct Zone {
        let center: [Float]
        let width: Float
        let height: Float
        let depth: Float
    }

    private static func box(low: [Float], high: [Float])
        -> (center: [Float], size: [Float])? {
        guard low.count == 3, high.count == 3,
              low.allSatisfy(\.isFinite), high.allSatisfy(\.isFinite) else {
            return nil
        }
        var center: [Float] = []
        var size: [Float] = []
        for i in 0..<3 {
            guard high[i] >= low[i] else { return nil }
            // This subtracts from low rather than adding both bounds,
            // avoiding overflow when the original vertices are large.
            let span = high[i] - low[i]
            guard span.isFinite else { return nil }
            let midpoint = low[i] + span * 0.5
            guard midpoint.isFinite else { return nil }
            center.append(midpoint)
            size.append(span)
        }
        return (center, size)
    }

    /// Use a sphere only for nearly equal X/Y/Z spans; non-round PC models
    /// continue to use their genuine UCM convex hull.
    static func ball(low: [Float], high: [Float]) -> Sphere? {
        guard let bounds = box(low: low, high: high) else { return nil }
        let diameter = bounds.size.max() ?? 0
        let smallest = bounds.size.min() ?? 0
        guard diameter > 0, smallest > diameter * 0.85 else { return nil }
        return Sphere(center: bounds.center, radius: diameter * 0.5)
    }

    /// The PC zone is a flat XY plane. Give its SceneKit contact sensor
    /// a modest Z depth, centered on the original visible mesh bounds.
    static func zone(low: [Float], high: [Float]) -> Zone? {
        guard let bounds = box(low: low, high: high) else { return nil }
        return Zone(center: bounds.center,
                    width: max(0.001, bounds.size[0]),
                    height: max(0.001, bounds.size[1]),
                    depth: 0.6)
    }
}
