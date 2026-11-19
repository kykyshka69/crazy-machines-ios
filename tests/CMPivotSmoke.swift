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
  // 11. Negative lengths are rejected.
  w=world()
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,3),length:-1)])==0)
  // 12. Infinite lengths are rejected.
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,3),length:.infinity)])==0)
  // 13. NaN lengths are rejected.
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,3),length:.nan)])==0)
  // 14. Excessively long rods are rejected.
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,3),length:21)])==0)
  // 15. Negative indices are rejected.
  precondition(w.applyPivots([CMPivotJoint2D(bodyIndex:-1,anchor:SIMD2(1,3),length:2)])==0)
  // 16. Nonfinite disk coordinates are rejected.
  w=world()
  w.bodies[0].position.y = .nan
  precondition(w.applyPivots([pivot])==0)
  // 17. Nonfinite disk velocities are rejected.
  w=world()
  w.bodies[0].velocity.y = .infinity
  precondition(w.applyPivots([pivot])==0)
  // 18. Nonpositive mass is rejected.
  w=world()
  w.bodies[0].mass=0
  precondition(w.applyPivots([pivot])==0)
  // 19. Applying an empty pivot collection is a no-op.
  w=world()
  let original=w.bodies[0].position
  precondition(w.applyPivots([])==0)
  precondition(w.bodies[0].position==original)
  // 20. Two independent pivots constrain two disks.
  w=world()
  w.bodies.append(CMPhysicsBody2D(position:SIMD2(6,3),velocity:SIMD2(1,2),radius:0.2))
  let other=CMPivotJoint2D(bodyIndex:1,anchor:SIMD2(4,3),length:2)
  precondition(w.applyPivots([pivot,other])==2)
  precondition(abs(w.bodies[1].velocity.x)<1e-12)
  // 21–50. Thirty different pendulum angles and tangential velocities.
  // Each case validates radius preservation, finite state, and zero radial speed.
  for caseIndex in 0..<30 {
   let angle=Double(caseIndex)*Double.pi/15
   let direction=SIMD2(cos(angle),sin(angle))
   let tangent=SIMD2(-direction.y,direction.x)
   let anchor=SIMD2(3.5,3)
   let radius=0.5+Double(caseIndex%5)*0.3
   var trial=world()
   trial.bodies[0].position=anchor+direction*radius
   trial.bodies[0].velocity=tangent*(0.25+Double(caseIndex%7)*0.3)+direction*0.7
   let joint=CMPivotJoint2D(bodyIndex:0,anchor:anchor,length:radius)
   precondition(trial.applyPivots([joint])==1,"Angle case \\(caseIndex)")
   let radial=trial.bodies[0].position-anchor
   let distance=sqrt(radial.x*radial.x+radial.y*radial.y)
   let radialSpeed=trial.bodies[0].velocity.x*radial.x+trial.bodies[0].velocity.y*radial.y
   precondition(abs(distance-radius)<1e-10)
   precondition(abs(radialSpeed)<1e-10)
   precondition(trial.bodies[0].velocity.x.isFinite && trial.bodies[0].velocity.y.isFinite)
  }
  // 51–70. Twenty independently stepped pendulums under gravity.
  // Vary initial angle, gravity, and velocity, then check every constrained step.
  for caseIndex in 0..<20 {
   var trial=world()
   trial.gravity=SIMD2(0,-2-Double(caseIndex%5)*2)
   let angle=Double(caseIndex+1)*Double.pi/25
   let anchor=SIMD2(3.5,4)
   let radius=1.0+Double(caseIndex%4)*0.2
   let direction=SIMD2(sin(angle),-cos(angle))
   trial.bodies[0].position=anchor+direction*radius
   trial.bodies[0].velocity=SIMD2(Double(caseIndex%3)*0.25,0)
   let joint=CMPivotJoint2D(bodyIndex:0,anchor:anchor,length:radius)
   for _ in 0..<60 {
    trial.step(dt:1.0/120)
    precondition(trial.applyPivots([joint])==1,"Gravity case \\(caseIndex)")
    let radial=trial.bodies[0].position-anchor
    let distance=sqrt(radial.x*radial.x+radial.y*radial.y)
    let speed=trial.bodies[0].velocity.x*radial.x+trial.bodies[0].velocity.y*radial.y
    precondition(abs(distance-radius)<1e-8)
    precondition(abs(speed)<1e-8)
   }
  }
  print("PASS: 70 pivot and pendulum regression scenarios")
 }
}
