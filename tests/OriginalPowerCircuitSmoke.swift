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
        let firstOnly = net.experimentalCablePowerSignals(
            powerByDeviceID: openSignal)
        precondition(firstOnly == [
            .init(battery.plugID, terminal(1)): 10
        ])
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: [sourceID: 10, switchID: -10]).isEmpty)
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: [sourceID: .nan, switchID: 10]).isEmpty)
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: [sourceID: .infinity, switchID: 10]).isEmpty)
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: [sourceID: -.infinity, switchID: 10]).isEmpty)
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: [sourceID: 0, switchID: 0]).isEmpty)
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
        let reencoded = try loaded.snapshotData()
        precondition(reencoded == snapshot)
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
        let allWires = net.experimentalCablePowerSignals(
            powerByDeviceID: closedSignal)
        precondition(allWires.count == 4)
        precondition(allWires.values.allSatisfy { $0 == 10 })
        precondition(CMOriginalWindowsPowerScalar.motorTriggersGoal(
            power: closedSignal[motorID]!))
        // Win32 scissors fires only when blade-angle difference is
        // strictly greater than the original float Pi/6 constant.
        typealias Scissors = CMOriginalScissorsCableGeometry
        let angle = Scissors.activationAngle
        precondition(!Scissors.activates(firstAngle: angle, secondAngle: 0))
        precondition(Scissors.activates(firstAngle: angle.nextUp, secondAngle: 0))
        precondition(Scissors.activates(firstAngle: -angle.nextUp, secondAngle: 0))
        precondition(!Scissors.activates(firstAngle: .nan, secondAngle: 0))
        let bladeA = SIMD3<Float>(0, 0, 0)
        let bladeB = SIMD3<Float>(0.2, 0, 0)
        func cutAt(_ x: Float, depth: Float = 0) -> Bool {
            Scissors.cuts(bladeStart: bladeA, bladeEnd: bladeB,
                cableStart: .init(x, -0.1, depth),
                cableEnd: .init(x, 0.1, depth))
        }
        precondition(cutAt(0.1))
        precondition(!cutAt(0.3))
        precondition(!cutAt(0.1, depth: 0.02))
        precondition(!cutAt(.nan))
        precondition(!Scissors.cuts(bladeStart: bladeA, bladeEnd: bladeA,
            cableStart: .init(0, -1, 0), cableEnd: .init(0, 1, 0)))
        // A real scissors cut is run-local, interrupts both authentic
        // endpoints, and never edits the saved player wiring arrangement.
        var cutRun = net
        let cutWire = CMOriginalPowerCircuit.Cable(terminal(4), terminal(5))
        precondition(cutRun.applyObservedCableCut(cutWire))
        precondition(!cutRun.applyObservedCableCut(cutWire))
        precondition(!cutRun.applyObservedCableCut(.init(terminal(1), terminal(6))))
        precondition(cutRun.cutPlugIDs == [terminal(4), terminal(5)])
        precondition(cutRun.cables == net.cables)
        precondition(cutRun.activeCables.count == 3)
        let cutSignals = cutRun.experimentalBatterySignals(closedSwitchIDs: [switchID])
        precondition(cutSignals[motorID] == nil && cutSignals[lampID] == nil)
        precondition(cutSignals[junctionID] == 10)
        precondition(cutRun.experimentalCablePowerSignals(powerByDeviceID: closedSignal)[cutWire] == nil)
        let cutSnapshot = try cutRun.snapshotData()
        precondition(cutSnapshot == snapshot)
        cutRun.clearRuntimeCuts()
        precondition(cutRun.activeCables == net.cables)
        precondition(cutRun.experimentalBatterySignals(closedSwitchIDs: [switchID])[lampID] == 10)
        precondition(cutRun.applyObservedCableCut(cutWire))
        precondition(cutRun.restoreSnapshot(snapshot))
        precondition(cutRun.cutPlugIDs.isEmpty)
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
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: net.experimentalBatterySignals(
                closedSwitchIDs: [switchID])).count == 2)
        net.reset()
        // Stale signal dictionaries cannot light deleted CML cables
        // because the actual user-authored cable set has been cleared.
        precondition(net.experimentalCablePowerSignals(
            powerByDeviceID: closedSignal).isEmpty)
        precondition(net.unwiredTerminalCount == 8)
        precondition(net.reachableDevices() == [sourceID])
        // Independent battery seeds are not evidence of current in the
        // direct cable: Win32 skips recursion into a second battery.
        var dualRaw = raw
        dualRaw["root"] = ["name": "level", "fields": [], "children": [
            ["name": "level_elements", "fields": [], "children": [
                device("tmo_power_battery", [11]),
                device("tmo_power_battery", [12])
            ]]
        ]]
        let dualDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: dualRaw))
        var dual = CMOriginalPowerCircuit(session:
            CMOriginalGameplaySession(document: dualDoc))!
        precondition(dual.terminals.count == 2)
        precondition(dual.toggleCable(between: dual.terminals[0].plugID,
                                      and: dual.terminals[1].plugID) == .connected)
        let independent = dual.experimentalBatterySignals()
        precondition(independent.count == 2)
        precondition(independent.values.allSatisfy { $0 == 10 })
        precondition(dual.experimentalCablePowerSignals(
            powerByDeviceID: independent).isEmpty)
        precondition(dual.experimentalNetworkObservation().cableSignals.isEmpty)
        // Equal values on two different open switch owners do not prove
        // that their unused outgoing ports have transmitted power.
        var splitRaw = raw
        splitRaw["root"] = ["name": "level", "fields": [], "children": [
            ["name": "level_elements", "fields": [], "children": [
                device("tmo_power_battery", [21]),
                device("tmo_power_switch", [22, 23]),
                device("tmo_power_switch", [24, 25]),
                device("tmo_power_battery", [26])
            ]]
        ]]
        let splitDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: splitRaw))
        var split = CMOriginalPowerCircuit(session:
            CMOriginalGameplaySession(document: splitDoc))!
        func splitPlug(_ n: Int) -> String {
            split.terminals.first { $0.number == n }!.plugID
        }
        for (a, b) in [(21,22),(23,24),(25,26)] {
            precondition(split.toggleCable(between: splitPlug(a), and: splitPlug(b)) == .connected)
        }
        let middle = CMOriginalPowerCircuit.Cable(splitPlug(23), splitPlug(24))
        let left = CMOriginalPowerCircuit.Cable(splitPlug(21), splitPlug(22))
        let right = CMOriginalPowerCircuit.Cable(splitPlug(25), splitPlug(26))
        let splitOpen = split.experimentalNetworkObservation()
        precondition(splitOpen.deviceSignals.count == 4)
        precondition(splitOpen.cableSignals == [left: 10, right: 10])
        precondition(splitOpen.cableSignals[middle] == nil)
        let switchIDs = Set(split.terminals.filter { $0.deviceType == "tmo_power_switch" }.map(\.deviceID))
        let splitClosed = split.experimentalNetworkObservation(closedSwitchIDs: switchIDs)
        precondition(splitClosed.deviceSignals.count == 2)
        precondition(splitClosed.cableSignals.isEmpty)
        precondition(split.applyObservedCableCut(left))
        precondition(split.experimentalNetworkObservation().cableSignals == [right: 10])
        split.clearRuntimeCuts()
        precondition(split.experimentalNetworkObservation().cableSignals == [left: 10, right: 10])
        let blockedID = split.terminals.first { $0.number == 22 }!.deviceID
        let blocked = split.experimentalNetworkObservation(switchContactsByDeviceID: [
            blockedID: .init(selectedContact: 1, matingContact: -1)])
        precondition(blocked.deviceSignals[blockedID] == nil)
        precondition(blocked.cableSignals[left] == 10)
        precondition(blocked.cableSignals[middle] == nil)
        // Ordered native reference: first arrival owns this pass,
        // but resetting visit marks alone does not erase stored signals.
        var orderedRaw = raw
        orderedRaw["root"] = ["name": "level", "fields": [], "children": [
            ["name": "level_elements", "fields": [], "children": [
                device("tmo_power_generator", [21]),
                device("tmo_power_switch", [22, 23]),
                device("tmo_power_switch", [24, 25]),
                device("tmo_power_battery", [26])
            ]]
        ]]
        let orderedDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: orderedRaw))
        var ordered = CMOriginalPowerCircuit(session:
            CMOriginalGameplaySession(document: orderedDoc))!
        func orderedPlug(_ n: Int) -> String {
            ordered.terminals.first { $0.number == n }!.plugID
        }
        for (a, b) in [(21,22),(23,24),(25,26)] {
            precondition(ordered.toggleCable(between: orderedPlug(a), and: orderedPlug(b)) == .connected)
        }
        let orderedMiddle = CMOriginalPowerCircuit.Cable(orderedPlug(23), orderedPlug(24))
        let orderedSwitchIDs = Set(ordered.terminals.filter { $0.deviceType == "tmo_power_switch" }.map(\.deviceID))
        let orderedBlockedID = ordered.terminals.first { $0.number == 22 }!.deviceID
        typealias Event = CMOriginalPowerCircuit.NativePortEvent
        let lSource = Event.source(plugID: orderedPlug(21), value: 3)
        let rSource = Event.source(plugID: orderedPlug(26), value: 10)
        let gates = Dictionary(uniqueKeysWithValues: orderedSwitchIDs.map { ($0, true) })
        let first = ordered.nativePortPass(events: [lSource, rSource],
                                         conductingByDeviceID: gates)!
        precondition(first.signals[orderedPlug(24)] == 3)
        precondition(first.signals[orderedPlug(26)] == 10)
        let reverse = ordered.nativePortPass(events: [rSource, lSource],
                                           conductingByDeviceID: gates)!
        precondition(reverse.signals[orderedPlug(23)] == 10)
        let resetOnly = ordered.nativePortPass(previous: first, events: [.resetVisited],
                                             conductingByDeviceID: gates)!
        precondition(resetOnly.signals == first.signals)
        precondition(resetOnly.visitedOwners.isEmpty)
        let stopped = ordered.nativePortPass(previous: first, events: [.resetVisited,
            .source(plugID: orderedPlug(21), value: 0)], conductingByDeviceID: gates)!
        precondition(stopped.signals[orderedPlug(22)] == 0)
        precondition(stopped.signals[orderedPlug(24)] == 0)
        precondition(stopped.signals[orderedPlug(26)] == 10)
        var openGates = gates
        openGates[orderedBlockedID] = false
        let opened = ordered.nativePortPass(previous: first, events: [.resetVisited, lSource],
                                          conductingByDeviceID: openGates)!
        precondition(opened.signals[orderedPlug(22)] == 3)
        precondition(opened.signals[orderedPlug(23)] == 0)
        precondition(opened.signals[orderedPlug(24)] == 0)
        precondition(ordered.nativePortPass(events: [lSource], conductingByDeviceID: [:]) == nil)
        precondition(ordered.applyObservedCableCut(orderedMiddle))
        let severed = ordered.nativePortPass(previous: first, events: [.cutTransfer(orderedMiddle)],
                                           conductingByDeviceID: gates)!
        precondition(severed.signals[orderedPlug(23)] == 0)
        precondition(severed.signals[orderedPlug(24)] == 0)
        ordered.clearRuntimeCuts()
        precondition(ordered.nativePortPass(events: [.cutTransfer(orderedMiddle)],
                                          conductingByDeviceID: gates) == nil)
        print("Original Win32 cables, multiport motor load-through and switch isolation passed")
    }
}