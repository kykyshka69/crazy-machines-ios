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
 public struct Pin: Codable {
  public var bodyIndex: Int
  public var x: Double
  public var y: Double
 }
 public struct Spring: Codable {
  public var firstIndex: Int
  public var secondIndex: Int
  public var restLength: Double
  public var stiffness: Double
  public var damping: Double
 }
 public struct Pivot: Codable {
  public var bodyIndex: Int
  public var x: Double
  public var y: Double
  public var length: Double
 }
 public var pivots: [Pivot]?
 public var springs: [Spring]?
 public var pins: [Pin]?
 public var version: Int
 public var gravity: Double
 public var floorFriction: Double
 public var balls: [Ball]
 public var ramps: [Ramp]
 public init(world: CMPhysicsWorld2D, pins: [CMPinJoint2D] = [], springs: [CMSpringJoint2D] = [], pivots: [CMPivotJoint2D] = []) {
  self.pivots=pivots.map { Pivot(bodyIndex:$0.bodyIndex,x:$0.anchor.x,y:$0.anchor.y,length:$0.length) }
  self.springs=springs.map { Spring(firstIndex:$0.firstIndex,secondIndex:$0.secondIndex,restLength:$0.restLength,stiffness:$0.stiffness,damping:$0.damping) }
  self.pins=pins.map { Pin(bodyIndex:$0.bodyIndex,x:$0.anchor.x,y:$0.anchor.y) }
  version=1
  gravity = -world.gravity.y
  floorFriction=world.floorFriction
  balls=world.bodies.map { Ball(x:$0.position.x,y:$0.position.y,radius:$0.radius,restitution:$0.restitution,mass:$0.mass,friction:$0.surfaceFriction) }
  ramps=world.segments.map { Ramp(x1:$0.start.x,y1:$0.start.y,x2:$0.end.x,y2:$0.end.y,friction:$0.friction) }
 }
 public func makeWorld() throws -> CMPhysicsWorld2D {
  guard version == 1, gravity.isFinite, (0...20).contains(gravity),
   floorFriction.isFinite, (0...10).contains(floorFriction),
   balls.count <= 20, ramps.count <= 12,
   (pins ?? []).count <= 20, (springs ?? []).count <= 20, (pivots ?? []).count <= 20 else { throw LevelError.invalid }
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
    (0...10).contains(ramp.friction),
    (ramp.x2-ramp.x1)*(ramp.x2-ramp.x1)+(ramp.y2-ramp.y1)*(ramp.y2-ramp.y1) >= 1e-8 else { throw LevelError.invalid }
   world.segments.append(CMStaticSegment2D(start:SIMD2(ramp.x1,ramp.y1),end:SIMD2(ramp.x2,ramp.y2),friction:ramp.friction))
  }
  let attached=pins ?? []
  var occupied=Set<Int>()
  for pin in attached {
   guard world.bodies.indices.contains(pin.bodyIndex),
    pin.x.isFinite,pin.y.isFinite,(0...7).contains(pin.x),(0...6).contains(pin.y),
    occupied.insert(pin.bodyIndex).inserted else { throw LevelError.invalid }
  }
  for pivot in pivots ?? [] {
   guard world.bodies.indices.contains(pivot.bodyIndex),
    pivot.x.isFinite,pivot.y.isFinite,
    (0...7).contains(pivot.x),(0...6).contains(pivot.y),
    pivot.length.isFinite,(0.01...10).contains(pivot.length),
    occupied.insert(pivot.bodyIndex).inserted else { throw LevelError.invalid }
  }
  var pairs=Set<String>()
  for spring in springs ?? [] {
   guard world.bodies.indices.contains(spring.firstIndex),
    world.bodies.indices.contains(spring.secondIndex),
    spring.firstIndex != spring.secondIndex,
    spring.restLength.isFinite,(0...10).contains(spring.restLength),
    spring.stiffness.isFinite,(0...1000).contains(spring.stiffness),
    spring.damping.isFinite,(0...100).contains(spring.damping) else { throw LevelError.invalid }
   let pair="\(min(spring.firstIndex,spring.secondIndex))-\(max(spring.firstIndex,spring.secondIndex))"
   guard pairs.insert(pair).inserted else { throw LevelError.invalid }
  }
  return world
 }
 public func makePivots() throws -> [CMPivotJoint2D] {
  _ = try makeWorld()
  return (pivots ?? []).map { CMPivotJoint2D(bodyIndex:$0.bodyIndex,anchor:SIMD2($0.x,$0.y),length:$0.length) }
 }
 public func makeSprings() throws -> [CMSpringJoint2D] {
  _ = try makeWorld()
  return (springs ?? []).map {
   CMSpringJoint2D(firstIndex:$0.firstIndex,secondIndex:$0.secondIndex,
    restLength:$0.restLength,stiffness:$0.stiffness,damping:$0.damping)
  }
 }
 public func makePins() throws -> [CMPinJoint2D] {
  _ = try makeWorld()
  return (pins ?? []).map { CMPinJoint2D(bodyIndex:$0.bodyIndex,anchor:SIMD2($0.x,$0.y)) }
 }
 public enum LevelError: Error { case invalid }
}
