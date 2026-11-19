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
  // Reject non-finite and out-of-bounds data before loading user levels.
  corrupt=decoded
  corrupt.gravity = .infinity
  do { _=try corrupt.makeWorld(); fatalError("Infinite gravity accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.balls[0].x = 7.01
  do { _=try corrupt.makeWorld(); fatalError("Out-of-bounds ball accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.balls[0].mass = .nan
  do { _=try corrupt.makeWorld(); fatalError("NaN mass accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.ramps[0].x2=corrupt.ramps[0].x1
  corrupt.ramps[0].y2=corrupt.ramps[0].y1
  do { _=try corrupt.makeWorld(); fatalError("Zero-length ramp accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.ramps[0].friction = -0.1
  do { _=try corrupt.makeWorld(); fatalError("Negative ramp friction accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.balls=Array(repeating:decoded.balls[0],count:21)
  do { _=try corrupt.makeWorld(); fatalError("Excessive ball count accepted") } catch CMLevelDocument.LevelError.invalid {}
  corrupt=decoded
  corrupt.ramps=Array(repeating:decoded.ramps[0],count:13)
  do { _=try corrupt.makeWorld(); fatalError("Excessive ramp count accepted") } catch CMLevelDocument.LevelError.invalid {}
  // Regression coverage: ten independent persistence invariants.
  let roundtrip=try JSONDecoder().decode(CMLevelDocument.self,from:JSONEncoder().encode(decoded))
  precondition(roundtrip.version == 1) // 1: schema version survives
  precondition(roundtrip.gravity == 12) // 2: gravity survives
  precondition(roundtrip.floorFriction == 0.6) // 3: floor friction survives
  precondition(roundtrip.balls[0].radius == 0.3) // 4: ball radius survives
  precondition(roundtrip.balls[0].restitution == 0.7) // 5: bounce survives
  precondition(roundtrip.balls[0].friction == 0.4) // 6: ball friction survives
  precondition(roundtrip.ramps[0].friction == 0.25) // 7: ramp friction survives
  corrupt=decoded
  corrupt.balls[0].restitution = 1.01
  do { _=try corrupt.makeWorld(); fatalError("Excessive restitution accepted") } catch CMLevelDocument.LevelError.invalid {} // 8
  corrupt=decoded
  corrupt.floorFriction = -0.01
  do { _=try corrupt.makeWorld(); fatalError("Negative floor friction accepted") } catch CMLevelDocument.LevelError.invalid {} // 9
  corrupt=decoded
  corrupt.ramps[0].y1 = -0.01
  do { _=try corrupt.makeWorld(); fatalError("Out-of-bounds ramp accepted") } catch CMLevelDocument.LevelError.invalid {} // 10
  let pinned=CMLevelDocument(world:world,pins:[CMPinJoint2D(bodyIndex:0,anchor:SIMD2(1.5,4))])
  let pinnedDecoded=try JSONDecoder().decode(CMLevelDocument.self,from:JSONEncoder().encode(pinned))
  let restoredPins=try pinnedDecoded.makePins()
  precondition(restoredPins.count == 1)
  precondition(restoredPins[0].anchor.x == 1.5)
  var invalidPin=pinnedDecoded
  invalidPin.pins?[0].bodyIndex=9
  do { _=try invalidPin.makeWorld(); fatalError("Invalid pin index accepted") } catch CMLevelDocument.LevelError.invalid {}
  invalidPin=pinnedDecoded
  invalidPin.pins?[0].x = -0.1
  do { _=try invalidPin.makeWorld(); fatalError("Invalid pin coordinate accepted") } catch CMLevelDocument.LevelError.invalid {}
  invalidPin=pinnedDecoded
  invalidPin.pins?.append(pinnedDecoded.pins![0])
  do { _=try invalidPin.makeWorld(); fatalError("Duplicate pin accepted") } catch CMLevelDocument.LevelError.invalid {}
  let legacyPins=try decoded.makePins()
  precondition(legacyPins.isEmpty)
  // Ten spring-document regression scenarios.
  var twoBodies=world
  twoBodies.bodies.append(CMPhysicsBody2D(position:SIMD2(3,4),radius:0.4))
  let linked=CMLevelDocument(world:twoBodies,springs:[
   CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1.5,stiffness:25,damping:3)
  ])
  let linkedDecoded=try JSONDecoder().decode(CMLevelDocument.self,from:JSONEncoder().encode(linked))
  // 1. Spring survives a JSON roundtrip.
  let loadedSprings=try linkedDecoded.makeSprings()
  precondition(loadedSprings.count == 1)
  // 2. Both endpoint indices survive.
  precondition(loadedSprings[0].firstIndex == 0 && loadedSprings[0].secondIndex == 1)
  // 3. Rest length survives.
  precondition(loadedSprings[0].restLength == 1.5)
  // 4. Stiffness and damping survive.
  precondition(loadedSprings[0].stiffness == 25 && loadedSprings[0].damping == 3)
  // 5. Legacy level without springs remains readable.
  let legacySprings=try decoded.makeSprings()
  precondition(legacySprings.isEmpty)
  // 6. Out-of-range endpoint is rejected.
  var invalidSpring=linkedDecoded
  invalidSpring.springs?[0].secondIndex=2
  do { _=try invalidSpring.makeWorld(); fatalError("Invalid spring endpoint accepted") } catch CMLevelDocument.LevelError.invalid {}
  // 7. Self-connection is rejected.
  invalidSpring=linkedDecoded
  invalidSpring.springs?[0].secondIndex=0
  do { _=try invalidSpring.makeWorld(); fatalError("Self spring accepted") } catch CMLevelDocument.LevelError.invalid {}
  // 8. Negative rest length is rejected.
  invalidSpring=linkedDecoded
  invalidSpring.springs?[0].restLength = -1
  do { _=try invalidSpring.makeWorld(); fatalError("Negative spring rest length accepted") } catch CMLevelDocument.LevelError.invalid {}
  // 9. Nonfinite damping is rejected.
  invalidSpring=linkedDecoded
  invalidSpring.springs?[0].damping = .infinity
  do { _=try invalidSpring.makeWorld(); fatalError("Infinite spring damping accepted") } catch CMLevelDocument.LevelError.invalid {}
  // 10. Reversed duplicate connection is rejected.
  invalidSpring=linkedDecoded
  invalidSpring.springs?.append(CMLevelDocument.Spring(firstIndex:1,secondIndex:0,restLength:1.5,stiffness:25,damping:3))
  do { _=try invalidSpring.makeWorld(); fatalError("Duplicate spring accepted") } catch CMLevelDocument.LevelError.invalid {}
  // Pivot persistence: roundtrip, compatibility, and invalid constraints.
  let pivotDocument=CMLevelDocument(world:twoBodies,pivots:[
   CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1,5),length:1)
  ])
  let pivotDecoded=try JSONDecoder().decode(CMLevelDocument.self,from:JSONEncoder().encode(pivotDocument))
  let pivotLoaded=try pivotDecoded.makePivots()
  precondition(pivotLoaded.count==1)
  precondition(pivotLoaded[0].bodyIndex==0)
  precondition(pivotLoaded[0].anchor == SIMD2(1,5))
  precondition(pivotLoaded[0].length==1)
  let legacyPivots=try decoded.makePivots()
  precondition(legacyPivots.isEmpty)
  var invalidPivot=pivotDecoded
  invalidPivot.pivots?[0].bodyIndex=20
  do { _=try invalidPivot.makeWorld(); fatalError("Invalid pivot index accepted") } catch CMLevelDocument.LevelError.invalid {}
  invalidPivot=pivotDecoded
  invalidPivot.pivots?[0].length=0
  do { _=try invalidPivot.makeWorld(); fatalError("Zero pivot length accepted") } catch CMLevelDocument.LevelError.invalid {}
  invalidPivot=pivotDecoded
  invalidPivot.pivots?[0].x = .infinity
  do { _=try invalidPivot.makeWorld(); fatalError("Infinite pivot anchor accepted") } catch CMLevelDocument.LevelError.invalid {}
  invalidPivot=pivotDecoded
  invalidPivot.pivots?.append(pivotDecoded.pivots![0])
  do { _=try invalidPivot.makeWorld(); fatalError("Duplicate pivot accepted") } catch CMLevelDocument.LevelError.invalid {}
  invalidPivot=pivotDecoded
  invalidPivot.pins=[CMLevelDocument.Pin(bodyIndex:0,x:1,y:4)]
  do { _=try invalidPivot.makeWorld(); fatalError("Pin and pivot conflict accepted") } catch CMLevelDocument.LevelError.invalid {}
  print("Level document roundtrip and validation passed")
 }
}
