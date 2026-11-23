import Foundation

/// Original PC executable registers UCM named attachments with 0x425250
/// (sites 0x42FE12..0x42FFB1). It stores their type selector in the
/// registered native object at +0x10 (0x4252B4..0x4252B7).
///
/// The candle and rocket then request selector 3, ordinal 0; this
/// registry proves the literal original label for that selector is
/// "Heat". The name alone is not native +0x20 cone/+0x24 geometry.
public enum CMOriginalWindowsNamedRegionRegistry {
    public static func nativeSelector(forOriginalMarkerName name: String) -> UInt8? {
        switch name {
        case "Pipe": return 1
        case "Light": return 2
        case "Heat": return 3
        case "Wind": return 4
        case "Gear": return 5
        case "Mechanic": return 10
        case "Magnetic": return 11
        case "Fire", "Rope": return 0xfd
        case "Power": return 0xfe
        case "Wheel": return 0xff
        default: return nil
        }
    }

    /// "Heat" is the only original registered UCM label for selector 3.
    /// Candidate only: record attachment and native cone parameters must
    /// still be independently measured before ignition is permitted.
    public static func isHeatRegionCandidate(_ originalName: String) -> Bool {
        nativeSelector(forOriginalMarkerName: originalName) == 3
    }
}
