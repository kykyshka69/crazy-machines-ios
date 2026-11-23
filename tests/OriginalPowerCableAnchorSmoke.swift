import Foundation

@main struct OriginalPowerCableAnchorSmoke {
    static func main() {
        typealias A = CMOriginalPowerCableAnchor
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_plug",
            originalUCMNames: ["Plug", "Wire"]) == 1)
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_plug",
            originalUCMNames: ["Wire", "Plug"]) == 0)
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_plug",
            originalUCMNames: ["Plug", "wire"]) == nil)
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_plug",
            originalUCMNames: ["Plug", "Wire", "Wire"]) == nil)
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_plug",
            originalUCMNames: ["Plug"]) == nil)
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_battery",
            originalUCMNames: ["Power01", "Wire"]) == nil)
        precondition(A.uniqueWireMarkerIndex(
            originalOwnerType: "tmo_power_plug",
            originalUCMNames: []) == nil)
        print("Original power-plug UCM Wire-only connector: PASS")
    }
}
