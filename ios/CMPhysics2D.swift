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
/// One-sided static ramp: collides from the upper side only.
public struct CMStaticSegment2D {
 public var start: SIMD2<Double>
 public var end: SIMD2<Double>
 public init(start:SIMD2<Double>,end:SIMD2<Double>) {
  self.start=start;self.end=end
 }
}
public struct CMPhysicsWorld2D {
 public var gravity=SIMD2<Double>(0,-9.81)
 public var floorY: Double = 0
 public var bodies: [CMPhysicsBody2D] = []
 public var segments: [CMStaticSegment2D] = []
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
  // Static ramps: closest-point contact, with an upward-facing one-sided normal.
  // Endpoints are treated as rounded caps. Zero-length ramps are ignored.
  for i in bodies.indices {
   let body=bodies[i]
   guard body.radius.isFinite,body.radius > 0,
         body.position.x.isFinite,body.position.y.isFinite,
         body.velocity.x.isFinite,body.velocity.y.isFinite,
         body.restitution.isFinite else { continue }
   for segment in segments {
    let axis=segment.end-segment.start
    let len2=axis.x*axis.x+axis.y*axis.y
    guard len2.isFinite,len2 > 1e-12 else { continue }
    var up=SIMD2<Double>(-axis.y,axis.x)/sqrt(len2)
    if up.y < 0 { up = -up }
    let offset=bodies[i].position-segment.start
    let side=offset.x*up.x+offset.y*up.y
    // Do not push objects approaching from below through a platform.
    guard side >= -1e-9 else { continue }
    let projection=(offset.x*axis.x+offset.y*axis.y)/len2
    let t=min(max(projection,0),1)
    let closest=segment.start+axis*t
    let delta=bodies[i].position-closest
    let d2=delta.x*delta.x+delta.y*delta.y
    guard d2.isFinite,d2 < body.radius*body.radius else { continue }
    let distance=sqrt(d2)
    let normal=distance > 1e-12 ? delta/distance : up
    // Reject backside contacts at rounded endpoints.
    guard normal.x*up.x+normal.y*up.y >= 0 else { continue }
    bodies[i].position += normal*(body.radius-distance)
    let vn=bodies[i].velocity.x*normal.x+bodies[i].velocity.y*normal.y
    if vn < 0 {
     let e=min(max(body.restitution,0),1)
     bodies[i].velocity -= normal*((1+e)*vn)
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
