import Foundation

/// The actual power_plug.ucm contains separate `Plug` and `Wire` named
/// attachments. Visual cables must start at precisely one real `Wire` frame,
/// not the tmo_power_plug owner's center or its mating `Plug` frame.
/// Only the already selected CML plug pair defines electrical connectivity.
public enum CMOriginalPowerCableAnchor {
    public static func uniqueWireMarkerIndex(
        originalOwnerType: String,
        originalUCMNames: [String]
    ) -> Int? {
        guard originalOwnerType == "tmo_power_plug" else { return nil }
        var selected: Int?
        for (index, name) in originalUCMNames.enumerated()
            where name == "Wire" {
            guard selected == nil else { return nil }
            selected = index
        }
        return selected
    }
}
