import Foundation

/// An opt-in approximation; neither field strength nor range has been
/// recovered from the original Windows physics solver.
enum CMOriginalMagneticAttraction {
    static func responds(_ type: String) -> Bool {
        type == "tmo_bucket" || type == "tmo_ball_steel"
    }

    /// World-space XY force on a dynamic metal object near an original magnet.
    static func force(magnetX: Float, magnetY: Float,
                      targetX: Float, targetY: Float,
                      mass: Float) -> (x: Float, y: Float)? {
        guard [magnetX, magnetY, targetX, targetY, mass].allSatisfy({
            $0.isFinite
        }), mass > 0, mass <= 2_000 else { return nil }
        let dx = magnetX - targetX
        let dy = magnetY - targetY
        let squared = dx * dx + dy * dy
        guard squared.isFinite, squared >= 0.015625,
              squared < 9 else { return nil }
        let distance = squared.squareRoot()
        let falloff = 1 - distance / 3
        let forcePerMass = 9 * falloff * falloff
        let scale = mass * forcePerMass / distance
        let x = dx * scale
        let y = dy * scale
        guard x.isFinite, y.isFinite else { return nil }
        return (x, y)
    }
    /// The genuine 102-level pack contains scenes with multiple magnets
    /// (11 permanent magnets and a bucket in Professor level 58). Naively
    /// applying a separate full force for each magnet allows unbounded net
    /// acceleration and can destabilize the experimental SceneKit solver.
    /// Sum all world-space XY forces first, then cap the target's resulting
    /// acceleration. 12 m/s² is a conservative prototype stability limit,
    /// NOT a recovered Windows magnet strength.
    static func combinedForce(
        magnets: [(x: Float, y: Float)],
        targetX: Float, targetY: Float, mass: Float
    ) -> (x: Float, y: Float)? {
        guard targetX.isFinite, targetY.isFinite,
              mass.isFinite, mass > 0, mass <= 2_000 else { return nil }
        var totalX = 0.0
        var totalY = 0.0
        for magnet in magnets {
            guard let part = force(
                magnetX: magnet.x, magnetY: magnet.y,
                targetX: targetX, targetY: targetY, mass: mass
            ) else { continue }
            totalX += Double(part.x)
            totalY += Double(part.y)
        }
        let magnitude = hypot(totalX, totalY)
        guard magnitude.isFinite, magnitude > 0.000001 else { return nil }
        let limit = Double(mass) * 12.0
        let scale = min(1, limit / magnitude)
        let x = Float(totalX * scale)
        let y = Float(totalY * scale)
        guard x.isFinite, y.isFinite else { return nil }
        return (x, y)
    }

}
