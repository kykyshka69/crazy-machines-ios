import Foundation

/// Maps an observed SceneKit rigid-body contact to the original PC switch
/// lever and the *other* original object. It does not infer the Windows
/// switch activation threshold or connect an electrical circuit.
public struct CMOriginalSwitchContactMapper {
    public struct Item: Equatable {
        public let id: String
        public let type: String
        public let parentID: String?

        public init(id: String, type: String, parentID: String?) {
            self.id = id
            self.type = type
            self.parentID = parentID
        }
    }

    public struct Hit: Equatable {
        public let switchID: String
        public let leverID: String
        public let strikingObjectID: String
        public let strikingObjectType: String
        public let impulse: Double
    }

    /// Experimental SceneKit physical switch drive: a genuine moving
    /// original striker must actually hit the mapped UCM LEVER with a
    /// positive, finite collision impulse. The Win32 *threshold* and
    /// per-contact +0xEC/+0xC8 electrical fields are not yet recovered,
    /// so do not call this native switch activation evidence or GOAL.
    /// beginContact() independently validates original CML ownership
    /// and debounces each continuous pair until didEnd().
    public static func qualifiesForExperimentalImpact(_ hit: Hit) -> Bool {
        hit.impulse.isFinite && hit.impulse > 0
    }

    private struct Pair: Hashable {
        let first: String
        let second: String
        init(_ a: String, _ b: String) {
            first = min(a, b)
            second = max(a, b)
        }
    }

    private let objectTypes: [String: String]
    private let owningSwitchByObject: [String: String]
    private let switchByLever: [String: String]
    private var activePairs: Set<Pair> = []
    // A SceneKit contact often begins with ZERO collision impulse. The
    // actual positive impact can arrive in didUpdate on the next frame.
    // Track which real lever/striker PAIRS already triggered independently
    // of ongoing contact observations. Clear only when contact ends.
    private var impactedPairs: Set<Pair> = []

    public init(objects: [Item]) {
        let byID = Dictionary(objects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        objectTypes = byID.mapValues(\.type)
        var owners: [String: String] = [:]
        var levers: [String: String] = [:]
        for item in objects {
            // A lever might sit under an intermediate mounting object.
            // Walk only the original CML hierarchy; never pick a nearby part.
            var ancestorID: String? = item.id
            var visited = Set<String>()
            var depth = 0
            while let id = ancestorID, let ancestor = byID[id],
                  visited.insert(id).inserted, depth < 128 {
                if ancestor.type == "tmo_power_switch" {
                    owners[item.id] = id
                    if item.type == "tmo_power_switch_lever" && item.id != id {
                        levers[item.id] = id
                    }
                    break
                }
                ancestorID = ancestor.parentID
                depth += 1
            }
        }
        owningSwitchByObject = owners
        switchByLever = levers
    }

    /// Emits a contact only when SceneKit identifies the actual original
    /// lever, not a base or nearby housing. The striker must be movable and
    /// outside that switch's original child hierarchy. A sustained collision
    /// is reported once, until didEnd closes the pair.
    public mutating func beginContact(
        _ a: String, _ b: String, impulse: Double,
        aIsMovable: Bool, bIsMovable: Bool
    ) -> Hit? {
        guard a != b, impulse.isFinite, impulse >= 0,
              objectTypes[a] != nil, objectTypes[b] != nil else { return nil }
        let switchID: String
        let leverID: String
        let strikerID: String
        if let owner = switchByLever[a], bIsMovable,
           owningSwitchByObject[b] == nil {
            switchID = owner
            leverID = a
            strikerID = b
        } else if let owner = switchByLever[b], aIsMovable,
                  owningSwitchByObject[a] == nil {
            switchID = owner
            leverID = b
            strikerID = a
        } else { return nil }
        let pair = Pair(a, b)
        guard activePairs.insert(pair).inserted,
              let type = objectTypes[strikerID] else { return nil }
        return Hit(switchID: switchID, leverID: leverID,
                   strikingObjectID: strikerID,
                   strikingObjectType: type, impulse: impulse)
    }

    /// Called on BOTH didBegin and didUpdate. Only an already recognized
    /// original CML lever / moving original striker pair can cause a
    /// physical prototype toggle; a zero first impulse is not fatal.
    /// This accepts exactly ONE positive finite impulse during each
    /// sustained contact, preventing chattering and accidental double
    /// switch flips on the following SceneKit frames.
    public mutating func consumeImpact(
        _ a: String, _ b: String, impulse: Double,
        aIsMovable: Bool, bIsMovable: Bool
    ) -> Hit? {
        let pair = Pair(a, b)
        guard activePairs.contains(pair), impulse.isFinite, impulse > 0,
              !impactedPairs.contains(pair) else { return nil }
        let switchID: String
        let leverID: String
        let strikerID: String
        if let owner = switchByLever[a], bIsMovable,
           owningSwitchByObject[b] == nil {
            switchID = owner; leverID = a; strikerID = b
        } else if let owner = switchByLever[b], aIsMovable,
                  owningSwitchByObject[a] == nil {
            switchID = owner; leverID = b; strikerID = a
        } else { return nil }
        guard let kind = objectTypes[strikerID],
              impactedPairs.insert(pair).inserted else { return nil }
        return Hit(switchID: switchID, leverID: leverID,
                   strikingObjectID: strikerID,
                   strikingObjectType: kind, impulse: impulse)
    }

    public mutating func endContact(_ a: String, _ b: String) {
        let pair = Pair(a, b)
        activePairs.remove(pair)
        impactedPairs.remove(pair)
    }

    public mutating func reset() {
        activePairs.removeAll()
        impactedPairs.removeAll()
    }
}
