import Foundation

/// Exact original tmo_candle thermal source cone constructor:
/// 0x4545C0 -> 0x4545FE -> 0x431E80 in the owner's SHA-pinned PE32.
/// Its SOURCE cone is attached at region +0x20; the native source
/// coordinate and rotated axis must still be observed separately.
public enum CMOriginalWindowsCandleHeatFactory {
    public static let halfAngleDegrees: Float = 17
    public static let nearScale: Float = 0.2
    public static let outerExtension: Float = 0.8
    public static let nativeSourceIntensity: Float = 1
    public static let radiansPerDegree: Float = 0.01745329238474369

    /// 0x43207A constructs (0,1,0) in the source LOCAL coordinates.
    /// Never treat this as the world axis of a rotated SceneKit candle.
    public static let initialLocalForward =
        CMOriginalWindowsWindRegion.Vector3(0, 1, 0)

    /// 0x432053: 17 degrees -> +0x40 / +0x44 through 0x448820.
    /// 0x432060: 0.2 near scale through 0x4486B0 -> 0x409860.
    /// 0x43206D: 0.8 outer extension through 0x409D70.
    /// Pass the actual NATIVE source axis, in the receiver's reference
    /// frame. Local UCM Heat direction is not sufficient evidence.
    public static func parameters(
        observedNativeAxis: CMOriginalWindowsWindRegion.Vector3
    ) -> CMOriginalWindowsWindRegion.Parameters? {
        guard observedNativeAxis.x.isFinite, observedNativeAxis.y.isFinite,
              Double(observedNativeAxis.x) * Double(observedNativeAxis.x)
                + Double(observedNativeAxis.y) * Double(observedNativeAxis.y) > 0
        else { return nil }
        let radians = halfAngleDegrees * radiansPerDegree
        // Native 0x409860: tan(90 + halfAngleRadians) * nearScale.
        // Retain literal 90 used by this original binary, not pi/2.
        let inner = abs(tan(Float(90) + radians) * nearScale)
        let outer = inner + outerExtension
        let innerSquared = inner * inner
        let outerSquared = outer * outer
        let spanSquared = outerSquared - innerSquared
        guard radians.isFinite, radians > 0,
              inner.isFinite, outer.isFinite,
              spanSquared.isFinite, spanSquared > 0 else { return nil }
        return CMOriginalWindowsWindRegion.Parameters(
            nativeAxis: observedNativeAxis,
            minRadiusSquared: innerSquared,
            maxRadiusSquared: outerSquared,
            radialFalloff: 1 / spanSquared,
            maximumAngle: radians,
            angularFalloff: 1 / radians)
    }
}
