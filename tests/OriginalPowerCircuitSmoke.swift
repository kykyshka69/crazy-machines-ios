import Foundation

@main
struct OriginalPowerCircuitSmoke {
    static func main() throws {
        // Copyright-free scene with the REAL nested tmo_power_plug ownership
        // pattern. No guessed terminal-number-to-cable pairing.
        func plug(_ terminal: Int?) -> [String: Any] {
            ["name": "tmo_power_plug", "fields": terminal.map { ["VALF \($0).000000"] } ?? [],
             "children": []]
        }
        func device(_ name: String, _ terminals: [Int?]) -> [String: Any] {
            ["name": name, "fields": [], "children": terminals.map(plug)]
        }
        let raw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1", "index": 14,
            "title": "Original-format power plugs (non-copyright synthetic fixture)",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    device("tmo_power_battery", [nil]),
                    device("tmo_power_switch", [1, 2]),
                    device("tmo_power_distributor", [3, 4]),
                    device("tmo_power_motor", [5]),
                    device("tmo_power_lamp", [6]),
                    plug(7) // unowned original tmo_power_plug: no powered device
                ]]
            ]]
        ]
        let doc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        let session = CMOriginalGameplaySession(document: doc)
        guard var net = CMOriginalPowerCircuit(session: session) else {
            fatalError("Original terminal registry not recognized")
        }
        precondition(session.originalPowerTerminals.count == 8)
        precondition(net.terminals.count == 7)
        func terminal(_ number: Int) -> String {
            net.terminals.first { $0.number == number }!.plugID
        }
        let battery = net.terminals.first {
            $0.deviceType == "tmo_power_battery"
        }!
        let switchID = net.terminals.first {
            $0.deviceType == "tmo_power_switch"
        }!.deviceID
        let sourceID = battery.deviceID
        let motorID = net.terminals.first {
            $0.deviceType == "tmo_power_motor"
        }!.deviceID
        let junctionID = net.terminals.first {
            $0.deviceType == "tmo_power_distributor"
        }!.deviceID
        precondition(net.reachableDevices() == [sourceID])
        precondition(net.toggleCable(between: battery.plugID,
                                     and: terminal(1)) == .connected)
        precondition(net.toggleCable(between: terminal(2),
                                     and: terminal(3)) == .connected)
        precondition(net.toggleCable(between: terminal(4),
                                     and: terminal(5)) == .connected)
        precondition(net.reachableDevices().count == 2) // battery + open switch
        let withSwitch = net.reachableDevices(closedSwitchIDs: [switchID])
        precondition(withSwitch.contains(sourceID))
        precondition(withSwitch.contains(junctionID))
        precondition(withSwitch.contains(motorID))
        precondition(net.toggleCable(between: battery.plugID,
                                     and: terminal(6)) == .rejected)
        precondition(net.toggleCable(between: terminal(1),
                                     and: terminal(2)) == .rejected)
        // The original-format level also contains a standalone plug with
        // VALF 7. It must NOT appear among device-owned circuit terminals.
        let unowned = session.originalPowerTerminals.first {
            $0.originalTerminalNumber == 7
        }!
        precondition(unowned.deviceObjectID == nil)
        precondition(net.toggleCable(between: unowned.plugObjectID,
                                     and: terminal(6)) == .rejected)
        precondition(net.toggleCable(between: "invalid",
                                     and: terminal(6)) == .rejected)
        precondition(net.toggleCable(between: terminal(4),
                                     and: terminal(5)) == .disconnected)
        precondition(!net.reachableDevices(closedSwitchIDs: [switchID])
            .contains(motorID))
        net.reset()
        precondition(net.unwiredTerminalCount == 7)
        precondition(net.reachableDevices() == [sourceID])
        print("Original Win32 two-ended power-cable topology & switch isolation passed")
    }
}