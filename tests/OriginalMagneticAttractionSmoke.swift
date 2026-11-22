import Foundation

@main
struct OriginalMagneticAttractionSmoke {
    static func main() {
        precondition(CMOriginalMagneticAttraction.responds("tmo_bucket"))
        precondition(CMOriginalMagneticAttraction.responds("tmo_ball_steel"))
        precondition(!CMOriginalMagneticAttraction.responds("tmo_crate"))
        precondition(!CMOriginalMagneticAttraction.responds("tmo_ball_tennis"))
        let close = CMOriginalMagneticAttraction.force(
            magnetX: 0, magnetY: 0, targetX: 0.5, targetY: 0, mass: 1)!
        let far = CMOriginalMagneticAttraction.force(
            magnetX: 0, magnetY: 0, targetX: 2.5, targetY: 0, mass: 1)!
        precondition(close.x < far.x && far.x < 0 && close.y == 0)
        let doubleMass = CMOriginalMagneticAttraction.force(
            magnetX: 0, magnetY: 0, targetX: 0.5, targetY: 0, mass: 2)!
        precondition(abs(doubleMass.x - 2 * close.x) < 0.001)
        precondition(CMOriginalMagneticAttraction.force(
            magnetX: 0, magnetY: 0, targetX: 4, targetY: 0, mass: 1) == nil)
        precondition(CMOriginalMagneticAttraction.force(
            magnetX: 0, magnetY: 0, targetX: 0, targetY: 0, mass: 1) == nil)
        precondition(CMOriginalMagneticAttraction.force(
            magnetX: .nan, magnetY: 0, targetX: 1, targetY: 0, mass: 1) == nil)
        precondition(CMOriginalMagneticAttraction.force(
            magnetX: 0, magnetY: 0, targetX: 1, targetY: 0, mass: 0) == nil)
        // The one-source prototype remains unchanged when the total force
        // is below the stability cap.
        let single = CMOriginalMagneticAttraction.combinedForce(
            magnets: [(x: 0, y: 0)], targetX: 0.5, targetY: 0, mass: 1)!
        precondition(abs(single.x - close.x) < 0.0001 && single.y == close.y)
        // Symmetric magnets cancel instead of applying opposing impulses
        // separately to the physics engine.
        precondition(CMOriginalMagneticAttraction.combinedForce(
            magnets: [(x: -1, y: 0), (x: 1, y: 0)],
            targetX: 0, targetY: 0, mass: 1) == nil)
        // Authentic level 58 contains eleven magnets and one metal bucket.
        // Parallel fields must never exceed 12 m/s² of net acceleration.
        let eleven = Array(repeating: (x: Float(0), y: Float(0)), count: 11)
        let capped = CMOriginalMagneticAttraction.combinedForce(
            magnets: eleven, targetX: 0.5, targetY: 0, mass: 2)!
        precondition(capped.x < 0 && abs(capped.x + 24) < 0.001)
        precondition(abs(capped.y) < 0.001)
        // Independent perpendicular forces must be limited by their
        // vector magnitude, not independently clamped per axis.
        let diagonal = CMOriginalMagneticAttraction.combinedForce(
            magnets: Array(repeating: (x: Float(0), y: Float(0)), count: 11),
            targetX: 0.5, targetY: 0.5, mass: 1)!
        precondition(hypot(diagonal.x, diagonal.y) <= 12.001)
        // Invalid or out-of-range magnets contribute no force. No sources
        // also means no force; invalid mass cannot enter SceneKit.
        precondition(CMOriginalMagneticAttraction.combinedForce(
            magnets: [], targetX: 0.5, targetY: 0, mass: 1) == nil)
        precondition(CMOriginalMagneticAttraction.combinedForce(
            magnets: [(x: 4, y: 0), (x: .nan, y: 0)],
            targetX: 0, targetY: 0, mass: 1) == nil)
        precondition(CMOriginalMagneticAttraction.combinedForce(
            magnets: [(x: 0, y: 0)], targetX: 1, targetY: 0, mass: .infinity) == nil)
        print("Optional original magnet field smoke passed")
    }
}
