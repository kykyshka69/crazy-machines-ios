import Foundation

@main struct CMCombinedMechanicsSmoke {
 static func main() {
  func scene() -> CMPhysicsWorld2D {
   var w=CMPhysicsWorld2D()
   w.gravity = SIMD2(0,-9.81)
   w.bodies=[
    CMPhysicsBody2D(position:SIMD2(1,4),radius:0.2),
    CMPhysicsBody2D(position:SIMD2(3,4),radius:0.2),
    CMPhysicsBody2D(position:SIMD2(5,4),radius:0.2)
   ]
   return w
  }
  let left=CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1,stiffness:20,damping:2)
  let right=CMSpringJoint2D(firstIndex:1,secondIndex:2,restLength:1,stiffness:20,damping:2)
  let fixed=CMPinJoint2D(bodyIndex:0,anchor:SIMD2(1,4))
  // 1. A spring between two free disks changes both velocities.
  var w=scene()
  precondition(w.applySprings([left],dt:1.0/120)==1)
  precondition(w.bodies[0].velocity.x > 0 && w.bodies[1].velocity.x < 0)
  // 2. Two connected springs can be applied in the same frame.
  w=scene()
  precondition(w.applySprings([left,right],dt:1.0/120)==2)
  // 3. The first disk is restored to its fixed anchor.
  w.step(dt:1.0/120)
  precondition(w.applyPins([fixed])==1)
  precondition(w.bodies[0].position==fixed.anchor)
  // 4. A fixed disk has no residual translational velocity.
  precondition(w.bodies[0].velocity == .zero)
  // 5. An attached free disk still moves.
  precondition(w.bodies[1].velocity.y < 0)
  // 6. A fixed disk remains fixed across 120 frames.
  w=scene()
  for _ in 0..<120 {
   _=w.applySprings([left,right],dt:1.0/120)
   w.step(dt:1.0/120)
   _=w.applyPins([fixed])
   precondition(w.bodies[0].position==fixed.anchor)
  }
  // 7. All three disk coordinates remain finite after the simulation.
  precondition(w.bodies.allSatisfy({$0.position.x.isFinite && $0.position.y.isFinite}))
  // 8. All three disk velocities remain finite.
  precondition(w.bodies.allSatisfy({$0.velocity.x.isFinite && $0.velocity.y.isFinite}))
  // 9. Removing springs stops the spring impulse.
  let before=w.bodies.map(\.velocity)
  precondition(w.applySprings([],dt:1.0/120)==0)
  precondition(zip(w.bodies,before).allSatisfy({$0.0.velocity==$0.1}))
  // 10. Invalid spring endpoints cannot corrupt a pinned scene.
  let bad=CMSpringJoint2D(firstIndex:0,secondIndex:99,restLength:1)
  precondition(w.applySprings([bad],dt:1.0/120)==0)
  precondition(w.bodies[0].position==fixed.anchor)
  print("PASS: 10 combined pin and spring regression scenarios")
 }
}
