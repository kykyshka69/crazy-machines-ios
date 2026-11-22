import Foundation

/// A shared evidence-only tracker for all 102 imported original PC scenes.
/// This does not decide win/loss: the Windows GOAL state machines, scripts,
/// electricity and other original engine rules are not yet recovered.
/// No copyrighted level payload is embedded in this file.
public struct CMOriginalObjectiveEvidenceLedger {
    public struct Goal: Hashable {
        public let objectID: String
        public let type: String
        public init(objectID: String, type: String) {
            self.objectID = objectID
            self.type = type
        }
    }

    public struct Connection: Hashable {
        public let sourceID: String
        public let targetID: String
        public let sourceType: String
        public let targetType: String
        public init(sourceID: String, targetID: String,
                    sourceType: String, targetType: String) {
            self.sourceID = sourceID
            self.targetID = targetID
            self.sourceType = sourceType
            self.targetType = targetType
        }
    }

    public let levelIndex: Int
    public let sceneSHA256: String
    public let goalMarkers: Set<Goal>
    public let authoredConnections: Set<Connection>
    public private(set) var observedGoalIDs: Set<String> = []
    public private(set) var observedContacts: Set<Connection> = []

    public init?(levelIndex: Int, sceneSHA256: String,
                 goalMarkers: [Goal], connections: [Connection]) {
        guard (1...102).contains(levelIndex),
              sceneSHA256.count == 64,
              sceneSHA256.unicodeScalars.allSatisfy({
                  (48...57).contains($0.value) || (65...70).contains($0.value)
                      || (97...102).contains($0.value)
              }),
              !goalMarkers.isEmpty || !connections.isEmpty,
              goalMarkers.allSatisfy({ !$0.objectID.isEmpty && !$0.type.isEmpty }),
              connections.allSatisfy({
                  !$0.sourceID.isEmpty && !$0.targetID.isEmpty
                      && $0.sourceID != $0.targetID
                      && !$0.sourceType.isEmpty && !$0.targetType.isEmpty
              }) else { return nil }
        self.levelIndex = levelIndex
        self.sceneSHA256 = sceneSHA256
        self.goalMarkers = Set(goalMarkers)
        self.authoredConnections = Set(connections)
    }

    /// Index original GOAL and CONNECTED_TO markers using the same object IDs
    /// as the SceneKit physics registry. Metadata alone is never a win.
    public init?(session: CMOriginalGameplaySession) {
        let goals = session.objects.compactMap { object -> Goal? in
            let marker = object.fields["GOAL"]?.first ?? object.goalAnnotation
            guard marker == "1" else { return nil }
            return Goal(objectID: object.id, type: object.type)
        }
        let links = session.originalConnections.map {
            Connection(sourceID: $0.sourceID, targetID: $0.targetID,
                       sourceType: $0.sourceType, targetType: $0.targetType)
        }
        self.init(levelIndex: session.levelIndex,
                  sceneSHA256: session.sceneSHA256,
                  goalMarkers: goals, connections: links)
    }

    public var observedGoalCount: Int { observedGoalIDs.count }
    public var observedConnectionCount: Int { observedContacts.count }
    public var totalMarkerCount: Int {
        goalMarkers.count + authoredConnections.count
    }

    /// This means only that app-side events have been recorded for every
    /// original metadata marker. It is never called `isWon` intentionally.
    public var allMarkersObserved: Bool {
        observedGoalCount == goalMarkers.count
            && observedConnectionCount == authoredConnections.count
    }

    /// Only a genuine detected SceneKit collision may supply this event.
    /// The contact is physically unordered, but we retain the exact
    /// direction from the original CONNECTED_TO record in the result.
    @discardableResult
    public mutating func recordPhysicalContact(
        _ objectA: String, _ objectB: String, isSimulationRunning: Bool
    ) -> [Connection] {
        guard isSimulationRunning, objectA != objectB else { return [] }
        let matches = authoredConnections.filter {
            ($0.sourceID == objectA && $0.targetID == objectB)
                || ($0.sourceID == objectB && $0.targetID == objectA)
        }
        var fresh: [Connection] = []
        for original in matches where observedContacts.insert(original).inserted {
            fresh.append(original)
        }
        return fresh.sorted {
            ($0.sourceID + "|" + $0.targetID) <
                ($1.sourceID + "|" + $1.targetID)
        }
    }

    /// This is NOT called on generic collisions. The feature-specific
    /// mechanic (lamp powered, rocket launched, bucket filled, etc.) must
    /// explicitly report a verified state transition for the original id.
    @discardableResult
    public mutating func recordGoalStateChanged(
        _ objectID: String, isSimulationRunning: Bool
    ) -> Bool {
        guard isSimulationRunning,
              goalMarkers.contains(where: { $0.objectID == objectID }) else {
            return false
        }
        return observedGoalIDs.insert(objectID).inserted
    }

    public mutating func reset() {
        observedGoalIDs.removeAll(keepingCapacity: true)
        observedContacts.removeAll(keepingCapacity: true)
    }
}