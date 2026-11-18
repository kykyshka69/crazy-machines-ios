import Foundation
@main struct CMAngularSmoke {
 static func main() {
  var count=0
  for spin in 1...10 {
   for friction in 0...9 {
    for speed in 1...10 {
     var w=CMPhysicsWorld2D()
     w.gravity = .zero
     let mu=Double(friction)/9
     w.bodies=[
      CMPhysicsBody2D(position:SIMD2(-0.45,5),velocity:SIMD2(Double(speed),1),
       radius:0.5,restitution:0,mass:1,surfaceFriction:mu,angularVelocity:Double(spin)),
      CMPhysicsBody2D(position:SIMD2(0.45,5),velocity:SIMD2(-Double(speed),0),
       radius:0.5,restitution:0,mass:1,surfaceFriction:mu)
     ]
     w.step(dt:1.0/120.0)
     let a=w.bodies[0],b=w.bodies[1]
     precondition(a.angularVelocity.isFinite && b.angularVelocity.isFinite)
     precondition(abs(a.velocity.y+b.velocity.y-1)<1e-8)
     if friction==0 {
      precondition(abs(a.angularVelocity-Double(spin))<1e-9)
      precondition(abs(b.angularVelocity)<1e-9)
     }
     count += 1
    }
   }
  }
  precondition(count==1000)
  var free=CMPhysicsWorld2D()
  free.gravity = .zero
  free.bodies=[CMPhysicsBody2D(position:SIMD2(0,3),radius:0.5,angularVelocity:2)]
  free.step(dt:0.01)
  precondition(abs(free.bodies[0].angle-0.02)<1e-12)
  print("PASS: 1000 angular collision cases and free rotation")
 }
}
