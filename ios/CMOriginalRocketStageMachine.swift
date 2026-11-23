import Foundation

/// SceneKit PLAYBACK sequence driven by actual original UCM geometry.
/// It is NOT the original Win32 native selector/Engine/GOAL state machine.
public struct CMOriginalRocketStageMachine {
    public enum Phase: Int, Equatable {
        case mounted = 0
        case fuse = 1
        case flying = 2
        case ended = 3
    }

    public private(set) var phase: Phase = .mounted
    public private(set) var ignitionTime: Double?
    public private(set) var launchTime: Double?
    private var lastTime: Double?

    public init() {}

    /// Original constants from PE32: heat >0x3F570A3D and two independent
    /// strictly >3-second clocks. Projection/effect state remains the
    /// explicitly experimental SceneKit reconstruction.
    @discardableResult
    public mutating func advance(
        time: Double,
        projectedCandleHeat: Float?,
        projectedBlowtorchHit: Bool,
        rocketBodyPresent: Bool,
        directionAndInitialVelocityUsable: Bool
    ) -> Phase {
        guard time.isFinite, time >= 0,
              (lastTime.map { time >= $0 } ?? true) else { return phase }
        lastTime = time
        switch phase {
        case .mounted:
            let candleHit = projectedCandleHeat.map {
                $0.isFinite && $0 >= 0 && $0 <= 1
                    && $0 > Float(bitPattern: 0x3F570A3D)
            } ?? false
            if candleHit || projectedBlowtorchHit {
                phase = .fuse
                ignitionTime = time
            }
        case .fuse:
            if let ignitionTime, time - ignitionTime > 3,
               rocketBodyPresent, directionAndInitialVelocityUsable {
                phase = .flying
                launchTime = time
            }
        case .flying:
            if let launchTime, time - launchTime > 3 {
                phase = .ended
            }
        case .ended:
            break
        }
        return phase
    }
}
