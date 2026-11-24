import Foundation

@main
struct OriginalWindowsSwitchCircuitSmoke {
    static func main() throws {
        func device(_ name: String, _ numbers: [Int]) -> [String: Any] {
            ["name": name, "fields": [], "children": numbers.map { n in
                ["name": "tmo_power_plug", "fields": ["VALF \(n).000000"],
                 "children": []] as [String: Any]
            }]
        }
        let raw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1", "index": 18,
            "title": "Synthetic original Win32 +0xEC +0xC8 contact states",
            "scene_sha256": String(repeating: "c", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    device("tmo_power_battery", [1]),
                    device("tmo_power_switch", [2, 3]),
                    device("tmo_power_lamp", [4])
                ]]
            ]]
        ]
        let doc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        let session = CMOriginalGameplaySession(document: doc)
        guard var circuit = CMOriginalPowerCircuit(session: session) else {
            fatalError("Original-format electrical graph not parsed")
        }
        func plug(_ n: Int) -> String {
            circuit.terminals.first { $0.number == n }!.plugID
        }
        let sw = circuit.terminals.first {
            $0.deviceType == "tmo_power_switch"
        }!.deviceID
        let lamp = circuit.terminals.first {
            $0.deviceType == "tmo_power_lamp"
        }!.deviceID
        precondition(circuit.toggleCable(between: plug(1), and: plug(2)) == .connected)
        precondition(circuit.toggleCable(between: plug(3), and: plug(4)) == .connected)
        let matchedPositive = CMOriginalWindowsSwitchContactGate.ContactPair(
            selectedContact: 1, matingContact: 1)
        let mismatched = CMOriginalWindowsSwitchContactGate.ContactPair(
            selectedContact: 1, matingContact: -1)
        let matchedNegative = CMOriginalWindowsSwitchContactGate.ContactPair(
            selectedContact: -1, matingContact: -1)
        // Original physical contact states override the old prototype toggle.
        let yes = circuit.experimentalNetworkSignals(
            switchContactsByDeviceID: [sw: matchedPositive])
        precondition(yes[lamp] == 10)
        let blocked = circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            switchContactsByDeviceID: [sw: mismatched])
        precondition(blocked[lamp] == nil)
        precondition(blocked[sw] == nil) // true Win32 zero-write, not ghost power
        let negative = circuit.experimentalNetworkSignals(
            switchContactsByDeviceID: [sw: matchedNegative])
        precondition(negative[lamp] == 10)
        // Old manual experimental switch still works when real contacts are
        // absent; it must NOT override a true mismatched Win32 contact pair.
        precondition(circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw])[lamp] == 10)
        precondition(circuit.experimentalNetworkSignals()[lamp] == nil)
        let unknown = CMOriginalWindowsSwitchContactGate.ContactPair(
            selectedContact: .nan, matingContact: 1)
        precondition(circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            switchContactsByDeviceID: [sw: unknown])[lamp] == nil)
        typealias Gate = CMOriginalWindowsSwitchContactGate
        precondition(Gate.settledNativeContact(matingContact: -1, motion: -10) == -1)
        precondition(Gate.settledNativeContact(matingContact: Float(-1).nextDown, motion: -10) == -1)
        precondition(Gate.settledNativeContact(matingContact: Float(-1).nextUp, motion: -10) == nil)
        precondition(Gate.settledNativeContact(matingContact: -1, motion: 0) == nil)
        precondition(Gate.settledNativeContact(matingContact: .nan, motion: -10) == nil)
        // An in-flight lever must not power a motor simply because a tap
        // occurred. Exercise both directions and wrapped presentation angles.
        let rest: Float = 1
        precondition(!Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: rest))
        precondition(!Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: 0.7))
        precondition(Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: 0.4))
        precondition(!Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: 0.42))
        precondition(Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: 0.4 + 2 * .pi))
        precondition(!Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: .nan))
        for i in 0...120 {
            let angle = rest + Gate.sceneClosedOffset * Float(i) / 120
            let closed = Gate.sceneContactClosed(authoredOpenAngle: rest, observedAngle: angle)
            let signals = circuit.experimentalNetworkSignals(closedSwitchIDs: closed ? [sw] : [])
            precondition((signals[lamp] == 10) == closed)
            if i < 117 { precondition(!closed) }
        }
        print("Original Win32 ±1 switch contact state overrides prototype toggle and blocks ghost voltage")
    }
}