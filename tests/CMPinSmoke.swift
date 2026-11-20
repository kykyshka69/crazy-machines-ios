import Foundation
@main struct CMPinSmoke {
 static func main() {
  var checks=0
  for x in 0..<10 {
   for y in 0..<10 {
    for speed in 0..<10 {
     var world=CMPhysicsWorld2D()
     let anchor=SIMD2<Double>(Double(x),Double(y)+10)
     world.bodies=[CMPhysicsBody2D(position:SIMD2(0,10),
        velocity:SIMD2(Double(speed),0),radius:0.5)]
     let pin=CMPinJoint2D(bodyIndex:0,anchor:anchor)
     for _ in 0..<10 {
      world.step(dt:1.0/120.0)
      precondition(world.applyPins([pin])==1)
      precondition(world.bodies[0].position==anchor)
      precondition(world.bodies[0].velocity == .zero)
     }
     checks += 1
    }
   }
  }
  precondition(checks==1000)
  var invalid=CMPhysicsWorld2D()
  invalid.bodies=[CMPhysicsBody2D(position:SIMD2(0,1),radius:0.5)]
  precondition(invalid.applyPins([CMPinJoint2D(bodyIndex:-1,anchor:SIMD2(1,2)),
    CMPinJoint2D(bodyIndex:1,anchor:SIMD2(1,2))])==0)

  // Ten focused regression cases for the editor's fixed-pin mechanic.
  // 1. Empty constraint list does not change a body.
  var probe=CMPhysicsWorld2D()
  probe.bodies=[CMPhysicsBody2D(position:SIMD2(2,3),velocity:SIMD2(4,5),radius:0.25)]
  precondition(probe.applyPins([])==0)
  precondition(probe.bodies[0].position==SIMD2(2,3))

  // 2. Negative body index is ignored.
  precondition(probe.applyPins([CMPinJoint2D(bodyIndex:-1,anchor:SIMD2(1,1))])==0)
  // 3. Index equal to count is ignored.
  precondition(probe.applyPins([CMPinJoint2D(bodyIndex:1,anchor:SIMD2(1,1))])==0)
  // 4. NaN anchor X is rejected.
  precondition(probe.applyPins([CMPinJoint2D(bodyIndex:0,anchor:SIMD2(.nan,1))])==0)
  // 5. Infinite anchor Y is rejected.
  precondition(probe.applyPins([CMPinJoint2D(bodyIndex:0,anchor:SIMD2(1,.infinity))])==0)
  // 6. Nonpositive body mass is rejected.
  probe.bodies[0].mass=0
  precondition(probe.applyPins([CMPinJoint2D(bodyIndex:0,anchor:SIMD2(1,1))])==0)
  probe.bodies[0].mass=1

  // 7. Valid pin snaps position to its anchor.
  precondition(probe.applyPins([CMPinJoint2D(bodyIndex:0,anchor:SIMD2(1,2))])==1)
  precondition(probe.bodies[0].position==SIMD2(1,2))
  // 8. Valid pin cancels translational velocity.
  precondition(probe.bodies[0].velocity == .zero)

  // 9. Multiple distinct pins constrain their corresponding bodies.
  probe.bodies.append(CMPhysicsBody2D(position:SIMD2(3,4),radius:0.25))
  precondition(probe.applyPins([
   CMPinJoint2D(bodyIndex:0,anchor:SIMD2(2,4)),
   CMPinJoint2D(bodyIndex:1,anchor:SIMD2(5,6))
  ])==2)
  precondition(probe.bodies[0].position==SIMD2(2,4))
  precondition(probe.bodies[1].position==SIMD2(5,6))

  // 10. Reapplying a fixed pin after gravity restores its position.
  let anchor=SIMD2<Double>(2,4)
  for _ in 0..<120 {
   probe.step(dt:1.0/120.0)
   precondition(probe.applyPins([CMPinJoint2D(bodyIndex:0,anchor:anchor)])==1)
   precondition(probe.bodies[0].position==anchor)
  }
  // Duplicate constraints must not cause one body to jump between anchors.
  var duplicates=CMPhysicsWorld2D()
  duplicates.bodies=[CMPhysicsBody2D(position:SIMD2(0,2),radius:0.5)]
  let firstPin=CMPinJoint2D(bodyIndex:0,anchor:SIMD2(3,4))
  let conflictingPin=CMPinJoint2D(bodyIndex:0,anchor:SIMD2(9,10))
  precondition(duplicates.applyPins([firstPin,conflictingPin])==1)
  precondition(duplicates.bodies[0].position==SIMD2(3,4))
  // An invalid first constraint must not block a later valid one.
  duplicates.bodies[0].position=SIMD2(0,2)
  precondition(duplicates.applyPins([
    CMPinJoint2D(bodyIndex:0,anchor:SIMD2(.nan,4)),firstPin
  ])==1)
  precondition(duplicates.bodies[0].position==SIMD2(3,4))
  // Malformed disk geometry or positions must not be silently repaired by pins.
  var malformed=CMPhysicsWorld2D()
  malformed.bodies=[CMPhysicsBody2D(position:SIMD2(.nan,2),radius:0.5)]
  precondition(malformed.applyPins([firstPin])==0)
  precondition(malformed.bodies[0].position.x.isNaN)
  malformed.bodies[0].position=SIMD2(0,2)
  malformed.bodies[0].radius = .infinity
  precondition(malformed.applyPins([firstPin])==0)
  malformed.bodies[0].radius = 0
  precondition(malformed.applyPins([firstPin])==0)
  malformed.bodies[0].radius = 0.5
  precondition(malformed.applyPins([firstPin])==1)
  precondition(malformed.bodies[0].position==SIMD2(3,4))
  print("PASS: 1000 fixed-pin constraint scenarios")
 }
}
