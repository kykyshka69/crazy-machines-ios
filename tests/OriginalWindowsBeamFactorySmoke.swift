import Foundation

@main
struct OriginalWindowsBeamFactorySmoke {
    static func main() {
        typealias Original = CMOriginalWindowsBeamFactory
        typealias Beam = CMOriginalWindowsBeamRegion
        let p = Original.pocketlampParameters()!
        let angle = Original.pocketlampHalfAngleDegrees * Original.radiansPerDegree
        let near = abs(tan(Float(90) + angle) * Original.pocketlampNearScale)
        let far = near + Original.pocketlampOuterExtension
        precondition(abs(p.maximumAngle - angle) < 0.000001)
        precondition(abs(p.innerSquaredDistance - near*near) < 0.000001)
        precondition(abs(p.outerSquaredDistance - far*far) < 0.000001)
        precondition(abs(p.distanceFalloff -
            1/(far*far - near*near)) < 0.000001)
        precondition(abs(p.angleFalloff - 1/angle) < 0.000001)
        precondition(Original.pocketlampIntensity == 0.3)
        let origin = Beam.Vector(x: 0, y: 0)
        let forward = Beam.Vector(x: 1, y: 0)
        precondition(Beam.intersect(origin: origin, forward: forward,
            target: .init(x: 1, y: 0), p: p) != nil)
        precondition(Beam.intersect(origin: origin, forward: forward,
            target: .init(x: 0, y: 2), p: p) == nil)
        print("Authentic Win32 pocketlamp emitter: 30°, 0.3 near scale, 1.5 outer extension")
    }
}
