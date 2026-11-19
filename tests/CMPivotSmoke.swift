import Foundation

@main struct CMPivotSmoke {
 static func main() {
  func world() -> CMPhysicsWorld2D {
   var w=CMPhysicsWorld2D()
   w.gravity = .zero
   w.bodies=[CMPhysicsBody2D(position:SIMD2(3,3),velocity:SIMD2(2,3),radius:0.2)]
   return w
  }
  let pivot=CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,3),length:2)
  // 1. A valid pivot applies.
  var w=world()
  precondition(w.applyPivots([pivot])==1)
  // 2. Radial velocity is removed.
  precondition(abs(w.bodies[0].velocity.x)<1e-12)
  // 3. Tangential velocity remains.
  precondition(abs(w.bodies[0].velocity.y-3)<1e-12)
  // 4. A displaced disk is returned to the correct radius.
  w=world()
  w.bodies[0].position=SIMD2(5,3)
  precondition(w.applyPivots([pivot])==1)
  precondition(abs(w.bodies[0].position.x-3)<1e-12)
  // 5. Invalid body indices are ignored.
  w=world()
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:5,anchor:SIMD2(1,3),length:2)])==0)
  // 6. Zero pivot lengths are rejected.
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,3),length:0)])==0)
  // 7. Nonfinite anchors are rejected.
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(.infinity,3),length:2)])==0)
  // 8. Coincident anchor and body are ignored without NaNs.
  w=world()
  w.bodies[0].position=SIMD2(1,3)
  precondition(w.applyPivots([pivot])==0)
  precondition(w.bodies[0].velocity.x.isFinite)
  // 9. A moving pendulum remains on its pivot circle over many frames.
  w=world()
  for _ in 0..<240 {
   w.step(dt:1.0/120)
   precondition(w.applyPivots([pivot])==1)
   let offset=w.bodies[0].position-pivot.anchor
   precondition(abs(sqrt(offset.x*offset.x+offset.y*offset.y)-2)<1e-9)
  }
  // 10. No radial velocity remains after the simulation.
  let offset=w.bodies[0].position-pivot.anchor
  let dot=w.bodies[0].velocity.x*offset.x+w.bodies[0].velocity.y*offset.y
  precondition(abs(dot)<1e-9)
  print("PASS: 10 pivot and pendulum regression scenarios")
 }
}
