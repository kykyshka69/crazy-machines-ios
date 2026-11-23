import Foundation

/// Native Win32 directional heat strip (0x44CC70..0x44CD2D), recovered
/// directly from owner's SHA-pinned CrazyMachines.exe. Both source and
/// receiver positions are native selector-3 +0x24 XY coordinates; the
/// source +0x30 floating-point sign chooses left versus right.
/// This does not establish original effects, rocket state or GOAL.
public enum CMOriginalWindowsBlowtorchHeat {
    public static let halfHeight = Float(bitPattern: 0x3D8F5C29) // 0.07
    public static let horizontalReach = Float(bitPattern: 0x3ECCCCCD) // 0.4

    /// Nil for unknown geometry; false for a geometrically observed miss.
    /// Original x87 bounds: lower Y inclusive, upper Y exclusive;
    /// right-facing X [source, source+0.4), left-facing
    /// X [source-0.4, source]. Use unrounded Double intermediates.
    public static func hits(
        sourceX: Float, sourceY: Float,
        receiverX: Float, receiverY: Float,
        sourceHorizontalDirection: Float
    ) -> Bool? {
        let values = [sourceX, sourceY, receiverX, receiverY,
                      sourceHorizontalDirection]
        guard values.allSatisfy(\.isFinite) else { return nil }
        let sx = Double(sourceX), sy = Double(sourceY)
        let tx = Double(receiverX), ty = Double(receiverY)
        let half = Double(halfHeight), reach = Double(horizontalReach)
        guard ty >= sy - half, ty < sy + half else { return false }
        if sourceHorizontalDirection > 0 {
            return tx >= sx && tx < sx + reach
        }
        return tx >= sx - reach && tx <= sx
    }
}
