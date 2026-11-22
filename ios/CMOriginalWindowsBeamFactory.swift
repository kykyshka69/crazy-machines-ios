import Foundation

/// The original PC pocketlamp beam construction (not a guessed spotlight).
/// Private SHA-gated Windows executable at 0x4541F7..0x45427C sets
/// beam angle, near scale, outer extent, intensity and location separately.
/// Only native SHAPE is reconstructed here. Source active state and original
/// source/world transform must be independently observed before solar power.
public enum CMOriginalWindowsBeamFactory {
    public static let radiansPerDegree: Float = 0.01745329238474369
    public static let pocketlampHalfAngleDegrees: Float = 30
    public static let pocketlampNearScale: Float = 0.3
    public static let pocketlampOuterExtension: Float = 1.5
    public static let pocketlampIntensity: Float = 0.3

    /// 0x448820: +0x40=degrees*radiansPerDegree, +0x44=1/+0x40
    /// 0x4486B0 -> 0x409860: +0x28=0.3, recompute +0x34
    /// 0x409D70: +0x30=nearDistance+1.5, +0x38=squared outer radius,
    ///            +0x3C=1/(squared outer radius - squared inner radius).
    public static func pocketlampParameters()
        -> CMOriginalWindowsBeamRegion.Parameters? {
        let angle = pocketlampHalfAngleDegrees * radiansPerDegree
        let near = abs(tan(Float(90) + angle) * pocketlampNearScale)
        let innerSquared = near * near
        let far = near + pocketlampOuterExtension
        let outerSquared = far * far
        let spanSquared = outerSquared - innerSquared
        guard angle.isFinite, angle > 0,
              near.isFinite, spanSquared.isFinite,
              spanSquared > 0 else { return nil }
        return CMOriginalWindowsBeamRegion.Parameters(
            innerSquaredDistance: innerSquared,
            outerSquaredDistance: outerSquared,
            distanceFalloff: 1 / spanSquared,
            maximumAngle: angle,
            angleFalloff: 1 / angle
        )
    }
}
