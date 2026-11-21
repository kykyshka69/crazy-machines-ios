import Foundation

/// One authoritative original-object registry for experimental SceneKit
/// physics roles. IDs MUST come from CMOriginalGameplaySession's traversal:
/// a level's nested tmo_mount_* objects change preorder ordinals. Recounting
/// the scene separately in SwiftUI may silently freeze the wrong ball or let
/// a fixed board/collection zone fall.
public enum CMOriginalPhysicsRolePlanner {
    public static func roles(
        for session: CMOriginalGameplaySession
    ) -> [String: CMOriginalGameplaySession.PhysicsRole] {
        var result: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
        result.reserveCapacity(session.objects.count)
        for object in session.objects {
            let role: CMOriginalGameplaySession.PhysicsRole
            if object.type == "tmo_zone" {
                // Original level capture zones detect contact but cannot
                // drop, bounce or obstruct the falling PC objects.
                role = .sensor
            } else if object.type == "tmo_rope_seesaw_lever"
                        || CMOriginalAxleParts.rotatingKinds.contains(object.type) {
                // Preserve hinged and axle-driven components even when
                // original metadata does not include a VALB moving flag.
                role = .movable
            } else if let raw = object.fields["VALB"]?.first,
                      let flags = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                      (0...255).contains(flags) {
                // Recovered bit 8 marks movable original puzzle bodies.
                // This is an experimental SceneKit mapping, not PC physics.
                role = (flags & 8) != 0 ? .movable : .fixed
            } else {
                // Missing, invalid and decorative metadata is not a license
                // to simulate falling equipment supports or backdrops.
                role = .fixed
            }
            result[object.id] = role
        }
        return result
    }
}
