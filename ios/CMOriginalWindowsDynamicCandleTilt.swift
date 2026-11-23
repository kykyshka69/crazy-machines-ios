import Foundation

/// The original CrazyMachines.exe 0x44DAA8..0x44DB29 treats ACTIVE
/// tmo_candle_dyn separately from tmo_candle. It normalizes its native
/// selector-3 region direction (+0x30 via 0x45A07B), compares world Y
/// STRICTLY against original Float32 -0.8 (0x4EDDEC), then enters the
/// real source-toggle function at 0x4348F0 when inverted.
/// The imported UCM Heat +Z approximates the native region direction
/// in SceneKit, but true native +0x30 is not yet independently observed.
public enum CMOriginalWindowsDynamicCandleTilt {
    public static let nativeDownwardThreshold = Float(bitPattern: 0xBF4CCCCD)

    /// Nil represents unusable measurements, never inferred candle state.
    public static func shouldExtinguish(
        observedDirectionX x: Float,
        observedDirectionY y: Float,
        observedDirectionZ z: Float
    ) -> Bool? {
        guard x.isFinite, y.isFinite, z.isFinite else { return nil }
        let dx = Double(x), dy = Double(y), dz = Double(z)
        let length = (dx * dx + dy * dy + dz * dz).squareRoot()
        guard length.isFinite, length > 0 else { return nil }
        let normalizedY = dy / length
        guard normalizedY.isFinite else { return nil }
        return normalizedY < Double(nativeDownwardThreshold)
    }
}
