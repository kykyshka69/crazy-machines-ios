import Foundation

@main
struct OriginalBucketCollisionProxySmoke {
    static func main() {
        // Genuine bucket UCM measured bounds, NOT a copy of its proprietary
        // vertices/triangles. Assert open top and physical floor.
        let low: [Float] = [-0.202, -0.166, -0.1767]
        let high: [Float] = [0.202, 0.375, 0.1767]
        guard let panels = CMOriginalBucketCollisionProxy.panels(
            low: low, high: high
        ), panels.count == 3 else {
            preconditionFailure("Original bucket has no open collision shell")
        }
        let floor = panels[0], left = panels[1], right = panels[2]
        precondition(floor.center[1] < left.center[1])
        precondition(left.center[0] < 0 && right.center[0] > 0)
        precondition(left.size[1] == right.size[1])
        precondition(left.size[2] > 0.3)
        precondition(panels.allSatisfy { panel in
            panel.center.allSatisfy(\.isFinite)
                && panel.size.allSatisfy { $0.isFinite && $0 > 0 }
        })
        // Above the floor and between the side walls is actually EMPTY.
        // A full convex hull across this region made original level 4
        // unable to receive its tennis ball.
        let leftInner = left.center[0] + left.size[0] * 0.5
        let rightInner = right.center[0] - right.size[0] * 0.5
        precondition(leftInner < -0.13 && rightInner > 0.13)
        let ballRadius: Float = 0.108 // measured original UCM sphere radius
        precondition(rightInner - leftInner > ballRadius * 2)
        let rimY = left.center[1] + left.size[1] * 0.5
        let floorTop = floor.center[1] + floor.size[1] * 0.5
        precondition(rimY - floorTop > ballRadius * 2)
        // Degenerate and malicious bounds never create unstable physics.
        precondition(CMOriginalBucketCollisionProxy.panels(
            low: [0, 0, 0], high: [0, 1, 1]) == nil)
        precondition(CMOriginalBucketCollisionProxy.panels(
            low: [0, 0, 0], high: [.infinity, 1, 1]) == nil)
        precondition(CMOriginalBucketCollisionProxy.panels(
            low: [2, 0, 0], high: [1, 1, 1]) == nil)
        print("Original UCM bucket now has a physical open-top collision shell")
    }
}
