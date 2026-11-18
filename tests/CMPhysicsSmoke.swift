import Foundation
@main struct CMPhysicsSmoke {
 static func main() {
  var checks=0
  for r in 1...10 {
   for bounce in 0...9 {
    for height in 1...10 {
     var world=CMPhysicsWorld2D()
     let radius=Double(r)*0.1
     let e=Double(bounce)/10
     world.bodies=[CMPhysicsBody2D(position:SIMD2(0,Double(height)+radius),radius:radius,restitution:e)]
     for _ in 0..<120 {
      world.step(dt:1.0/120.0)
      precondition(world.bodies[0].position.y >= radius - 1e-9)
      precondition(world.bodies[0].position.y.isFinite)
     }
     checks += 1
    }
   }
  }
  precondition(checks==1000)
  var world=CMPhysicsWorld2D()
  world.bodies=[CMPhysicsBody2D(position:SIMD2(0,1),radius:0.5,restitution:0)]
  for _ in 0..<600 { world.step(dt:1.0/120.0) }
  precondition(abs(world.bodies[0].position.y-0.5)<1e-8)
  precondition(abs(world.bodies[0].velocity.y)<1e-8)
  print("PASS: 1000 gravity/floor collision scenarios and stationary rest")
 }
}
