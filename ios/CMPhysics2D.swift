import Foundation

/// Deterministic, minimal 2D physics prototype; not the original game's physics.
public struct CMPhysicsBody2D {
 public var position: SIMD2<Double>
 public var velocity: SIMD2<Double>
 public var radius: Double
 public var restitution: Double
 public init(position: SIMD2<Double>, velocity: SIMD2<Double> = .zero,
             radius: Double, restitution: Double = 0.4) {
  self.position=position;self.velocity=velocity;self.radius=radius
  self.restitution=restitution
 }
}
public struct CMPhysicsWorld2D {
 public var gravity=SIMD2<Double>(0,-9.81)
 public var floorY: Double = 0
 public var bodies: [CMPhysicsBody2D] = []
 public init() {}
 /// Fixed-step semi-implicit Euler with a horizontal floor and bounce.
 public mutating func step(dt: Double) {
  guard dt.isFinite && dt > 0 && dt <= 1.0/30.0 else { return }
  for i in bodies.indices {
   guard bodies[i].radius.isFinite && bodies[i].radius > 0,
         bodies[i].restitution.isFinite,
         bodies[i].position.x.isFinite,bodies[i].position.y.isFinite,
         bodies[i].velocity.x.isFinite,bodies[i].velocity.y.isFinite else { continue }
   bodies[i].velocity += gravity*dt
   bodies[i].position += bodies[i].velocity*dt
   let bottom=floorY+bodies[i].radius
   if bodies[i].position.y < bottom {
    bodies[i].position.y=bottom
    if bodies[i].velocity.y < 0 {
     bodies[i].velocity.y = -bodies[i].velocity.y * min(max(bodies[i].restitution,0),1)
    }
   }
  }
 }
}
