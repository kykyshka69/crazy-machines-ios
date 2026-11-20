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

    /// Explicitly configured experimental behaviors, never inferred from
    /// original GOAL markers or object names.
    public struct ReactionRule: Equatable {
        public enum Trigger: Equatable {
            case firstContact
            case everyContact
        }
        public enum Action: Equatable {
            case impulse(x: Double, y: Double, z: Double)
            case activate(String)
        }
        public let objectID: String
        public let trigger: Trigger
        public let action: Action

        public init(objectID: String, trigger: Trigger, action: Action) {
            self.objectID = objectID
            self.trigger = trigger
            self.action = action
        }
    }

    public struct PendingAction: Equatable {
        public let sourceID: String
        public let action: ReactionRule.Action
        public let simulationTime: TimeInterval
    }

    public private(set) var reactionRules: [ReactionRule] = []
    private var actionQueue: [PendingAction] = []

    public mutating func configureReactions(_ rules: [ReactionRule]) {
        let ids = Set(objects.map(\.id))
        reactionRules = Array(rules.prefix(512)).filter { rule in
            guard ids.contains(rule.objectID) else { return false }
            switch rule.action {
            case .activate(let target): return ids.contains(target)
            case .impulse(let x, let y, let z):
                return [x, y, z].allSatisfy { $0.isFinite && abs($0) <= 1000 }
            }
        }
        actionQueue.removeAll()
    }

    /// Expand explicit activation links into executable actions. Each target
    /// activates once per run, preventing cycles from looping forever.
    /// Only impulse actions reach SceneKit; links are resolved in the engine.
    public mutating func resolveActions() -> [PendingAction] {
        guard phase == .running else { return [] }
        releaseDueActions()
        var impulses: [PendingAction] = []
        var processed = 0
        while !actionQueue.isEmpty && processed < 512 {
            let pending = actionQueue.removeFirst()
            processed += 1
            switch pending.action {
            case .impulse:
                impulses.append(pending)
            case .activate(let target):
                guard activatedObjectIDs.insert(target).inserted else { continue }
                activations.append(Activation(objectID: target,
                                              triggeredBy: pending.sourceID,
                                              impulse: 0,
                                              simulationTime: elapsedSimulationTime))
                enqueueReactions(for: target, firstContact: true)
            }
        }
        // Never carry an unbounded chain across frames.
        if processed >= 512 { actionQueue.removeAll() }
        return impulses
    }

    /// Explicit time-driven mechanism: schedule a reaction after a simulation
    /// delay. The timer freezes while paused and is cleared on restart.
    public struct ScheduledAction: Equatable {
        public let dueTime: TimeInterval
        public let sourceID: String
        public let action: ReactionRule.Action
    }

    public private(set) var scheduledActions: [ScheduledAction] = []

    @discardableResult
    public mutating func schedule(_ action: ReactionRule.Action,
                                  from sourceID: String,
                                  after delay: TimeInterval) -> Bool {
        guard phase == .running,
              objects.contains(where: { $0.id == sourceID }),
              delay.isFinite, delay >= 0, delay <= 3600,
              scheduledActions.count < 512 else { return false }
        switch action {
        case .activate(let target):
            guard objects.contains(where: { $0.id == target }) else { return false }
        case .impulse(let x, let y, let z):
            guard [x, y, z].allSatisfy({ $0.isFinite && abs($0) <= 1000 }) else { return false }
        }
        scheduledActions.append(ScheduledAction(dueTime: elapsedSimulationTime + delay,
                                                sourceID: sourceID, action: action))
        return true
    }

    private mutating func releaseDueActions() {
        var remaining: [ScheduledAction] = []
        for item in scheduledActions {
            if item.dueTime <= elapsedSimulationTime && actionQueue.count < 512 {
                actionQueue.append(PendingAction(sourceID: item.sourceID,
                                                 action: item.action,
                                                 simulationTime: elapsedSimulationTime))
            } else {
                remaining.append(item)
            }
        }
        scheduledActions = remaining
    }

    /// Consume once; SceneKit may execute these actions on its renderer thread.
    public mutating func drainActions() -> [PendingAction] {
        let actions = actionQueue
        actionQueue.removeAll()
        return actions
    }

    private mutating func enqueueReactions(for id: String, firstContact: Bool) {
        for rule in reactionRules where rule.objectID == id {
            if rule.trigger == .firstContact && !firstContact { continue }
            if actionQueue.count >= 512 { break }
            actionQueue.append(PendingAction(sourceID: id, action: rule.action,
                                             simulationTime: elapsedSimulationTime))
        }
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
            let first = activatedObjectIDs.insert(target).inserted
            if first {
                activations.append(Activation(objectID: target, triggeredBy: source,
                                              impulse: impulse,
                                              simulationTime: elapsedSimulationTime))
            }
            enqueueReactions(for: target, firstContact: first)
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
        actionQueue.removeAll()
        scheduledActions.removeAll()
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
        actionQueue.removeAll()
        scheduledActions.removeAll()
        phase = .ready
    }

    /// Intentionally no inferred 'completed' phase: GOAL 1 alone does not
    /// tell us how the original puzzle decides success.
}
