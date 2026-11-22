import Foundation

/// The two-input win counter recovered from the original Windows executable.
///
/// Verified x86 chain (VA in owner's CrazyMachines.exe):
///  0x422E80 / 0x422ECC: GOAL -> original object field +0x160
///  0x422FE2 / 0x42302E: CONNECTED_TO index -> +0x174
///  0x44AC1F / 0x44AC46: resolve original index into object pointer +0x170
///  0x454DE0: count one input for each nonzero +0x160 and +0x170
///  0x44B460: independently latch +0x164 and +0x168 on goal/link events;
///            increase +0xAC once per eligible channel
///  0x44B53F-0x44B551: compare current +0xAC with required +0xA8
///  0x44B592: latch completed level (+0xD4); dispatch task_solved/level_done.
///
/// Input *events* must still come from faithfully simulated mechanisms.
/// Recovered metadata is not itself proof a switch has received power, a
/// ball entered a goal, or a Windows puzzle has actually been completed.
/// Only exact user-owned CML object IDs are eligible; no synthetic fallback.
public struct CMOriginalWindowsGoalCounter {
    public enum EventResult: Equatable {
        case ignored
        case credited
        case allInputsCredited
    }

    public let levelIndex: Int
    public let sceneSHA256: String
    public let totalRequired: Int
    public let requiredGoalCount: Int
    public let requiredConnectionCount: Int

    private let goalSourceIDs: Set<String>
    // Original +0x170 is a SINGLE resolved link pointer for each source
    // object. A second distinct CONNECTED_TO on the same source is ambiguous.
    private let connectedToBySource: [String: String]
    public private(set) var creditedGoalIDs = Set<String>()
    public private(set) var creditedConnectionSourceIDs = Set<String>()
    public private(set) var completed = false

    public var credited: Int {
        creditedGoalIDs.count + creditedConnectionSourceIDs.count
    }

    public init?(session: CMOriginalGameplaySession) {
        guard (1...102).contains(session.levelIndex) else { return nil }
        var goals = Set<String>()
        for object in session.objects {
            if let raw = object.fields["GOAL"]?.first,
               let flag = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
               flag != 0 {
                goals.insert(object.id)
            }
        }
        var links: [String: String] = [:]
        for link in session.originalConnections {
            if let previous = links[link.sourceID], previous != link.targetID {
                // The original engine has a single resolved pointer per
                // source object, so don't invent a choice between targets.
                return nil
            }
            links[link.sourceID] = link.targetID
        }
        let required = goals.count + links.count
        guard required > 0, required <= 10_000 else { return nil }
        levelIndex = session.levelIndex
        sceneSHA256 = session.sceneSHA256
        goalSourceIDs = goals
        connectedToBySource = links
        requiredGoalCount = goals.count
        requiredConnectionCount = links.count
        totalRequired = required
    }

    /// Original Windows event-channel 0: a mechanic-specific transition of
    /// an object with a nonzero GOAL flag. A mere generic collision must NOT
    /// call this, unless the mechanism has explicitly validated its goal.
    @discardableResult
    public mutating func recordGoalEvent(
        objectID: String, simulationRunning: Bool
    ) -> EventResult {
        guard simulationRunning, !completed,
              goalSourceIDs.contains(objectID),
              creditedGoalIDs.insert(objectID).inserted else { return .ignored }
        return checkCompletion()
    }

    /// Original Windows event-channel 1: contact with precisely the source's
    /// resolved CONNECTED_TO target. Both the original IDs and source/target
    /// direction matter; arbitrary contacts never advance this counter.
    @discardableResult
    public mutating func recordConnectedToEvent(
        sourceID: String, targetID: String, simulationRunning: Bool
    ) -> EventResult {
        guard simulationRunning, !completed,
              connectedToBySource[sourceID] == targetID,
              creditedConnectionSourceIDs.insert(sourceID).inserted else {
            return .ignored
        }
        return checkCompletion()
    }

    private mutating func checkCompletion() -> EventResult {
        guard credited == totalRequired else { return .credited }
        completed = true
        return .allInputsCredited
    }

    public mutating func reset() {
        creditedGoalIDs.removeAll(keepingCapacity: true)
        creditedConnectionSourceIDs.removeAll(keepingCapacity: true)
        completed = false
    }
}