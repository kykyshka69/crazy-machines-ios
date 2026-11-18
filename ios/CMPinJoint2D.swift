import Foundation

/// A fixed world-space pin. This is a position-only constraint for a disk,
/// not yet a motor, rigid linkage, or full angular joint.
public struct CMPinJoint2D {
 public var bodyIndex: Int
 public var anchor: SIMD2<Double>
 public init(bodyIndex:Int, anchor:SIMD2<Double>) {
  self.bodyIndex=bodyIndex; self.anchor=anchor
 }
}

public extension CMPhysicsWorld2D {
 /// Constrain selected disk centers to static pins after a physics step.
 /// Returns the number of valid constraints applied.
 @discardableResult
 mutating func applyPins(_ pins:[CMPinJoint2D]) -> Int {
  var count=0
  for pin in pins {
   guard bodies.indices.contains(pin.bodyIndex),
         pin.anchor.x.isFinite, pin.anchor.y.isFinite else { continue }
   let i=pin.bodyIndex
   guard bodies[i].mass.isFinite,bodies[i].mass > 0 else { continue }
   bodies[i].position=pin.anchor
   bodies[i].velocity = .zero
   count += 1
  }
  return count
 }
}
