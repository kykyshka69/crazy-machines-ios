import Foundation

/// One authoritative original-object registry for experimental SceneKit
/// physics roles. IDs MUST come from CMOriginalGameplaySession's traversal:
/// a level's nested tmo_mount_* objects change preorder ordinals. Recounting
/// the scene separately in SwiftUI may silently freeze the wrong ball or let
/// a fixed board/collection zone fall.
public enum CMOriginalPhysicsRolePlanner {
    public static func roles(
        for session: CMOriginalGameplaySession,
        originalTemplates: [String: CMOriginalElementsTemplateCatalog.Template]? = nil
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
            } else if ["tmo_rope_scissors_1", "tmo_rope_scissors_2"].contains(object.type),
                      let parentID = object.parentID,
                      session.objects.contains(where: {
                          $0.id == parentID && $0.type == "tmo_rope_scissors"
                      }) {
                // Authentic scissors blades have independent physical
                // angle components even though their CML omits VALB.
                role = .movable
            } else if object.type == "tmo_heat_rocket_rocket",
                      let parentID = object.parentID,
                      session.objects.contains(where: {
                          $0.id == parentID && $0.type == "tmo_heat_rocket"
                      }) {
                // Native Win32 0x44F1DD..0x44F27D continuously applies
                // Direction * live +0xFC force to THIS rocket child's
                // physics body. It must be dynamically simulated even
                // when its CML omits VALB and a template is unavailable.
                // Keep the parent rocket mount fixed independently.
                role = .movable
            } else {
                // Original level-specific VALB overrides take precedence
                // over templates recovered from the genuine elements.fsc.
                let inherited = originalTemplates.flatMap { templates in
                    let raw = object.fields.flatMap { key, values in
                        values.map { key + " " + $0 }
                    }
                    return CMOriginalWindowsElementRules(
                        type: object.type, sceneFields: raw,
                        catalogue: templates
                    )?.effectiveBits
                }
                let actual = object.fields["VALB"]?.first
                    .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .flatMap { (0...255).contains($0) ? $0 : nil }
                if let bits = actual ?? inherited {
                    role = (bits & 8) != 0 ? .movable : .fixed
                } else {
                    role = .fixed
                }
            }
            result[object.id] = role
        }
        return result
    }
}
