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
                    device("tmo_power_motor", [5, 8]),
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
        precondition(session.originalPowerTerminals.count == 9)
        precondition(net.terminals.count == 8)
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
        let lampID = net.terminals.first {
            $0.deviceType == "tmo_power_lamp"
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
        // Two distinct original motor plugs are explicitly wired. The
        // genuine Win32 walker visits the outgoing port when reached from
        // the incoming one; a motor with just one plug cannot do this.
        precondition(net.toggleCable(between: terminal(8),
                                     and: terminal(6)) == .connected)
        precondition(net.reachableDevices().count == 2) // battery + open switch
        // Genuine battery writes 10.0 to +0x40 in the Win32 executable.
        // The iOS experimental topology must NOT leak across an open switch.
        let openSignal = net.experimentalBatterySignals()
        precondition(openSignal[sourceID] == 10)
        precondition(openSignal[motorID] == nil)
        precondition(openSignal[lampID] == nil)
        precondition(CMOriginalWindowsPowerScalar.motorRotorCommand(
            from: openSignal[sourceID]!) == -10)
        // A cable arrangement survives app/level re-entry only for this
        // exact imported original scene, and is revalidated on restoration.
        let snapshot = try net.snapshotData()
        precondition(net.snapshotStorageKey.contains(session.sceneSHA256))
        var loaded = CMOriginalPowerCircuit(session: session)!
        precondition(loaded.cableCount == 0)
        precondition(loaded.restoreSnapshot(snapshot))
        precondition(loaded.cables == net.cables)
        precondition(loaded.snapshotData() == snapshot)
        // Bad data, unknown versions, cross-level files, duplicate wires,
        // wrong source IDs and occupied plugs all fail atomically.
        let originalCables = loaded.cables
        precondition(!loaded.restoreSnapshot(Data(snapshot.dropLast())))
        precondition(loaded.cables == originalCables)
        func tampered(_ alter: (inout [String: Any]) -> Void) throws -> Data {
            var object = try JSONSerialization.jsonObject(
                with: snapshot) as! [String: Any]
            alter(&object)
            return try JSONSerialization.data(withJSONObject: object)
        }
        let wrongVersion = try tampered { $0["version"] = 99 }
        let wrongScene = try tampered { $0["sceneSHA256"] = String(repeating: "b", count: 64) }
        let wrongLevel = try tampered { $0["levelIndex"] = 13 }
        let repeated = try tampered { $0["cables"] =
            ($0["cables"] as! [[String: Any]]) +
            [($0["cables"] as! [[String: Any]])[0]] }
        let alien = try tampered { object in
            var wires = object["cables"] as! [[String: Any]]
            wires[0]["firstPlugID"] = "not-an-original-object"
            object["cables"] = wires
        }
        for invalid in [wrongVersion, wrongScene, wrongLevel, repeated, alien] {
            precondition(!loaded.restoreSnapshot(invalid))
            precondition(loaded.cables == originalCables)
        }
        loaded.reset()
        precondition(loaded.cableCount == 0)
        precondition(loaded.restoreSnapshot(snapshot))
        precondition(loaded.cables == originalCables)

        let closedSignal = net.experimentalBatterySignals(
            closedSwitchIDs: [switchID])
        precondition(closedSignal[motorID] == 10)
        precondition(closedSignal[lampID] == 10)
        precondition(CMOriginalWindowsPowerScalar.motorTriggersGoal(
            power: closedSignal[motorID]!))
        let withSwitch = net.reachableDevices(closedSwitchIDs: [switchID])
        precondition(withSwitch.contains(sourceID))
        precondition(withSwitch.contains(junctionID))
        precondition(withSwitch.contains(motorID))
        precondition(withSwitch.contains(lampID))
        precondition(net.toggleCable(between: battery.plugID,
                                     and: terminal(6)) == .rejected)
        precondition(net.toggleCable(between: terminal(1),
                                     and: terminal(2)) == .rejected)
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
        precondition(net.experimentalBatterySignals(
            closedSwitchIDs: [switchID])[lampID] == nil)
        precondition(net.experimentalBatterySignals(
            closedSwitchIDs: [switchID])[motorID] == nil)
        net.reset()
        precondition(net.unwiredTerminalCount == 8)
        precondition(net.reachableDevices() == [sourceID])
        print("Original Win32 cables, multiport motor load-through and switch isolation passed")
    }
}