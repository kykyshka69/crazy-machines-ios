import Foundation

@main
struct OriginalWindowsWindRegionSmoke {
    static func main() {
        typealias W = CMOriginalWindowsWindRegion
        let p = W.Parameters(nativeAxis: .init(1, 0),
            minRadiusSquared: 1, maxRadiusSquared: 100,
            radialFalloff: 0.01, maximumAngle: .pi / 2,
            angularFalloff: 2 / .pi)
        func equals(_ actual: Float?, _ expected: Float) -> Bool {
            guard let actual else { return false }
            return abs(actual - expected) < 0.00005
        }
        precondition(equals(W.measuredFraction(
            nativeDisplacement: .init(1, 0), region: p), 1))
        precondition(equals(W.measuredFraction(
            nativeDisplacement: .init(5, 0), region: p), 0.76))
        precondition(equals(W.measuredFraction(
            nativeDisplacement: .init(-5, 0), region: p), 0))
        precondition(equals(W.measuredFraction(
            nativeDisplacement: .init(11, 0), region: p), 0))
        precondition(equals(W.measuredFraction(
            nativeDisplacement: .init(0.5, 0), region: p), 0))
        let diagonal = W.measuredFraction(
            nativeDisplacement: .init(3, 4), region: p)
        precondition(diagonal != nil && diagonal! > 0 && diagonal! < 0.76)
        precondition(W.measuredFraction(
            nativeDisplacement: .init(0, 0), region: p) == nil)
        let noAxis = W.Parameters(nativeAxis: .init(0, 0),
            minRadiusSquared: 1, maxRadiusSquared: 100,
            radialFalloff: 0.01, maximumAngle: .pi / 2,
            angularFalloff: 2 / .pi)
        precondition(W.measuredFraction(
            nativeDisplacement: .init(5, 0), region: noAxis) == nil)
        precondition(W.measuredFraction(
            nativeDisplacement: .init(.nan, 0), region: p) == nil)
        for i in 1...400 {
            let v = W.Vector3(Float(i) * 0.03, Float(i % 20) * 0.14)
            guard let output = W.measuredFraction(
                nativeDisplacement: v, region: p) else {
                preconditionFailure("valid observed region must be measurable")
            }
            precondition(output.isFinite && output >= 0 && output <= 1)
        }
        print("Native wind region: squared distance, angular falloff, 400 bounded cases OK")
    }
}
