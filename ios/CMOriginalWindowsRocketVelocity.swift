import Foundation

/// Native Win32 loader 0x422D35 reads the original VELOCITY script key,
/// and 0x422D81 stores its Float32 into the object at +0xFC. The rocket
/// Engine reads this very field at 0x44F219. Initial value only: the
/// running object's later modifications have not been proved absent.
public enum CMOriginalWindowsRocketVelocity {
    public enum Origin: Equatable {
        case originalSceneOverride, originalElementsTemplate
    }
    public struct Evidence: Equatable {
        public let initialChildFC: Float
        public let origin: Origin
    }

    public static func initialChildFC(
        originalChildType: String,
        sceneFields: [String: [String]],
        originalTemplateFields: [String: [String]]?
    ) -> Evidence? {
        guard originalChildType == "tmo_heat_rocket_rocket" else { return nil }
        let raw: String
        let source: Origin
        if let override = sceneFields["VELOCITY"] {
            guard override.count == 1 else { return nil }
            raw = override[0]
            source = .originalSceneOverride
        } else {
            guard let original = originalTemplateFields?["VELOCITY"],
                  original.count == 1 else { return nil }
            raw = original[0]
            source = .originalElementsTemplate
        }
        guard let initial = Float(raw.trimmingCharacters(
            in: .whitespacesAndNewlines)), initial.isFinite else { return nil }
        return Evidence(initialChildFC: initial, origin: source)
    }
}
