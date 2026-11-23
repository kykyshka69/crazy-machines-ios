import Foundation

@main
struct OriginalRocketAnchorTelemetrySmoke {
    static func main() {
        typealias T = CMOriginalRocketAnchorTelemetry
        func frame(_ name: String, _ id: String = "original-rocket-child",
                   _ position: T.Vector3 = .init(0, 0, 0),
                   _ axis: T.Vector3 = .init(0, 1, 0),
                   originalName: String? = nil) -> T.Frame {
            .init(rocketChildID: id, name: name,
                  originalUCMMarkerName: originalName ?? name,
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
        precondition(T.originalName(inSceneNodeName:
            "original-ucm-anchor-Heat-5") == "Heat")
        precondition(T.originalName(inSceneNodeName:
            "original-ucm-anchor-heat-5") == "heat")
        precondition(T.originalName(inSceneNodeName:
            "original-ucm-anchor-Engine-1") == "Engine")
        precondition(T.originalName(inSceneNodeName:
            "original-ucm-anchor-Heat-1-3") == "Heat-1")
        for bad in ["original-ucm-anchor-Heat", "original-ucm-anchor-Heat-",
                    "original-ucm-anchor-Heat-001", "original-ucm-anchor-Heat-a",
                    "original-ucm-anchor-Heat--1", "other-prefix-Heat-1",
                    "original-ucm-anchor--1", "original-ucm-anchor-Тепло-1"] {
            if bad == "original-ucm-anchor-Heat--1" {
                // A suffix after the final separator is canonical 1;
                // its original name is actually `Heat-`, NOT `Heat`.
                precondition(T.originalName(inSceneNodeName: bad) == "Heat-")
            } else {
                precondition(T.originalName(inSceneNodeName: bad) == nil)
            }
        }
        precondition(good?.heat.originalUCMMarkerName == "Heat")
        for mismatchedName in ["Light", "Wind", "heat", "", "Heat01"] {
            let spoofed = [frame("Heat", originalName: mismatchedName)]
                + Array(realBasis.dropFirst())
            precondition(T.complete(rocketChildID: "original-rocket-child",
                originalParentType: "tmo_heat_rocket", frames: spoofed) == nil)
        }
        let fakeEngine = [frame("Heat"),
            frame("Engine", originalName: "Light")]
            + Array(realBasis.dropFirst(2))
        precondition(T.complete(rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket", frames: fakeEngine) == nil)
        precondition(good?.engine.worldYAxis == .init(0, 0, 1))
        precondition(good?.worldDynamicBodyCenter == nil)
        let center = T.Vector3(0.25, 0.5, 0)
        let withCOM = T.complete(
            rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket",
            frames: realBasis, observedDynamicBodyCenter: center)
        precondition(withCOM?.worldDynamicBodyCenter == center)
        precondition(T.complete(
            rocketChildID: "original-rocket-child",
            originalParentType: "tmo_heat_rocket",
            frames: realBasis,
            observedDynamicBodyCenter: .init(.infinity, 0, 0)) == nil)
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
