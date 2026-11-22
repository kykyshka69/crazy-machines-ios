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
        print("Optional original magnet field smoke passed")
    }
}
