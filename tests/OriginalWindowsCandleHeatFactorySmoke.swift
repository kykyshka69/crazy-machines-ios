import Foundation

@main struct OriginalWindowsCandleHeatFactorySmoke {
    static func main() {
        typealias F = CMOriginalWindowsCandleHeatFactory
        typealias W = CMOriginalWindowsWindRegion
        let p = F.parameters(observedNativeAxis: .init(0, 1))!
        let angle = F.halfAngleDegrees * F.radiansPerDegree
        let near = abs(tan(Float(90) + angle) * F.nearScale)
        let far = near + F.outerExtension
        precondition(F.nativeSourceIntensity == 1)
        precondition(F.initialLocalForward.x == 0)
        precondition(F.initialLocalForward.y == 1)
        precondition(F.initialLocalForward.z == 0)
        precondition(angle > 0 && angle < 0.3)
        precondition(abs(p.maximumAngle - angle) < 0.000001)
        precondition(abs(p.minRadiusSquared - near*near) < 0.000001)
        precondition(abs(p.maxRadiusSquared - far*far) < 0.000001)
        precondition(abs(p.radialFalloff - 1/(far*far - near*near)) < 0.000001)
        precondition(abs(p.angularFalloff - 1/angle) < 0.000001)
        let cutoff = Float(bitPattern: 0x3f570a3d)
        precondition(W.measuredFraction(
            nativeDisplacement: .init(0, 0.35), region: p)! > cutoff)
        precondition(W.measuredFraction(
            nativeDisplacement: .init(0, 0.6), region: p)! < cutoff)
        precondition(W.measuredFraction(
            nativeDisplacement: .init(0.35, 0), region: p) == 0)
        precondition(F.parameters(observedNativeAxis: .init(0, 0)) == nil)
        precondition(F.parameters(observedNativeAxis: .init(.nan, 1)) == nil)
        precondition(F.parameters(observedNativeAxis: .init(.infinity, 1)) == nil)
        let rotated = F.parameters(observedNativeAxis: .init(1, 0))!
        precondition(W.measuredFraction(
            nativeDisplacement: .init(0.35, 0), region: rotated)! > cutoff)
        print("Owner-original Win32 tmo_candle heat: 17 degrees, near 0.2, outer +0.8 PASS")
    }
}
