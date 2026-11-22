import Foundation

/// Original Professor level 4: one tennis ball, one GOAL 1 bucket and one
/// player-editable permanent magnet; there is no CONNECTED_TO field.
/// Track a physically observed ball-inside-bucket event in the iOS engine.
/// This is NOT a reconstructed Windows victory condition.
public struct CMOriginalFourthLevelRun {
    public let ballID: String
    public let bucketID: String
    public let sceneSHA256: String
    public private(set) var isSatisfied = false

    public init?(document: CMOriginalSceneDocument) {
        guard document.index == 4 else { return nil }
        let scene = CMOriginalGameplaySession(document: document)
        let balls = scene.objects.filter { $0.type == "tmo_ball_tennis" }
        let buckets = scene.objects.filter {
            $0.type == "tmo_bucket"
                && ($0.goalAnnotation == "1"
                    || ($0.fields["GOAL"] ?? []).contains("1"))
        }
        let magnets = scene.objects.filter {
            $0.type == "tmo_magnetic_permanent"
                && ($0.fields["UNLOCKED"] ?? []).contains("1")
        }
        let movable = scene.objects.filter {
            ($0.fields["UNLOCKED"] ?? []).contains("1")
        }
        guard balls.count == 1, buckets.count == 1,
              magnets.count == 1, movable.count == 1,
              movable.first?.id == magnets.first?.id,
              scene.originalConnections.isEmpty else { return nil }
        ballID = balls[0].id
        bucketID = buckets[0].id
        sceneSHA256 = document.sceneSHA256
    }

    public var storageKey: String {
        "cm.original.prototype-level-4.\(sceneSHA256)"
    }

    @discardableResult
    public mutating func recordCapture(ballID: String, bucketID: String) -> Bool {
        guard !isSatisfied, ballID == self.ballID,
              bucketID == self.bucketID else { return false }
        isSatisfied = true
        return true
    }

    public mutating func reset() { isSatisfied = false }
}
