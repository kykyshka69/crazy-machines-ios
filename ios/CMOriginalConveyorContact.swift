import Foundation

/// Conveyor traction in the experimental SceneKit engine. All contact
/// coordinates and bounds refer to the actual belt UCM mesh (not its housing).
enum CMOriginalConveyorContact {
    struct Force { let x: Float; let y: Float }

    static func surfaceForce(
        localX: Float, localY: Float,
        beltMinX: Float, beltMaxX: Float, beltTopY: Float,
        wheelAngularSpeed: Float, tangentX: Float, tangentY: Float,
        objectVelocityX: Float, objectVelocityY: Float,
        mass: Float
    ) -> Force? {
        let values = [localX, localY, beltMinX, beltMaxX, beltTopY,
                      wheelAngularSpeed, tangentX, tangentY,
                      objectVelocityX, objectVelocityY, mass]
        guard values.allSatisfy(\.isFinite),
              beltMinX < beltMaxX, mass > 0,
              abs(wheelAngularSpeed) > 0.05 else { return nil }

        // Original belt_conveyor_belt.ucm: X ±0.59072 and upper Y 0.08646.
        // Allow a small contact manifold without accepting the frame/underside.
        guard localX >= beltMinX - 0.06,
              localX <= beltMaxX + 0.06,
              localY >= beltTopY - 0.09,
              localY <= beltTopY + 0.15 else { return nil }

        // Transform the original +X tangent through 3DO ROTREL/SCAL first.
        let tangentLength = hypot(tangentX, tangentY)
        guard tangentLength.isFinite, tangentLength > 0.00001 else { return nil }
        let tx = tangentX / tangentLength
        let ty = tangentY / tangentLength
        let beltSpeed = max(-2.0, min(2.0, -wheelAngularSpeed * 0.09))
        let objectSpeed = objectVelocityX * tx + objectVelocityY * ty
        let mismatch = beltSpeed - objectSpeed
        guard mismatch.isFinite, abs(mismatch) > 0.01 else { return nil }

        // Approximate viscous traction. These are NOT original PC constants.
        let strength = max(-8.0, min(8.0, mismatch * 3.0))
        let total = strength * max(0.05, mass)
        let x = tx * total, y = ty * total
        guard x.isFinite, y.isFinite else { return nil }
        return Force(x: x, y: y)
    }
}
