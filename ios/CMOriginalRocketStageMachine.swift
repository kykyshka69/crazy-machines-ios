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
        directionAndInitialVelocityUsable: Bool,
        projectedMagnifierHeatHit: Bool = false
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
            if candleHit || projectedBlowtorchHit || projectedMagnifierHeatHit {
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

/// The original Win32 terminal flight branch 0x44F2AD..0x44F354
/// emits the separate Explode effect, deactivates the rocket child,
/// removes its registered rigid body (0x428770), and only then fires
/// native GOAL. SceneKit must retire that physical child exactly once
/// instead of letting an already exploded rocket keep colliding.
/// Native GOAL is deliberately NOT inferred from this experimental
/// stage; this gate only controls playable visual/physics cleanup.
public struct CMOriginalRocketTerminalGate {
    private var deliveredChildIDs = Set<String>()
    public init() {}

    @discardableResult
    public mutating func consume(
        childID: String, phase: CMOriginalRocketStageMachine.Phase
    ) -> Bool {
        guard !childID.isEmpty, phase == .ended else { return false }
        return deliveredChildIDs.insert(childID).inserted
    }

    /// The original Win32 branch 0x44F33C→0x44F354 dispatches channel-0
    /// GOAL for the rocket parent ONLY after state 3 and Explode cleanup.
    /// iOS heat geometry is currently a SceneKit projection, so this
    /// yields an explicitly RECONSTRUCTED playable win, not proof that
    /// the native selector/effect runtime has reached identical values.
    /// Authentic UCM marker evidence is mandatory; a visual TGA file is
    /// optional and must never decide whether gameplay completes.
    public static func supportsReconstructedGoal(
        originalParentType: String,
        originalChildType: String,
        originalParentGoal: String?,
        phase: CMOriginalRocketStageMachine.Phase,
        genuineOriginalExplodeMarker: Bool,
        originalChildPhysicsRetired: Bool
    ) -> Bool {
        guard originalParentType == "tmo_heat_rocket",
              originalChildType == "tmo_heat_rocket_rocket",
              let originalParentGoal,
              let goal = Int(originalParentGoal.trimmingCharacters(
                in: .whitespacesAndNewlines)),
              goal != 0,
              phase == .ended,
              genuineOriginalExplodeMarker,
              originalChildPhysicsRetired else { return false }
        return true
    }
}
