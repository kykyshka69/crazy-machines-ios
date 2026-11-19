import Foundation

@main struct CMSpringParametersSmoke {
 static func main() {
  func scene() -> CMPhysicsWorld2D {
   var world=CMPhysicsWorld2D()
   world.gravity = .zero
   world.bodies=[
    CMPhysicsBody2D(position:SIMD2(1,3),radius:0.2),
    CMPhysicsBody2D(position:SIMD2(3,3),radius:0.2)
   ]
   return world
  }
  func joint(_ length: Double = 1,_ stiffness: Double = 20,_ damping: Double = 2) -> CMSpringJoint2D {
   CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:length,stiffness:stiffness,damping:damping)
  }
  // 1. Zero stiffness and damping produce no velocity change.
  var world=scene()
  precondition(world.applySprings([joint(1,0,0)],dt:0.01)==1)
  precondition(world.bodies[0].velocity == .zero && world.bodies[1].velocity == .zero)
  // 2. Higher stiffness produces a stronger attraction.
  var soft=scene(),stiff=scene()
  _=soft.applySprings([joint(1,10,0)],dt:0.01)
  _=stiff.applySprings([joint(1,40,0)],dt:0.01)
  precondition(stiff.bodies[0].velocity.x > soft.bodies[0].velocity.x)
  // 3. A longer rest length switches attraction to repulsion.
  world=scene()
  _=world.applySprings([joint(4,20,0)],dt:0.01)
  precondition(world.bodies[0].velocity.x < 0)
  // 4. The upper allowed stiffness is accepted.
  world=scene()
  precondition(world.applySprings([joint(1,1000,0)],dt:0.01)==1)
  // 5. Stiffness above the maximum is rejected.
  world=scene()
  precondition(world.applySprings([joint(1,1000.01,0)],dt:0.01)==0)
  // 6. Negative damping is rejected.
  precondition(world.applySprings([joint(1,20,-0.01)],dt:0.01)==0)
  // 7. Damping above the maximum is rejected.
  precondition(world.applySprings([joint(1,20,100.01)],dt:0.01)==0)
  // 8. NaN rest length is rejected.
  precondition(world.applySprings([joint(.nan,20,2)],dt:0.01)==0)
  // 9. An excessively large time step is rejected.
  precondition(world.applySprings([joint()],dt:0.1)==0)
  // 10. Repeated steps with the maximum stiffness keep velocities finite.
  world=scene()
  for _ in 0..<240 {
   _=world.applySprings([joint(1,1000,100)],dt:1.0/120)
   world.step(dt:1.0/120)
   precondition(world.bodies.allSatisfy({
    $0.position.x.isFinite && $0.position.y.isFinite &&
    $0.velocity.x.isFinite && $0.velocity.y.isFinite
   }))
  }
  print("PASS: 10 spring parameter regression scenarios")
 }
}
