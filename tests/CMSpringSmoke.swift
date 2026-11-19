import Foundation

@main struct CMSpringSmoke {
 static func main() {
  func world(_ x: Double = 0, _ y: Double = 2) -> CMPhysicsWorld2D {
   var w=CMPhysicsWorld2D()
   w.gravity = .zero
   w.bodies=[
    CMPhysicsBody2D(position:SIMD2(x,y),radius:0.2),
    CMPhysicsBody2D(position:SIMD2(x+2,y),radius:0.2)
   ]
   return w
  }
  let spring=CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1)
  // 1. A stretched spring pulls the disks together.
  var w=world()
  precondition(w.applySprings([spring],dt:1.0/120)==1)
  precondition(w.bodies[0].velocity.x > 0 && w.bodies[1].velocity.x < 0)
  // 2. The impulse preserves total momentum for equal masses.
  precondition(abs(w.bodies[0].velocity.x+w.bodies[1].velocity.x)<1e-10)
  // 3. Rest length causes no force when velocities match.
  w=world()
  precondition(w.applySprings([CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:2)],dt:1.0/120)==1)
  precondition(w.bodies[0].velocity == .zero && w.bodies[1].velocity == .zero)
  // 4. Compression pushes the disks apart.
  w=world()
  precondition(w.applySprings([CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:3)],dt:1.0/120)==1)
  precondition(w.bodies[0].velocity.x < 0 && w.bodies[1].velocity.x > 0)
  // 5. A zero time step is ignored.
  w=world()
  precondition(w.applySprings([spring],dt:0)==0)
  precondition(w.bodies[0].velocity == .zero)
  // 6. Identical body indices are rejected.
  precondition(w.applySprings([CMSpringJoint2D(firstIndex:0,secondIndex:0,restLength:1)],dt:0.01)==0)
  // 7. Missing body indices are rejected.
  precondition(w.applySprings([CMSpringJoint2D(firstIndex:0,secondIndex:4,restLength:1)],dt:0.01)==0)
  // 8. Invalid stiffness is rejected.
  precondition(w.applySprings([CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1,stiffness:-1)],dt:0.01)==0)
  // 9. Coincident disks do not produce NaN impulses.
  w.bodies[1].position=w.bodies[0].position
  precondition(w.applySprings([spring],dt:0.01)==0)
  precondition(w.bodies[0].velocity == .zero)
  // 10. Damping opposes relative motion at rest length.
  w=world()
  w.bodies[0].velocity=SIMD2(-1,0)
  w.bodies[1].velocity=SIMD2(1,0)
  let damped=CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:2,stiffness:0,damping:5)
  precondition(w.applySprings([damped],dt:0.01)==1)
  precondition(w.bodies[0].velocity.x > -1 && w.bodies[1].velocity.x < 1)
  print("PASS: 10 spring connector regression scenarios")
 }
}
