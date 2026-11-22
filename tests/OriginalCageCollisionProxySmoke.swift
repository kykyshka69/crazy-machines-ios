import Foundation

@main
struct OriginalCageCollisionProxySmoke {
    static func main() {
        // Genuine private owner's rope_cage.UCM version2 measured bounds;
        // SHA256 402c793b0d334fc8ffa2f14cef3e726dadb9e7c665929c7ddf692d81c6d591f4.
        let low: [Float] = [-0.32006252, -0.20067988, -0.32006252]
        let high: [Float] = [0.32006252, 0.4354235, 0.32006252]
        guard let p = CMOriginalCageCollisionProxy.panels(
            low: low, high: high) else {
            preconditionFailure("Real original cage mesh should have panels")
        }
        precondition(p.count == 3)
        let floor = p[0], left = p[1], right = p[2]
        precondition(floor.rotationZ == 0)
        precondition(left.rotationZ < 0 && right.rotationZ > 0)
        precondition(abs(left.rotationZ + right.rotationZ) < 1e-6)
        precondition(abs(left.center[0] + right.center[0]) < 1e-6)
        precondition(abs(left.center[1] - right.center[1]) < 1e-6)
        precondition(abs(left.size[1] - right.size[1]) < 1e-6)
        precondition(floor.size[0] > 0.5)
        precondition(floor.size[1] > 0 && floor.size[1] < 0.08)
        // The authentic UCM's tall raised handle is NOT a lid.
        let wallMouth = left.center[1]
            + abs(cos(left.rotationZ)) * left.size[1] * 0.5
        precondition(wallMouth < high[1] - 0.11)
        precondition(wallMouth > 0.25)
        // The cage remains open at the top. No convex-hull cap.
        let floorTop = floor.center[1] + floor.size[1] * 0.5
        precondition(floorTop < 0)
        precondition(floorTop < wallMouth)
        precondition(CMOriginalCageCollisionProxy.panels(
            low: [0, 0, 0], high: [0, 1, 1]) == nil)
        precondition(CMOriginalCageCollisionProxy.panels(
            low: [0, 0, 0], high: [1, 1, .nan]) == nil)
        precondition(CMOriginalCageCollisionProxy.panels(
            low: [0, 0], high: [1, 1]) == nil)
        print("Real original rope_cage.UCM open-wall collider: floor, angled sides, no solid roof")
    }
}
