import Foundation
@main struct CMFrictionSmoke {
 static func main() {
  var cases=0
  for speed in 1...10 {
   for floor in 0...9 {
    for bodyFriction in 0...9 {
     var w=CMPhysicsWorld2D()
     w.floorFriction=Double(floor)/9
     w.bodies=[CMPhysicsBody2D(position:SIMD2(0,0.49),
       velocity:SIMD2(Double(speed),0),radius:0.5,
       restitution:0,surfaceFriction:Double(bodyFriction)/9)]
     w.step(dt:1.0/120.0)
     let vx=w.bodies[0].velocity.x
     precondition(vx >= -1e-9 && vx <= Double(speed)+1e-9)
     if floor == 0 || bodyFriction == 0 {
      precondition(abs(vx-Double(speed))<1e-9)
     } else {
      precondition(vx < Double(speed))
     }
     cases += 1
    }
   }
  }
  precondition(cases==1000)
  var ramp=CMPhysicsWorld2D()
  ramp.segments=[CMStaticSegment2D(start:SIMD2(-5,4),end:SIMD2(5,4),friction:1)]
  ramp.bodies=[CMPhysicsBody2D(position:SIMD2(0,4.49),
    velocity:SIMD2(2,0),radius:0.5,restitution:0,surfaceFriction:1)]
  ramp.step(dt:1.0/120.0)
  precondition(ramp.bodies[0].velocity.x < 2)
  print("PASS: 1000 floor friction cases and ramp friction")
 }
}
