import Foundation
@main struct LevelDocumentSmoke {
 static func main() throws {
  var world=CMPhysicsWorld2D()
  world.gravity.y = -12
  world.floorFriction=0.6
  world.bodies=[CMPhysicsBody2D(position:SIMD2(1.5,4),radius:0.3,restitution:0.7,mass:2,surfaceFriction:0.4)]
  world.segments=[CMStaticSegment2D(start:SIMD2(1,2),end:SIMD2(5,1),friction:0.25)]
  let encoded=try JSONEncoder().encode(CMLevelDocument(world:world))
  let decoded=try JSONDecoder().decode(CMLevelDocument.self,from:encoded)
  let restored=try decoded.makeWorld()
  precondition(restored.gravity.y == -12)
  precondition(restored.floorFriction == 0.6)
  precondition(restored.bodies.count == 1 && restored.segments.count == 1)
  precondition(restored.bodies[0].mass == 2 && restored.segments[0].end.x == 5)
  var corrupt=decoded
  corrupt.balls[0].radius = -1
  do { _=try corrupt.makeWorld(); fatalError("Invalid radius accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.version=999
  do { _=try corrupt.makeWorld(); fatalError("Unknown version accepted") } catch CMLevelDocument.LevelError.invalid {}
  print("Level document roundtrip and validation passed")
 }
}
