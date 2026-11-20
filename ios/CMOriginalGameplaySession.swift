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

    /// Experimental contact-driven activation graph. It tracks which imported
    /// objects have physically interacted; it does not infer puzzle success.
    public struct Activation: Equatable {
        public let objectID: String
        public let triggeredBy: String
        public let impulse: Double
        public let simulationTime: TimeInterval
    }

    public private(set) var activations: [Activation] = []
    public private(set) var activatedObjectIDs: Set<String> = []

    public var contactedGoalObjectIDs: Set<String> {
        let goals = Set(annotatedGoalObjects.map(\.id))
        return activatedObjectIDs.intersection(goals)
    }

    public struct Contact: Equatable {
        public let objectA: String
        public let objectB: String
        public let impulse: Double
        public let simulationTime: TimeInterval
    }

    public private(set) var recentContacts: [Contact] = []
    public private(set) var contactCounts: [String: Int] = [:]

    /// Collision telemetry only: not an inferred original win condition.
    public mutating func recordContact(_ a: String, _ b: String, impulse: Double) {
        guard phase == .running, a != b, impulse.isFinite, impulse >= 0,
              objects.contains(where: { $0.id == a }),
              objects.contains(where: { $0.id == b }) else { return }
        let pair = [a, b].sorted()
        let key = pair.joined(separator: "|")
        contactCounts[key, default: 0] += 1
        recentContacts.append(Contact(objectA: pair[0], objectB: pair[1],
                                      impulse: impulse,
                                      simulationTime: elapsedSimulationTime))
        // First valid contact activates each endpoint once. Future object
        // handlers can subscribe to these transitions, independent of physics.
        for (target, source) in [(a, b), (b, a)] {
            if activatedObjectIDs.insert(target).inserted {
                activations.append(Activation(objectID: target, triggeredBy: source,
                                              impulse: impulse,
                                              simulationTime: elapsedSimulationTime))
            }
        }
        if recentContacts.count > 256 {
            recentContacts.removeFirst(recentContacts.count - 256)
        }
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
        recentContacts.removeAll()
        contactCounts.removeAll()
        activations.removeAll()
        activatedObjectIDs.removeAll()
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
        recentContacts.removeAll()
        contactCounts.removeAll()
        activations.removeAll()
        activatedObjectIDs.removeAll()
        phase = .ready
    }

    /// Intentionally no inferred 'completed' phase: GOAL 1 alone does not
    /// tell us how the original puzzle decides success.
}
