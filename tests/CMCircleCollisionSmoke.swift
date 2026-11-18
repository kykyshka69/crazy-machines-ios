import Foundation
@main struct CMCircleCollisionSmoke {
 static func main() {
  var count=0
  for massA in 1...10 {
   for massB in 1...10 {
    for elasticity in 0...9 {
     var w=CMPhysicsWorld2D()
     w.gravity = .zero
     let e=Double(elasticity)/10
     w.bodies=[
      CMPhysicsBody2D(position:SIMD2(-0.4,5),velocity:SIMD2(1,0),radius:0.5,restitution:e,mass:Double(massA)),
      CMPhysicsBody2D(position:SIMD2(0.4,5),velocity:SIMD2(-1,0),radius:0.5,restitution:e,mass:Double(massB))
     ]
     let initialMomentum=Double(massA)-Double(massB)
     w.step(dt:1.0/120.0)
     let a=w.bodies[0],b=w.bodies[1]
     let momentum=Double(massA)*a.velocity.x+Double(massB)*b.velocity.x
     precondition(abs(momentum-initialMomentum)<1e-8)
     precondition(b.position.x-a.position.x >= 1-1e-9)
     precondition(a.position.x.isFinite && b.position.x.isFinite)
     count += 1
    }
   }
  }
  precondition(count==1000)
  var coincident=CMPhysicsWorld2D()
  coincident.gravity = .zero
  coincident.bodies=[
   CMPhysicsBody2D(position:SIMD2(0,5),radius:0.5),
   CMPhysicsBody2D(position:SIMD2(0,5),radius:0.5)
  ]
  coincident.step(dt:1.0/120.0)
  precondition(coincident.bodies[0].position.x.isFinite)
  precondition(coincident.bodies[1].position.x.isFinite)
  print("PASS: 1000 circle collisions conserve horizontal momentum and separate overlaps")
 }
}
