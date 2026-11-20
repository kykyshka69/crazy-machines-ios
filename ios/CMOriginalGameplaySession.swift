import Foundation

/// Engine-independent foundation for original-level gameplay.
/// This is an authoritative object registry and lifecycle, NOT a claim that
/// GOAL annotations define the original game's win condition.
public struct CMOriginalGameplaySession {
    public enum Phase: Equatable {
        case ready
        case running
        case paused
        case stopped
    }

    public struct Object: Equatable, Identifiable {
        public let id: String
        public let type: String
        public let models: [String]
        public let fields: [String: [String]]
        public let goalAnnotation: String?
        public let position: [Double]?
        public let parentID: String?
    }

    public let levelIndex: Int
    public let sceneSHA256: String
    public let objects: [Object]
    public private(set) var phase: Phase = .ready
    public private(set) var elapsedSimulationTime: TimeInterval = 0

    public init(document: CMOriginalSceneDocument) {
        levelIndex = document.index
        sceneSHA256 = document.sceneSHA256
        var collected: [Object] = []
        var ordinal = 0

        func visit(_ node: CMOriginalSceneDocument.Node, parentObjectID: String?) {
            var owner = parentObjectID
            if node.name.hasPrefix("tmo_") {
                // Preorder indices are stable for a given exported scene and
                // disambiguate repeated object types without hashing fields.
                let id = "object-\(ordinal)"
                ordinal += 1
                owner = id
                var models = node.models ?? []
                for child in node.children where child.name.hasPrefix("3DO ") {
                    let model = String(child.name.dropFirst(4))
                    if !models.contains(model) { models.append(model) }
                }
                collected.append(Object(
                    id: id,
                    type: node.name,
                    models: models,
                    fields: node.originalFieldValues,
                    goalAnnotation: node.goalRaw,
                    position: node.positionRelative ?? node.position,
                    parentID: parentObjectID
                ))
            }
            for child in node.children { visit(child, parentObjectID: owner) }
        }
        visit(document.root, parentObjectID: nil)
        objects = collected
    }

    public var annotatedGoalObjects: [Object] {
        objects.filter { $0.goalAnnotation == "1" }
    }

    public mutating func start() {
        guard phase == .ready || phase == .stopped else { return }
        elapsedSimulationTime = 0
        phase = .running
    }

    public mutating func pause() {
        guard phase == .running else { return }
        phase = .paused
    }

    public mutating func resume() {
        guard phase == .paused else { return }
        phase = .running
    }

    public mutating func advance(by delta: TimeInterval) {
        guard phase == .running, delta.isFinite, delta > 0 else { return }
        elapsedSimulationTime += delta
    }

    public mutating func stop() {
        phase = .stopped
    }

    public mutating func reset() {
        elapsedSimulationTime = 0
        phase = .ready
    }

    /// Intentionally no inferred 'completed' phase: GOAL 1 alone does not
    /// tell us how the original puzzle decides success.
}
