import Foundation
@main struct CMSlopeSmoke {
 static func main() {
  var count=0
  for incline in 0...9 {
   for radiusIndex in 1...10 {
    for bounce in 0...9 {
     var w=CMPhysicsWorld2D()
     w.gravity = .zero
     let rise=Double(incline)*0.1
     let radius=Double(radiusIndex)*0.05
     let e=Double(bounce)*0.1
     let start=SIMD2<Double>(-5,4)
     let end=SIMD2<Double>(5,4+rise)
     let tangent=end-start
     let n=SIMD2<Double>(-tangent.y,tangent.x)/sqrt(tangent.x*tangent.x+tangent.y*tangent.y)
     let center=(start+end)*0.5
     w.segments=[CMStaticSegment2D(start:start,end:end)]
     w.bodies=[CMPhysicsBody2D(position:center+n*(radius*0.8),
                 velocity:-n, radius:radius,restitution:e)]
     w.step(dt:1.0/120.0)
     let b=w.bodies[0]
     let signed=(b.position.x-center.x)*n.x+(b.position.y-center.y)*n.y
     precondition(signed >= radius-1e-8)
     let normalSpeed=b.velocity.x*n.x+b.velocity.y*n.y
     precondition(abs(normalSpeed-e)<1e-8)
     count += 1
    }
   }
  }
  precondition(count==1000)
  var w=CMPhysicsWorld2D()
  w.gravity = .zero
  w.segments=[CMStaticSegment2D(start:SIMD2(-2,4),end:SIMD2(2,4))]
  w.bodies=[CMPhysicsBody2D(position:SIMD2(0,3.8),velocity:SIMD2(0,1),radius:0.5)]
  w.step(dt:1.0/120.0)
  precondition(w.bodies[0].position.y < 4)
  print("PASS: 1000 incline collision scenarios; underside excluded")
 }
}
