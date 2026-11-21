import Foundation

@main
struct OriginalConveyorContactSmoke {
    static func force(
        x: Float = 0, y: Float = 0.08646,
        low: Float = -0.59072, high: Float = 0.59072,
        top: Float = 0.08646, omega: Float = 2,
        tx: Float = 1, ty: Float = 0,
        vx: Float = 0, vy: Float = 0, mass: Float = 1
    ) -> CMOriginalConveyorContact.Force? {
        CMOriginalConveyorContact.surfaceForce(
            localX: x, localY: y,
            beltMinX: low, beltMaxX: high, beltTopY: top,
            wheelAngularSpeed: omega,
            tangentX: tx, tangentY: ty,
            objectVelocityX: vx, objectVelocityY: vy, mass: mass
        )
    }

    static func main() {
        func near(_ value: Float, _ expected: Float) -> Bool {
            abs(value - expected) < 0.00001
        }
        // Original +Z wheel has negative-X top motion.
        guard let normal = force(), let mirrored = force(tx: -1),
              let rotated = force(tx: 0, ty: 3),
              let reversed = force(omega: -2) else {
            preconditionFailure("Expected wheel-driven traction")
        }
        precondition(near(normal.x, -0.54) && near(normal.y, 0))
        precondition(near(mirrored.x, 0.54) && near(mirrored.y, 0))
        precondition(near(rotated.x, 0) && near(rotated.y, -0.54))
        precondition(near(reversed.x, 0.54))
        precondition(force(vx: -0.18) == nil)
        guard let fast = force(omega: 1000, mass: 2) else {
            preconditionFailure("Expected speed-limited traction")
        }
        precondition(near(fast.x, -12))

        // Frame, underside, out-of-range and stationary wheel never propel.
        precondition(force(x: -0.7) == nil)
        precondition(force(x: 0.7) == nil)
        precondition(force(y: -0.1) == nil)
        precondition(force(y: 0.25) == nil)
        precondition(force(omega: 0) == nil)
        precondition(force(omega: 0.05) == nil)
        precondition(force(tx: 0, ty: 0) == nil)
        precondition(force(tx: Float.infinity) == nil)
        precondition(force(vx: Float.nan) == nil)
        precondition(force(mass: -1) == nil)
        precondition(force(mass: Float.infinity) == nil)
        precondition(force(low: 1, high: 0) == nil)

        for i in 0..<1000 {
            let rotation = Float((i % 40) - 20) * 0.3
            let vx = Float((i % 17) - 8) * 0.2
            let impulse = force(omega: rotation,
                tx: i.isMultiple(of: 2) ? -2 : 2,
                vx: vx, mass: Float(1 + i % 10) * 0.2)
            if let impulse {
                precondition(impulse.x.isFinite && impulse.y.isFinite)
                precondition(abs(impulse.x) <= 16.001)
                precondition(near(impulse.y, 0))
            }
        }
        print("Original conveyor contact and 1000 moving-body regression cases: OK")
    }
}
