import Foundation

/// Experimental contact geometry built from the owner's genuine bucket UCM
/// vertex bounds, without putting any PC asset bytes in the public source.
/// The imported to_bucket mesh stays unmodified for rendering.
///
/// The UCM extends to its carrying handle, above the open bucket rim:
/// convex-hulling the entire original mesh falsely seals its opening.
/// Three collision panels preserve an open top and a physical bottom.
enum CMOriginalBucketCollisionProxy {
    struct Panel {
        let center: [Float]
        let size: [Float]
    }

    /// The ball's full UCM cross-section must be inside the hollow bucket,
    /// not merely contacting its exterior walls, handle or rim.
    static func containsBall(
        x: Float, y: Float, radius: Float, panels: [Panel]
    ) -> Bool {
        guard [x, y, radius].allSatisfy(\.isFinite),
              radius > 0, radius < 1,
              panels.count == 3 else { return false }
        let floor = panels[0], left = panels[1], right = panels[2]
        let innerLeft = left.center[0] + left.size[0] * 0.5
        let innerRight = right.center[0] - right.size[0] * 0.5
        let floorTop = floor.center[1] + floor.size[1] * 0.5
        let rimTop = left.center[1] + left.size[1] * 0.5
        let tolerance: Float = 0.004
        return x - radius >= innerLeft - tolerance
            && x + radius <= innerRight + tolerance
            && y - radius >= floorTop - tolerance
            && y + radius <= rimTop + tolerance
    }

    static func panels(low: [Float], high: [Float]) -> [Panel]? {
        guard low.count == 3, high.count == 3,
              low.allSatisfy(\.isFinite), high.allSatisfy(\.isFinite),
              zip(low, high).allSatisfy({ $0.1 > $0.0 }) else {
            return nil
        }
        let spanX = high[0] - low[0]
        let spanY = high[1] - low[1]
        let spanZ = high[2] - low[2]
        guard [spanX, spanY, spanZ].allSatisfy({
            $0.isFinite && $0 >= 0.025 && $0 <= 20
        }) else { return nil }

        // The upper vertex extrema of the authentic to_bucket UCM include
        // the handle (y≈0.375), while its cylindrical rim is near y≈0.17.
        // Ratios are relative to measured imported bounds, not world coords.
        let centerX = low[0] + 0.5 * spanX
        let centerZ = low[2] + 0.5 * spanZ
        let outsideWidth = spanX * 0.82
        let rimY = low[1] + spanY * 0.625
        let wallThickness = outsideWidth * 0.09
        let bottomThickness = spanY * 0.06
        let depth = spanZ * 0.94
        let sideHeight = rimY - low[1] - bottomThickness
        guard sideHeight > 0, depth > 0,
              wallThickness * 2 < outsideWidth else { return nil }
        let sideY = low[1] + bottomThickness + sideHeight * 0.5
        let sideX = outsideWidth * 0.5 - wallThickness * 0.5
        return [
            Panel(center: [centerX, low[1] + bottomThickness * 0.5, centerZ],
                  size: [outsideWidth, bottomThickness, depth]),
            Panel(center: [centerX - sideX, sideY, centerZ],
                  size: [wallThickness, sideHeight, depth]),
            Panel(center: [centerX + sideX, sideY, centerZ],
                  size: [wallThickness, sideHeight, depth])
        ]
    }
}
