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
  print("PASS: 1000 fixed-pin constraint scenarios")
 }
}
