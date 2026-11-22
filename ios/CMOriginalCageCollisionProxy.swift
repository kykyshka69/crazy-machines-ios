import Foundation

/// Real rope_cage.UCM in the owner's original PC resources is an OPEN
/// tapered cage with a small upper rim and a separate decorative handle.
/// Its measured bounds are approximately X/Z ±0.32006, Y -0.20068..0.43542.
/// A SceneKit convex hull over its UCM geometry makes the entire opening
/// a solid lid, and the imported ball can never reach the original
/// to_dummy_bounding Catch/Test marker. This is a measured but PROVISIONAL
/// collision adapter, not the native Windows collision mesh or solver.
///
/// The bottom and two slanted walls use original mesh bounds; no flat roof
/// or helper triangle is ever put into the physical collision shape.
enum CMOriginalCageCollisionProxy {
    struct Panel {
        let center: [Float]  // local original UCM coordinates, XYZ
        let size: [Float]    // X width, Y height, Z depth of SCNBox
        let rotationZ: Float
    }

    static func panels(low: [Float], high: [Float]) -> [Panel]? {
        guard low.count == 3, high.count == 3,
              low.allSatisfy(\.isFinite),
              high.allSatisfy(\.isFinite),
              zip(low, high).allSatisfy({ $0.1 > $0.0 }) else {
            return nil
        }
        let width = high[0] - low[0]
        let height = high[1] - low[1]
        let depth = high[2] - low[2]
        guard width >= 0.04 && width <= 10,
              height >= 0.04 && height <= 10,
              depth >= 0.04 && depth <= 10 else { return nil }

        // For the authentic rope_cage.UCM, vertices at the lower rim
        // (Y≈-0.17) span X≈±0.30, while the mouth at Y≈0.27
        // spans X≈±0.10. Vertices up to Y≈0.435 belong to the
        // handle; treating them as a closed lid is incorrect.
        let leftX = low[0], rightX = high[0]
        let centerX = (leftX + rightX) * 0.5
        let centerZ = (low[2] + high[2]) * 0.5
        let footY = low[1] + height * 0.045
        let mouthY = low[1] + height * 0.75
        let bottomHalfSpan = width * 0.46
        let mouthHalfSpan = width * 0.155
        let wallThickness = width * 0.068
        let floorThickness = height * 0.065
        let wallDY = mouthY - footY
        let wallDX = bottomHalfSpan - mouthHalfSpan
        let slantLength = hypot(wallDY, wallDX)
        let angle = atan2(wallDX, wallDY)
        let wallX = (bottomHalfSpan + mouthHalfSpan) * 0.5
        let sideCenterY = (footY + mouthY) * 0.5
        let cageDepth = depth * 0.92
        guard [wallThickness, floorThickness, slantLength,
               wallX, cageDepth, sideCenterY, angle]
                .allSatisfy(\.isFinite),
              wallThickness > 0, floorThickness > 0,
              slantLength > 0, cageDepth > 0 else { return nil }

        return [
            Panel(
                center: [centerX, footY, centerZ],
                size: [bottomHalfSpan * 2, floorThickness, cageDepth],
                rotationZ: 0
            ),
            Panel(
                center: [centerX - wallX, sideCenterY, centerZ],
                size: [wallThickness, slantLength, cageDepth],
                rotationZ: -angle
            ),
            Panel(
                center: [centerX + wallX, sideCenterY, centerZ],
                size: [wallThickness, slantLength, cageDepth],
                rotationZ: angle
            )
        ]
    }
}
