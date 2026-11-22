import Foundation

/// A deliberately narrow first-playable-level prototype using only original
/// PC scene evidence. This is NOT the recovered Windows victory condition.
/// The authentic Professor Laboratory first level contains four distinct
/// CONNECTED_TO references, all pointing to one tmo_zone, and exactly two
/// UNLOCKED tmo_board pieces. Only that signature enables this challenge.
public struct CMOriginalFirstLevelRun {
    public struct Target: Equatable, Identifiable {
        public let sourceID: String
        public let sourceType: String
        public let zoneID: String
        public var id: String { sourceID + "|" + zoneID }

        public var displayName: String {
            switch sourceType {
            case "tmo_ball_tennis": return "Tennis ball"
            case "tmo_ball_beach": return "Beach ball"
            case "tmo_ball_basket": return "Basketball"
            case "tmo_crate": return "Crate"
            default: return sourceType
            }
        }
    }

    public let targets: [Target]
    public let sceneSHA256: String
    public private(set) var deliveredIDs: Set<String> = []

    public init?(document: CMOriginalSceneDocument) {
        guard document.index == 1 else { return nil }
        let session = CMOriginalGameplaySession(document: document)
        let links = session.originalConnections
        let expectedTypes: Set<String> = [
            "tmo_ball_tennis", "tmo_ball_beach",
            "tmo_ball_basket", "tmo_crate"
        ]
        let eligibleBoards = session.objects.filter {
            $0.type == "tmo_board" && ($0.fields["UNLOCKED"] ?? []).contains("1")
        }
        guard links.count == 4,
              eligibleBoards.count == 2,
              Set(links.map(\.sourceID)).count == 4,
              Set(links.map(\.sourceType)) == expectedTypes,
              links.allSatisfy({ $0.targetType == "tmo_zone" }),
              Set(links.map(\.targetID)).count == 1
        else { return nil }

        // Preserve the original link order; no hardcoded preorder object IDs.
        targets = links.map { Target(sourceID: $0.sourceID,
                                     sourceType: $0.sourceType,
                                     zoneID: $0.targetID) }
        sceneSHA256 = document.sceneSHA256
    }

    public var deliveredCount: Int { deliveredIDs.count }
    public var totalCount: Int { targets.count }
    public var isSatisfied: Bool {
        !targets.isEmpty && deliveredIDs.count == targets.count
    }
    public var storageKey: String {
        "cm.original.prototype-level-1.\(sceneSHA256)"
    }

    public func isDelivered(_ target: Target) -> Bool {
        deliveredIDs.contains(target.id)
    }

    /// Accept only actual reported contacts for exactly the source and zone
    /// linked in the PC scene. A ball touching a different zone, duplicates,
    /// reversed source/target pairs, or unrelated collisions never advance.
    @discardableResult
    public mutating func recordContact(sourceID: String, zoneID: String) -> Bool {
        let key = sourceID + "|" + zoneID
        guard targets.contains(where: { $0.id == key }),
              deliveredIDs.insert(key).inserted else { return false }
        return true
    }

    /// A replay starts with zero deliveries, not a persisted collision count.
    public mutating func reset() {
        deliveredIDs.removeAll()
    }
}

/**
 Evidence-limited level-two prototype based on the user's authentic PC scene.

 Original Professor level 2 ("Эффект домино") contains a basketball whose
 sole CONNECTED_TO target is a tmo_crate, NOT the separately present tmo_zone.
 Exactly three dominoes are marked UNLOCKED 1. A contact between the named
 basket and its own crate is a testable interaction; it does not assert that
 the original Windows puzzle's complete victory rule has been recovered.
 */
public struct CMOriginalSecondLevelRun {
    public let sourceID: String
    public let targetID: String
    public let sceneSHA256: String
    public private(set) var isSatisfied = false

    public init?(document: CMOriginalSceneDocument) {
        guard document.index == 2 else { return nil }
        let session = CMOriginalGameplaySession(document: document)
        let connections = session.originalConnections
        let editable = session.objects.filter {
            ($0.fields["UNLOCKED"] ?? []).contains("1")
        }
        guard connections.count == 1,
              let only = connections.first,
              only.sourceType == "tmo_ball_basket",
              only.targetType == "tmo_crate",
              editable.count == 3,
              editable.allSatisfy({ $0.type == "tmo_domino" })
        else { return nil }
        sourceID = only.sourceID
        targetID = only.targetID
        sceneSHA256 = document.sceneSHA256
    }

    public var storageKey: String {
        "cm.original.prototype-level-2.\(sceneSHA256)"
    }

    /// Exact original source/target IDs, not merely any ball or any crate.
    @discardableResult
    public mutating func recordContact(
        sourceID: String, targetID: String
    ) -> Bool {
        guard !isSatisfied,
              sourceID == self.sourceID,
              targetID == self.targetID else { return false }
        isSatisfied = true
        return true
    }

    public mutating func reset() {
        isSatisfied = false
    }
}

/**
 Evidence-limited Professor level 3 ("Уборщик") prototype. The user-owned
 PC scene has five distinct crates connected to ONE tmo_zone, plus exactly
 one unlocked tmo_spring. This is a SceneKit contact objective, not proof
 that the Windows game's spring/victory physics has been reproduced.
 */
public struct CMOriginalThirdLevelRun {
    public struct Target: Equatable, Identifiable {
        public let sourceID: String
        public let zoneID: String
        public var id: String { sourceID + "|" + zoneID }
    }

    public let targets: [Target]
    public let sceneSHA256: String
    public private(set) var deliveredIDs = Set<String>()

    public init?(document: CMOriginalSceneDocument) {
        guard document.index == 3 else { return nil }
        let session = CMOriginalGameplaySession(document: document)
        let links = session.originalConnections
        let editable = session.objects.filter {
            ($0.fields["UNLOCKED"] ?? []).contains("1")
        }
        guard links.count == 5,
              Set(links.map(\.sourceID)).count == 5,
              links.allSatisfy({
                  $0.sourceType == "tmo_crate" && $0.targetType == "tmo_zone"
              }),
              Set(links.map(\.targetID)).count == 1,
              editable.count == 1,
              editable.first?.type == "tmo_spring"
        else { return nil }

        targets = links.map {
            Target(sourceID: $0.sourceID, zoneID: $0.targetID)
        }
        sceneSHA256 = document.sceneSHA256
    }

    public var deliveredCount: Int { deliveredIDs.count }
    public var totalCount: Int { targets.count }
    public var isSatisfied: Bool {
        !targets.isEmpty && deliveredIDs.count == targets.count
    }
    public var storageKey: String {
        "cm.original.prototype-level-3.\(sceneSHA256)"
    }

    @discardableResult
    public mutating func recordContact(
        sourceID: String, zoneID: String
    ) -> Bool {
        let key = sourceID + "|" + zoneID
        guard targets.contains(where: { $0.id == key }),
              deliveredIDs.insert(key).inserted else { return false }
        return true
    }

    public mutating func reset() {
        deliveredIDs.removeAll()
    }
}
