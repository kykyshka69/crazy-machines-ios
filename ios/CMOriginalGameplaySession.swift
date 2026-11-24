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

    /// Player-operated positions of genuine original PC switch objects.
    /// A switch being ON does not imply current, wires or motor power:
    /// the original electrical network has not yet been recovered.
    public private(set) var originalSwitchStates: [String: Bool] = [:]
    // Win32 0x434A9A..0x434AE6: user-operated pocketlamp stores an
    // exact 0 or 1 scalar in the original element +0xEC. This source
    // state is separate from its native light-ray orientation and GOAL.
    public private(set) var originalPocketLampStates: [String: Bool] = [:]
    // Native 0x4349A0..0x434A20: tmo_candle, tmo_candle_dyn and
    // tmo_heat_blowtorch user click stores exact 0 or 1 at +0xEC.
    // It is not itself proof of ignition, heat transfer, or GOAL.
    public private(set) var originalHeatSourceStates: [String: Bool] = [:]

    private static func isUserOperatedHeatSource(_ type: String) -> Bool {
        type == "tmo_candle" || type == "tmo_candle_dyn"
            || type == "tmo_heat_blowtorch"
    }

    private var authoredHeatSourceStates: [String: Bool] {
        Dictionary(uniqueKeysWithValues: objects.compactMap {
            object -> (String, Bool)? in
            guard Self.isUserOperatedHeatSource(object.type),
                  let raw = object.fields["VALF"]?.first,
                  let initial = Float(raw.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  )), initial == 1 else { return nil }
            return (object.id, true)
        })
    }

    /// The owner's original level 92 has VALF 1.000000 on one genuine
    /// tmo_light_pocketlamp. Retain that authored starting source state,
    /// while all absent VALF pocketlamps start at 0.
    private var authoredPocketLampStates: [String: Bool] {
        Dictionary(uniqueKeysWithValues: objects.compactMap {
            object -> (String, Bool)? in
            guard object.type == "tmo_light_pocketlamp",
                  let raw = object.fields["VALF"]?.first,
                  let value = Float(raw.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  )), value == 1 else { return nil }
            return (object.id, true)
        })
    }

    /// Win32 0x434903 checks interaction flag 0x10; 0x4349A0 then
    /// toggles candle/dynamic candle/blowtorch source +0xEC.
    /// The native +0xF0 GOAL comparison is a SEPARATE condition.
    @discardableResult
    public mutating func toggleOriginalHeatSource(_ id: String) -> Bool? {
        guard phase == .running,
              let object = objects.first(where: { $0.id == id }),
              Self.isUserOperatedHeatSource(object.type) else { return nil }
        // User-authored VALB overrides take precedence over FSC defaults.
        // All real click-enabled candle and blowtorch CML entries have
        // their original interactive 0x10 bit set.
        if let raw = object.fields["VALB"]?.first,
           let bits = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           bits & 0x10 == 0 { return nil }
        let next = !(originalHeatSourceStates[id] ?? false)
        if next {
            originalHeatSourceStates[id] = true
        } else {
            originalHeatSourceStates.removeValue(forKey: id)
        }
        return next
    }

    /// Native focused heat 0x44CD30 directly sets candle +0xEC to 1,
    /// without the click handler's VALB & 0x10 gate. Wind and tilt
    /// instead call 0x4348F0 and must retain the separate click gate.
    @discardableResult
    public mutating func igniteOriginalCandleFromFocus(_ id: String) -> Bool {
        guard phase == .running,
              objects.contains(where: {
                  $0.id == id && ($0.type == "tmo_candle" || $0.type == "tmo_candle_dyn")
              }),
              originalHeatSourceStates[id] != true else { return false }
        originalHeatSourceStates[id] = true
        return true
    }

    /// Authentic Win32 0x434A9A..0x434AE6: pocketlamp +0xEC 0<->1.
    /// Its native +0xF0 GOAL comparison is not inferred from the tap.
    @discardableResult
    public mutating func toggleOriginalPocketLamp(_ id: String) -> Bool? {
        guard phase == .running,
              let object = objects.first(where: {
                  $0.id == id && $0.type == "tmo_light_pocketlamp"
              }) else { return nil }
        // Native Win32 click gate 0x434903 checks interaction flag 0x10.
        // All 11 original PC pocketlamps have VALB 176 (bit 0x10 set).
        // Explicit disabled/malformed per-scene overrides must never be
        // turned on merely because the object is a pocketlamp.
        if let raw = object.fields["VALB"]?.first {
            guard let bits = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                  bits & 0x10 != 0 else { return nil }
        }
        let next = !(originalPocketLampStates[id] ?? false)
        if next {
            originalPocketLampStates[id] = true
        } else {
            originalPocketLampStates.removeValue(forKey: id)
        }
        return next
    }

    /// Tap the imported PC electrical switch only in running phase.
    /// This optional circuit prototype does not fabricate Win32 +0xEC/+0xC8
    /// contacts or a native GOAL event.
    @discardableResult
    /// Original engine 0x45523B...0x455241 snapshots physical +0xEC
    /// into immutable per-run +0xF0 BEFORE player input. Its click handler
    /// compares the current +0xEC against that snapshot using fucompp,
    /// test ah,0x44 / jnp (0x434A5C or 0x434AFC); an unequal valid 0/1
    /// pair dispatches channel-0 GOAL. The scene's authored VALF is the
    /// initial source +0xEC, so 0/1 comparisons have exact equivalence.
    /// This is NOT a heat transfer or ray-hit event.
    public func nativeClickedSourceGoalSatisfied(_ id: String) -> Bool? {
        guard phase == .running,
              let object = objects.first(where: { $0.id == id }),
              object.goalAnnotation == "1"
                  || object.fields["GOAL"]?.contains("1") == true
        else { return nil }
        if Self.isUserOperatedHeatSource(object.type) {
            let initial = authoredHeatSourceStates[id] ?? false
            let current = originalHeatSourceStates[id] ?? false
            return current != initial
        }
        if object.type == "tmo_light_pocketlamp" {
            let initial = authoredPocketLampStates[id] ?? false
            let current = originalPocketLampStates[id] ?? false
            return current != initial
        }
        return nil
    }

    public mutating func toggleOriginalSwitch(_ id: String) -> Bool? {
        guard phase == .running,
              objects.contains(where: { $0.id == id && $0.type == "tmo_power_switch" })
        else { return nil }
        let isOn = !(originalSwitchStates[id] ?? false)
        if isOn {
            originalSwitchStates[id] = true
        } else {
            originalSwitchStates.removeValue(forKey: id)
        }
        return isOn
    }

    public var contactedGoalObjectIDs: Set<String> {
        let goals = Set(annotatedGoalObjects.map(\.id))
        return activatedObjectIDs.intersection(goals)
    }

    /// Explicitly configured experimental behaviors, never inferred from
    /// original GOAL markers or object names.
    /// Explicit experimental physics roles. Imported objects default to
    /// dynamic until a level-specific configuration is supplied; no role is
    /// inferred from original object names or GOAL annotations.
    public enum PhysicsRole: Equatable {
        case fixed
        case movable
        case sensor
    }

    public private(set) var physicsRoles: [String: PhysicsRole] = [:]

    public mutating func configurePhysicsRoles(_ roles: [String: PhysicsRole]) {
        physicsRoles = roles.filter { validObjectIDs.contains($0.key) }
    }

    public func physicsRole(for id: String) -> PhysicsRole {
        physicsRoles[id] ?? .movable
    }

    public struct ReactionRule: Equatable {
        public enum Trigger: Equatable {
            case firstContact
            case everyContact
        }
        public enum Action: Equatable {
            case impulse(x: Double, y: Double, z: Double)
            case activate(String)
            case impulseTarget(id: String, x: Double, y: Double, z: Double)
        }
        public let objectID: String
        public let trigger: Trigger
        public let action: Action
        public let delay: TimeInterval

        public init(objectID: String, trigger: Trigger, action: Action,
                    delay: TimeInterval = 0) {
            self.objectID = objectID
            self.trigger = trigger
            self.action = action
            self.delay = delay
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
        let ids = validObjectIDs
        reactionRules = Array(rules.prefix(512)).filter { rule in
            guard ids.contains(rule.objectID),
                  rule.delay.isFinite, rule.delay >= 0,
                  rule.delay <= 3600 else { return false }
            switch rule.action {
            case .activate(let target): return ids.contains(target)
            case .impulseTarget(let id, let x, let y, let z):
                return ids.contains(id) && [x, y, z].allSatisfy { $0.isFinite && abs($0) <= 1000 }
            case .impulse(let x, let y, let z):
                return [x, y, z].allSatisfy { $0.isFinite && abs($0) <= 1000 }
            }
        }
        actionQueue.removeAll()
        scheduledActions.removeAll()
    }

    /// Expand explicit activation links into executable actions. Each target
    /// activates once per run, preventing cycles from looping forever.
    /// Only impulse actions reach SceneKit; links are resolved in the engine.
    public mutating func resolveActions() -> [PendingAction] {
        guard phase == .running else { return [] }
        releaseDueActions()
        var impulses: [PendingAction] = []
        var processed = 0
        var cursor = 0
        while cursor < actionQueue.count && processed < 512 {
            let pending = actionQueue[cursor]
            cursor += 1
            processed += 1
            switch pending.action {
            case .impulse, .impulseTarget:
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
        // Retain any work beyond the per-frame budget for the next frame.
        // Avoid repeated removeFirst() array shifts for large reaction chains.
        actionQueue.removeFirst(cursor)
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
              validObjectIDs.contains(sourceID),
              delay.isFinite, delay >= 0, delay <= 3600,
              scheduledActions.count < 512 else { return false }
        switch action {
        case .activate(let target):
            guard validObjectIDs.contains(target) else { return false }
        case .impulseTarget(let id, let x, let y, let z):
            guard validObjectIDs.contains(id),
                  [x, y, z].allSatisfy({ $0.isFinite && abs($0) <= 1000 }) else { return false }
        case .impulse(let x, let y, let z):
            guard [x, y, z].allSatisfy({ $0.isFinite && abs($0) <= 1000 }) else { return false }
        }
        guard (elapsedSimulationTime + delay).isFinite else { return false }
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
            if rule.delay > 0 {
                _ = schedule(rule.action, from: id, after: rule.delay)
            } else {
                if actionQueue.count >= 512 { break }
                actionQueue.append(PendingAction(sourceID: id, action: rule.action,
                                                 simulationTime: elapsedSimulationTime))
            }
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
              validObjectIDs.contains(a),
              validObjectIDs.contains(b) else { return }
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

    /// An explicit input event for switches, buttons and motor starters.
    /// Unlike a collision, this activates only the addressed object, allowing
    /// genuine one-way chains and controllable prototype mechanisms.
    @discardableResult
    public mutating func triggerObject(_ id: String) -> Bool {
        guard phase == .running,
              validObjectIDs.contains(id),
              activatedObjectIDs.insert(id).inserted else { return false }
        activations.append(Activation(objectID: id, triggeredBy: id,
                                      impulse: 0,
                                      simulationTime: elapsedSimulationTime))
        enqueueReactions(for: id, firstContact: true)
        return true
    }

    /// A repeatable player-operated switch. Unlike collision activation,
    /// a deliberate tap remains usable after incidental physics contacts.
    @discardableResult
    public mutating func pressObject(_ id: String) -> Bool {
        guard phase == .running,
              validObjectIDs.contains(id),
              reactionRules.contains(where: { $0.objectID == id }) else { return false }
        if activatedObjectIDs.insert(id).inserted {
            activations.append(Activation(objectID: id, triggeredBy: id,
                                          impulse: 0,
                                          simulationTime: elapsedSimulationTime))
        }
        enqueueReactions(for: id, firstContact: true)
        return true
    }

    /// Exact object-to-object reference from the original PC level field
    /// CONNECTED_TO N. N is a zero-based index into level_elements.children,
    /// NOT into the flattened scene hierarchy or the physics body array.
    /// It describes an original link but does not, by itself, prove victory.
    public struct OriginalConnection: Equatable {
        public let sourceID: String
        public let sourceType: String
        public let targetID: String
        public let targetType: String
        public let originalTargetIndex: Int
    }

    /// Original electrical terminals are tmo_power_plug children. Their
    /// integral VALF values are distinct TERMINAL IDENTIFIERS, not voltage
    /// readings, wire connections or evidence that power is flowing.
    /// 321 plugs occur in the recovered 102 PC levels; 272 have indexed
    /// VALF identifiers and 49 are missing this field entirely.
    public struct OriginalPowerTerminal: Equatable {
        public let plugObjectID: String
        public let originalTerminalNumber: Int?
        public let deviceObjectID: String?
        public let deviceType: String?
        public let originalRelativePosition: [Double]?
    }

    public let levelIndex: Int
    public let sceneSHA256: String
    public let objects: [Object]
    public let originalConnections: [OriginalConnection]
    public let originalPowerTerminals: [OriginalPowerTerminal]
    public let powerTerminalNumbersAreUnique: Bool
    private let validObjectIDs: Set<String>
    public private(set) var phase: Phase = .ready
    public private(set) var elapsedSimulationTime: TimeInterval = 0

    public init(document: CMOriginalSceneDocument) {
        levelIndex = document.index
        sceneSHA256 = document.sceneSHA256
        var collected: [Object] = []
        var ordinal = 0
        var elementObjectIDs: [Int: String] = [:]
        var pendingConnections: [(source: String, targetIndex: Int)] = []

        func visit(_ node: CMOriginalSceneDocument.Node,
                   parentObjectID: String?, elementIndex: Int? = nil) {
            var owner = parentObjectID
            if node.name.hasPrefix("tmo_") {
                // Preorder indices are stable for a given exported scene and
                // disambiguate repeated object types without hashing fields.
                let id = "object-\(ordinal)"
                ordinal += 1
                owner = id
                if let elementIndex {
                    elementObjectIDs[elementIndex] = id
                }
                for raw in node.originalFieldValues["CONNECTED_TO"] ?? [] {
                    if let index = Int(raw), index >= 0 {
                        pendingConnections.append((source: id, targetIndex: index))
                    }
                }
                // Preserve every original 3DO belonging to this object,
                // including models below helper transforms in older exports.
                // A nested tmo_* starts a different original object.
                var models: [String] = []
                var seenModels = Set<String>()
                for model in node.models ?? [] {
                    if seenModels.insert(model.lowercased()).inserted {
                        models.append(model)
                    }
                }
                func collectOwnModels(_ item: CMOriginalSceneDocument.Node) {
                    for child in item.children {
                        if child.name.hasPrefix("tmo_") { continue }
                        if child.name.hasPrefix("3DO ") {
                            let model = String(child.name.dropFirst(4))
                            if seenModels.insert(model.lowercased()).inserted { models.append(model) }
                        }
                        collectOwnModels(child)
                    }
                }
                collectOwnModels(node)
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
            if node.name == "level_elements" {
                for (index, child) in node.children.enumerated() {
                    visit(child, parentObjectID: owner, elementIndex: index)
                }
            } else {
                for child in node.children {
                    visit(child, parentObjectID: owner)
                }
            }
        }
        visit(document.root, parentObjectID: nil)
        objects = collected
        validObjectIDs = Set(collected.map(\.id))
        let types = Dictionary(uniqueKeysWithValues:
            collected.map { ($0.id, $0.type) })
        originalConnections = pendingConnections.compactMap { link in
            guard let targetID = elementObjectIDs[link.targetIndex],
                  let sourceType = types[link.source],
                  let targetType = types[targetID] else { return nil }
            return OriginalConnection(
                sourceID: link.source, sourceType: sourceType,
                targetID: targetID, targetType: targetType,
                originalTargetIndex: link.targetIndex
            )
        }

        let byID = Dictionary(uniqueKeysWithValues: collected.map { ($0.id, $0) })
        originalPowerTerminals = collected.compactMap { plug in
            guard plug.type == "tmo_power_plug" else { return nil }
            // Only an integral, positive PC VALF number is a terminal ID.
            // Other VALF fields belong to motors and lamp components and
            // must NOT be interpreted as electrical connection endpoints.
            var terminalNumber: Int?
            if let raw = plug.fields["VALF"]?.first,
               let number = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
               number.isFinite, number >= 1, number <= 100_000,
               abs(number - number.rounded()) < 0.0001 {
                terminalNumber = Int(number.rounded())
            }

            // Some power plug models sit below a tmo_mount_wood helper,
            // rather than directly underneath their actual device.
            // Follow the recovered hierarchy to the nearest PC power part;
            // never attach to an arbitrary spatially-nearest motor.
            var ancestorID = plug.parentID
            var device: Object?
            var hopCount = 0
            while let id = ancestorID, let ancestor = byID[id],
                  hopCount < 128 {
                if ancestor.type.hasPrefix("tmo_power_"),
                   ancestor.type != "tmo_power_plug" {
                    device = ancestor
                    break
                }
                ancestorID = ancestor.parentID
                hopCount += 1
            }
            return OriginalPowerTerminal(
                plugObjectID: plug.id,
                originalTerminalNumber: terminalNumber,
                deviceObjectID: device?.id,
                deviceType: device?.type,
                originalRelativePosition: plug.position
            )
        }
        var seenTerminalNumbers = Set<Int>()
        powerTerminalNumbersAreUnique = originalPowerTerminals.allSatisfy { terminal in
            guard let number = terminal.originalTerminalNumber else { return true }
            return seenTerminalNumbers.insert(number).inserted
        }
        // The authentic CML source scalar is active even before Run.
        // Delaying initialization until start() incorrectly hides
        // initially lit candles and the level-92 pocketlamp in the editor.
        originalPocketLampStates = authoredPocketLampStates
        originalHeatSourceStates = authoredHeatSourceStates
    }

    public var annotatedGoalObjects: [Object] {
        objects.filter { $0.goalAnnotation == "1" }
    }

    public mutating func start() {
        guard phase == .ready || phase == .stopped else { return }
        elapsedSimulationTime = 0
        originalSwitchStates.removeAll()
        originalPocketLampStates = authoredPocketLampStates
        originalHeatSourceStates = authoredHeatSourceStates
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
        guard phase == .running, delta.isFinite, delta > 0,
              (elapsedSimulationTime + delta).isFinite else { return }
        elapsedSimulationTime += delta
    }

    public mutating func stop() {
        phase = .stopped
    }

    public mutating func reset() {
        elapsedSimulationTime = 0
        originalSwitchStates.removeAll()
        originalPocketLampStates = authoredPocketLampStates
        originalHeatSourceStates = authoredHeatSourceStates
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


// Mechanism identities recovered from the user's authentic CML scene graphs.
// These types carry UCM geometry centered on their local XY pivot and must
// be allowed to SPIN, even when their original VALB field is absent.
// Motion is not automatically driven: electricity, steam and belt power
// transmission are not yet reconstructed from the Windows game.
enum CMOriginalAxleParts {
    static let rotatingKinds: Set<String> = [
        "tmo_belt_gear",
        "tmo_belt_conveyer_wheel",
        "tmo_belt_conveyer_roll_big",
        "tmo_belt_conveyer_roll_small",
        "tmo_power_motor_rotor",
        "tmo_power_generator_rotor",
        "tmo_power_disrupter_wheel",
        "tmo_steam_wheel",
        "tmo_windmill_wheel",
        "tmo_windmill_wings",
        "tmo_hammer_wheel",
        "tmo_belt_flag_wheel",
        "tmo_heat_grill_wheel"
    ]
}


/// Native contact gates in 0x444045..0x4441A7 (Pike) and
/// 0x445110..0x4451C1 (Cut). Exact strict radii; the renderer
/// supplies the actual contact and authenticated UCM marker position.
public enum CMOriginalBalloonPuncture {
    public struct Rule {
        public let marker: String
        public let radius: Float
    }

    public static func rule(for type: String) -> Rule? {
        if type.hasSuffix("_nail") {
            return Rule(marker: "Pike", radius: type == "tmo_hammer_nail" ? 0.14 : 0.05)
        }
        if type == "tmo_rope_crossbow_arrow" {
            return Rule(marker: "Cut", radius: 0.09)
        }
        return nil
    }

    public static func hits(point: SIMD3<Float>, marker: SIMD3<Float>, radius: Float) -> Bool {
        guard radius.isFinite, radius > 0,
              [point.x, point.y, point.z, marker.x, marker.y, marker.z].allSatisfy(\.isFinite)
        else { return false }
        let d = point - marker
        return d.x*d.x + d.y*d.y + d.z*d.z < radius*radius
    }
}


/// Original catapult trigger 0x444F12..0x444F8E and terminal state
/// 0x44DCDB..0x44DE56. The native hinge range is +/- pi/4 and its
/// upward force is 100 at Ammo. The SceneKit rate is reconstructed,
/// not a recovered native force-to-angular-speed conversion.
public struct CMOriginalCatapultStroke {
    public enum Phase { case ready, triggered, finished }
    public private(set) var phase: Phase = .ready
    public private(set) var travel: Float = 0
    public static let triggerRadius: Float = 0.1
    public static let limit: Float = .pi / 4

    public init() {}

    public mutating func trigger(contact: SIMD3<Float>, button: SIMD3<Float>) -> Bool {
        guard phase == .ready,
              [contact.x, contact.y, contact.z, button.x, button.y, button.z]
                .allSatisfy(\.isFinite) else { return false }
        let d = contact - button
        guard d.x*d.x + d.y*d.y + d.z*d.z < Self.triggerRadius*Self.triggerRadius
        else { return false }
        phase = .triggered
        return true
    }

    /// Only one running-frame stroke, with a bounded delta. The fixed
    /// 12 rad/s adapter is provisional; the native angular limit is not.
    public mutating func advance(delta: Double) -> Float? {
        guard phase == .triggered, delta.isFinite, delta > 0, delta <= 0.25
        else { return nil }
        travel = min(Self.limit, travel + 12 * Float(delta))
        if travel == Self.limit { phase = .finished }
        return travel
    }
}


/// Original game crossbow release predicate 0x45783B..0x4578A9,
/// and its virtual projectile velocity 0x450594..0x4505EA.
/// Inputs describe the imported puzzle geometry, not physical hardware.
public struct CMOriginalCrossbowRelease {
    public private(set) var released = false

    public init() {}

    public static func leverReady(angle: Float, mirrored: Bool) -> Bool {
        guard angle.isFinite else { return false }
        return mirrored ? angle > 0.3 : angle < -0.3
    }

    public mutating func release(angle: Float, mirrored: Bool,
                                 direction: SIMD3<Float>) -> SIMD3<Float>? {
        guard !released, Self.leverReady(angle: angle, mirrored: mirrored),
              [direction.x, direction.y, direction.z].allSatisfy(\.isFinite),
              abs(direction.x) > 0.0001 else { return nil }
        let velocity = SIMD3<Float>(direction.x * 20, direction.y, 0)
        guard velocity.x.isFinite else { return nil }
        released = true
        return velocity
    }
}
