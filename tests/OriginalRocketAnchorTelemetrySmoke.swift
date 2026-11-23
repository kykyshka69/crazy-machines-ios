import Foundation

@main
struct OriginalRocketAnchorTelemetrySmoke {
    static func main() {
        typealias T = CMOriginalRocketAnchorTelemetry
        func frame(_ name: String, _ id: String = "original-rocket-child",
                   _ position: T.Vector3 = .init(0, 0, 0),
                   _ axis: T.Vector3 = .init(0, 1, 0)) -> T.Frame {
            .init(rocketChildID: id, name: name,
                  worldOrigin: position, worldYAxis: axis)
        }
        // Actual owner UCM rocket Engine and Direction markers point
        // along opposing Z axes. Both are legitimate 3D local-Y frames.
        let realBasis = [frame("Heat"),
                         frame("Engine", "original-rocket-child", .init(0, 0, 0), .init(0, 0, 1)),
                         frame("Explode", "original-rocket-child", .init(0, 0, 0), .init(0, 0, -1)),
                         frame("Direction", "original-rocket-child", .init(0, 0, 0), .init(0, 0, -1)),
                         frame("Rope")]
        let good = T.complete(rocketChildID: "original-rocket-child",
                              originalParentType: "tmo_heat_rocket", frames: realBasis)
        precondition(good != nil && good?.direction.name == "Direction")
        precondition(good?.engine.worldYAxis == .init(0, 0, 1))
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_candle", frames: realBasis) == nil)
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket", frames: Array(realBasis.dropLast(2))) == nil)
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket",
            frames: realBasis + [frame("Heat")]) == nil)
        let wrongOwner = [frame("Heat", "unrelated")] + Array(realBasis.dropFirst())
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket", frames: wrongOwner) == nil)
        let nonfinite = [frame("Heat", "original-rocket-child", .init(.nan, 0, 0))]
            + Array(realBasis.dropFirst())
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket", frames: nonfinite) == nil)
        let missingAxis = [frame("Heat", "original-rocket-child",
                                 .init(0, 0, 0), .init(0, 0, 0))]
            + Array(realBasis.dropFirst())
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket", frames: missingAxis) == nil)
        precondition(T.complete(rocketChildID: "",
            originalParentType: "tmo_heat_rocket", frames: realBasis) == nil)
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket",
            frames: Array(repeating: frame("Rope"), count: 65)) == nil)
        print("Real rocket UCM telemetry: four unique named world frames, real Z-only axis, fail-closed OK")
    }
}
