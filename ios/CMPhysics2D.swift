import Foundation

/// Deterministic, minimal 2D physics prototype; not the original game's physics.
public struct CMPhysicsBody2D {
 public var position: SIMD2<Double>
 public var velocity: SIMD2<Double>
 public var radius: Double
 public var restitution: Double
 public var mass: Double
 public init(position: SIMD2<Double>, velocity: SIMD2<Double> = .zero,
             radius: Double, restitution: Double = 0.4, mass: Double = 1) {
  self.position=position;self.velocity=velocity;self.radius=radius
  self.restitution=restitution;self.mass=mass
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
         bodies[i].restitution.isFinite, bodies[i].mass.isFinite, bodies[i].mass > 0,
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
  // Resolve circle-circle overlaps and normal impulses in deterministic index order.
  guard bodies.count > 1 else { return }
  for i in 0..<(bodies.count-1) {
   for j in (i+1)..<bodies.count {
    let a=bodies[i], b=bodies[j]
    guard a.radius.isFinite,b.radius.isFinite,a.radius > 0,b.radius > 0,
          a.mass.isFinite,b.mass.isFinite,a.mass > 0,b.mass > 0,
          a.restitution.isFinite,b.restitution.isFinite,
          a.position.x.isFinite,a.position.y.isFinite,
          b.position.x.isFinite,b.position.y.isFinite,
          a.velocity.x.isFinite,a.velocity.y.isFinite,
          b.velocity.x.isFinite,b.velocity.y.isFinite else { continue }
    let delta=b.position-a.position
    let distanceSquared=delta.x*delta.x+delta.y*delta.y
    let radiusSum=a.radius+b.radius
    guard distanceSquared.isFinite,distanceSquared < radiusSum*radiusSum else { continue }
    let distance=sqrt(distanceSquared)
    let normal=distance > 1e-12 ? delta/distance : SIMD2<Double>(1,0)
    let invA=1/a.mass, invB=1/b.mass, invSum=invA+invB
    let penetration=radiusSum-distance
    bodies[i].position -= normal*(penetration*invA/invSum)
    bodies[j].position += normal*(penetration*invB/invSum)
    let relative=b.velocity-a.velocity
    let speed=relative.x*normal.x+relative.y*normal.y
    if speed < 0 {
     let e=min(max(min(a.restitution,b.restitution),0),1)
     let impulse=-(1+e)*speed/invSum
     bodies[i].velocity -= normal*(impulse*invA)
     bodies[j].velocity += normal*(impulse*invB)
    }
   }
  }
 }
}
