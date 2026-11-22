import Foundation

/// Identifies native Windows Catch/Test callbacks from exact original CML.
/// A ball with CONNECTED_TO pointing at a bucket/cage is NOT credited on
/// simple collision with the outside wall. It needs the same original
/// internal 0.1-radius Catch/Test region used by container GOAL events.
/// No relative proximity matching, invented links, or synthetic GUIDs.
struct CMOriginalContainerCatchLinks {
    let goalContainerKindsByID: [String: String]
    let linkedSourcesByTargetID: [String: Set<String>]

    init(session: CMOriginalGameplaySession) {
        func isContainer(_ type: String) -> Bool {
            type == "tmo_bucket" || type == "tmo_rope_cage"
        }

        goalContainerKindsByID = Dictionary(uniqueKeysWithValues:
            session.objects.compactMap { object -> (String, String)? in
                guard isContainer(object.type),
                      object.goalAnnotation == "1"
                        || object.fields["GOAL"]?.contains("1") == true
                else { return nil }
                return (object.id, object.type)
            }
        )
        var links: [String: Set<String>] = [:]
        for link in session.originalConnections {
            guard isContainer(link.targetType),
                  link.sourceType.hasPrefix("tmo_ball_"),
                  link.sourceID != link.targetID else { continue }
            links[link.targetID, default: []].insert(link.sourceID)
        }
        linkedSourcesByTargetID = links
    }

    func acceptsOriginalLinkedBall(
        sourceID: String, targetID: String
    ) -> Bool {
        linkedSourcesByTargetID[targetID]?.contains(sourceID) == true
    }

    var watchedContainerIDs: Set<String> {
        Set(goalContainerKindsByID.keys).union(
            linkedSourcesByTargetID.keys
        )
    }
}
