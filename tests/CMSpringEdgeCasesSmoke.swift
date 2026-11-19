import Foundation

@main struct CMSpringEdgeCasesSmoke {
 static func main() {
  func scene(_ firstMass: Double = 1, _ secondMass: Double = 1) -> CMPhysicsWorld2D {
   var world=CMPhysicsWorld2D()
   world.gravity = .zero
   world.bodies=[
    CMPhysicsBody2D(position:SIMD2(1,3),radius:0.2,mass:firstMass),
    CMPhysicsBody2D(position:SIMD2(3,3),radius:0.2,mass:secondMass)
   ]
   return world
  }
  let spring=CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1,stiffness:20,damping:2)
  // 1. Reject NaN time step without changing velocities.
  var w=scene()
  precondition(w.applySprings([spring],dt:.nan)==0)
  precondition(w.bodies.allSatisfy {$0.velocity == .zero})
  // 2. Reject infinite time step.
  precondition(w.applySprings([spring],dt:.infinity)==0)
  // 3. Reject negative time step.
  precondition(w.applySprings([spring],dt:-0.01)==0)
  // 4. Reject time steps above the stability bound.
  precondition(w.applySprings([spring],dt:0.1)==0)
  // 5. Reject negative mass without changing either disk.
  w=scene(-1,1)
  precondition(w.applySprings([spring],dt:1.0/120)==0)
  precondition(w.bodies.allSatisfy {$0.velocity == .zero})
  // 6. Reject NaN position.
  w=scene()
  w.bodies[1].position.x = .nan
  precondition(w.applySprings([spring],dt:1.0/120)==0)
  // 7. Reject infinite velocity.
  w=scene()
  w.bodies[0].velocity.x = .infinity
  precondition(w.applySprings([spring],dt:1.0/120)==0)
  // 8. Unequal masses receive equal-and-opposite momenta.
  w=scene(2,5)
  precondition(w.applySprings([spring],dt:1.0/120)==1)
  let totalMomentum=w.bodies[0].velocity.x*2+w.bodies[1].velocity.x*5
  precondition(abs(totalMomentum)<1e-10)
  // 9. A force-limited spring remains finite with extreme valid stiffness.
  w=scene()
  let strong=CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:0,stiffness:1000,damping:100)
  precondition(w.applySprings([strong],dt:1.0/120)==1)
  precondition(w.bodies.allSatisfy {$0.velocity.x.isFinite && abs($0.velocity.x)<=20})
  // 10. Zero stiffness and damping do not alter velocities.
  w=scene()
  w.bodies[0].velocity=SIMD2(0.5,0)
  w.bodies[1].velocity=SIMD2(-0.5,0)
  let inert=CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:0,stiffness:0,damping:0)
  precondition(w.applySprings([inert],dt:1.0/120)==1)
  precondition(w.bodies[0].velocity.x==0.5 && w.bodies[1].velocity.x == -0.5)
  print("PASS: 10 spring edge-case regression scenarios")
 }
}
