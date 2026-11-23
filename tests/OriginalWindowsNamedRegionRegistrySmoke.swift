import Foundation

@main struct OriginalWindowsNamedRegionRegistrySmoke {
    static func main() {
        typealias R = CMOriginalWindowsNamedRegionRegistry
        let original: [(String, UInt8)] = [
            ("Pipe", 1), ("Light", 2), ("Heat", 3), ("Wind", 4),
            ("Gear", 5), ("Mechanic", 10), ("Magnetic", 11),
            ("Fire", 0xfd), ("Rope", 0xfd), ("Power", 0xfe),
            ("Wheel", 0xff)
        ]
        for (name, selector) in original {
            precondition(R.nativeSelector(forOriginalMarkerName: name) == selector)
        }
        precondition(R.isHeatRegionCandidate("Heat"))
        precondition(!R.isHeatRegionCandidate("Light"))
        precondition(!R.isHeatRegionCandidate("Wind"))
        precondition(!R.isHeatRegionCandidate("Fire"))
        precondition(!R.isHeatRegionCandidate("heat"))
        precondition(!R.isHeatRegionCandidate("Heat01"))
        precondition(R.nativeSelector(forOriginalMarkerName: "Engine") == nil)
        precondition(R.nativeSelector(forOriginalMarkerName: "Direction") == nil)
        precondition(R.nativeSelector(forOriginalMarkerName: "Explode") == nil)
        precondition(R.nativeSelector(forOriginalMarkerName: "") == nil)
        print("Win32 native UCM label registry: 11 authentic categories, Heat selector 3 PASS")
    }
}
