import Foundation

/// Elastic connector between two disks, with Hooke stiffness and velocity damping.
/// The connector applies forces before the world's regular integration step.
public struct CMSpringJoint2D {
 public var firstIndex: Int
 public var secondIndex: Int
 public var restLength: Double
 public var stiffness: Double
 public var damping: Double

 public init(firstIndex: Int, secondIndex: Int, restLength: Double,
             stiffness: Double = 20, damping: Double = 2) {
  self.firstIndex=firstIndex
  self.secondIndex=secondIndex
  self.restLength=restLength
  self.stiffness=stiffness
  self.damping=damping
 }
}

public extension CMPhysicsWorld2D {
 /// Apply a stable, bounded spring impulse. Invalid and coincident joints are ignored.
 /// Returns the number of spring joints that were applied.
 @discardableResult
 mutating func applySprings(_ springs: [CMSpringJoint2D], dt: Double) -> Int {
  guard dt.isFinite, dt > 0, dt <= 1.0/30.0 else { return 0 }
  var applied=0
  for spring in springs {
   let a=spring.firstIndex,b=spring.secondIndex
   guard bodies.indices.contains(a), bodies.indices.contains(b), a != b,
    spring.restLength.isFinite, spring.restLength >= 0,
    spring.stiffness.isFinite, (0...1000).contains(spring.stiffness),
    spring.damping.isFinite, (0...100).contains(spring.damping) else { continue }
   let first=bodies[a],second=bodies[b]
   guard first.mass.isFinite,first.mass > 0,second.mass.isFinite,second.mass > 0,
    first.position.x.isFinite,first.position.y.isFinite,
    second.position.x.isFinite,second.position.y.isFinite,
    first.velocity.x.isFinite,first.velocity.y.isFinite,
    second.velocity.x.isFinite,second.velocity.y.isFinite else { continue }
   let delta=second.position-first.position
   let lengthSquared=delta.x*delta.x+delta.y*delta.y
   guard lengthSquared.isFinite,lengthSquared > 1e-12 else { continue }
   let length=sqrt(lengthSquared)
   let axis=delta/length
   let relativeVelocity=second.velocity-first.velocity
   let along=relativeVelocity.x*axis.x+relativeVelocity.y*axis.y
   let force=spring.stiffness*(length-spring.restLength)+spring.damping*along
   guard force.isFinite else { continue }
   // Bound the change in relative velocity to avoid numerical explosions.
   let inverseMass=1/first.mass+1/second.mass
   let impulse=max(-20,min(20,force*dt))
   let correction=axis*impulse
   let firstVelocity=first.velocity+correction/first.mass
   let secondVelocity=second.velocity-correction/second.mass
   guard firstVelocity.x.isFinite,firstVelocity.y.isFinite,
    secondVelocity.x.isFinite,secondVelocity.y.isFinite,
    inverseMass.isFinite else { continue }
   bodies[a].velocity=firstVelocity
   bodies[b].velocity=secondVelocity
   applied+=1
  }
  return applied
 }
}
