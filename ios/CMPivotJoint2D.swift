import Foundation

/// A fixed-distance pivot: the center of a disk can move around a world anchor.
/// Unlike a fixed pin, it preserves tangential motion, enabling pendulums.
public struct CMPivotJoint2D {
 public var bodyIndex: Int
 public var anchor: SIMD2<Double>
 public var length: Double
 public init(bodyIndex:Int,anchor:SIMD2<Double>,length:Double) {
  self.bodyIndex=bodyIndex
  self.anchor=anchor
  self.length=length
 }
}

public extension CMPhysicsWorld2D {
 /// Apply a controlled tangential velocity impulse to a disk attached to a pivot.
 /// Returns false without mutation for malformed joints, invalid speeds or states.
 @discardableResult
 mutating func kickPivot(_ pivot:CMPivotJoint2D, speed:Double) -> Bool {
  guard bodies.indices.contains(pivot.bodyIndex),
   speed.isFinite,abs(speed)<=20,
   pivot.anchor.x.isFinite,pivot.anchor.y.isFinite,
   pivot.length.isFinite,pivot.length>0,pivot.length<=20 else { return false }
  let body=bodies[pivot.bodyIndex]
  guard body.mass.isFinite,body.mass>0,
   body.position.x.isFinite,body.position.y.isFinite,
   body.velocity.x.isFinite,body.velocity.y.isFinite else { return false }
  let offset=body.position-pivot.anchor
  let distanceSquared=offset.x*offset.x+offset.y*offset.y
  guard distanceSquared.isFinite,distanceSquared>1e-12 else { return false }
  let radius=sqrt(distanceSquared)
  let tangent=SIMD2(-offset.y/radius,offset.x/radius)
  let radial=offset/radius
  let radialSpeed=body.velocity.x*radial.x+body.velocity.y*radial.y
  let updated=body.velocity-radial*radialSpeed+tangent*speed
  guard updated.x.isFinite,updated.y.isFinite else { return false }
  bodies[pivot.bodyIndex].velocity=updated
  return true
 }
 /// Project disk centers onto their pivot circles and remove radial velocity.
 /// The caller should invoke this after each physics step.
 @discardableResult
 mutating func applyPivots(_ pivots:[CMPivotJoint2D]) -> Int {
  var applied=0
  for pivot in pivots {
   guard bodies.indices.contains(pivot.bodyIndex),
    pivot.anchor.x.isFinite,pivot.anchor.y.isFinite,
    pivot.length.isFinite,pivot.length > 0,pivot.length <= 20 else { continue }
   let index=pivot.bodyIndex
   let body=bodies[index]
   guard body.mass.isFinite,body.mass > 0,
    body.position.x.isFinite,body.position.y.isFinite,
    body.velocity.x.isFinite,body.velocity.y.isFinite else { continue }
   let offset=body.position-pivot.anchor
   let squared=offset.x*offset.x+offset.y*offset.y
   guard squared.isFinite,squared > 1e-12 else { continue }
   let direction=offset/sqrt(squared)
   let projected=pivot.anchor+direction*pivot.length
   let radial=body.velocity.x*direction.x+body.velocity.y*direction.y
   let tangential=body.velocity-direction*radial
   guard projected.x.isFinite,projected.y.isFinite,
    tangential.x.isFinite,tangential.y.isFinite else { continue }
   bodies[index].position=projected
   bodies[index].velocity=tangential
   applied+=1
  }
  return applied
 }
}
