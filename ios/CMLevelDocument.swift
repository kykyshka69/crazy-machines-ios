import Foundation

/// Portable, versioned snapshot of a user-created physics experiment.
public struct CMLevelDocument: Codable {
 public struct Ball: Codable {
  public var x: Double
  public var y: Double
  public var radius: Double
  public var restitution: Double
  public var mass: Double
  public var friction: Double
 }
 public struct Ramp: Codable {
  public var x1: Double
  public var y1: Double
  public var x2: Double
  public var y2: Double
  public var friction: Double
 }
 public var version: Int
 public var gravity: Double
 public var floorFriction: Double
 public var balls: [Ball]
 public var ramps: [Ramp]
 public init(world: CMPhysicsWorld2D) {
  version=1
  gravity = -world.gravity.y
  floorFriction=world.floorFriction
  balls=world.bodies.map { Ball(x:$0.position.x,y:$0.position.y,radius:$0.radius,restitution:$0.restitution,mass:$0.mass,friction:$0.surfaceFriction) }
  ramps=world.segments.map { Ramp(x1:$0.start.x,y1:$0.start.y,x2:$0.end.x,y2:$0.end.y,friction:$0.friction) }
 }
 public func makeWorld() throws -> CMPhysicsWorld2D {
  guard version == 1, gravity.isFinite, (0...20).contains(gravity),
   floorFriction.isFinite, (0...10).contains(floorFriction),
   balls.count <= 20, ramps.count <= 12 else { throw LevelError.invalid }
  var world=CMPhysicsWorld2D()
  world.gravity.y = -gravity
  world.floorFriction=floorFriction
  for ball in balls {
   guard [ball.x,ball.y,ball.radius,ball.restitution,ball.mass,ball.friction].allSatisfy({$0.isFinite}),
    (0...7).contains(ball.x), (0...6).contains(ball.y),
    (0.05...1).contains(ball.radius), (0...1).contains(ball.restitution),
    (0.01...100).contains(ball.mass), (0...10).contains(ball.friction) else { throw LevelError.invalid }
   world.bodies.append(CMPhysicsBody2D(position:SIMD2(ball.x,ball.y),radius:ball.radius,restitution:ball.restitution,mass:ball.mass,surfaceFriction:ball.friction))
  }
  for ramp in ramps {
   guard [ramp.x1,ramp.y1,ramp.x2,ramp.y2,ramp.friction].allSatisfy({$0.isFinite}),
    (0...7).contains(ramp.x1),(0...7).contains(ramp.x2),
    (0...6).contains(ramp.y1),(0...6).contains(ramp.y2),
    (0...10).contains(ramp.friction) else { throw LevelError.invalid }
   world.segments.append(CMStaticSegment2D(start:SIMD2(ramp.x1,ramp.y1),end:SIMD2(ramp.x2,ramp.y2),friction:ramp.friction))
  }
  return world
 }
 public enum LevelError: Error { case invalid }
}
