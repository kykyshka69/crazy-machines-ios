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
}
