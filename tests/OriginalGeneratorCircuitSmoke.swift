import Foundation

@main
struct OriginalGeneratorCircuitSmoke {
    static func main() throws {
        func device(_ name: String, _ nums: [Int]) -> [String: Any] {
            ["name": name, "fields": [], "children": nums.map { n in
                ["name": "tmo_power_plug", "fields": ["VALF \(n).000000"],
                 "children": []] as [String: Any]
            }]
        }
        let raw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 12, "title": "Copyright-free genuine-format generator circuit",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    device("tmo_power_battery", [1]),
                    device("tmo_power_generator", [2]),
                    device("tmo_power_switch", [3, 4]),
                    device("tmo_power_motor", [5]),
                    device("tmo_power_lamp", [6])
                ]]
            ]]
        ]
        let doc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        let session = CMOriginalGameplaySession(document: doc)
        guard var circuit = CMOriginalPowerCircuit(session: session) else {
            preconditionFailure("Real-format generator circuit rejected")
        }
        func owned(_ type: String) -> String {
            circuit.terminals.first { $0.deviceType == type }!.deviceID
        }
        func plug(_ n: Int) -> String {
            circuit.terminals.first { $0.number == n }!.plugID
        }
        let generator = owned("tmo_power_generator")
        let battery = owned("tmo_power_battery")
        let sw = owned("tmo_power_switch")
        let motor = owned("tmo_power_motor")
        let lamp = owned("tmo_power_lamp")
        precondition(circuit.toggleCable(between: plug(2), and: plug(3)) == .connected)
        precondition(circuit.toggleCable(between: plug(4), and: plug(5)) == .connected)
        precondition(circuit.experimentalNetworkSignals()[battery] == 10)
        precondition(circuit.experimentalNetworkSignals()[motor] == nil)
        precondition(circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            generatorRotorCommandsByDeviceID: [generator: 0])[motor] == nil)
        let moving = circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            generatorRotorCommandsByDeviceID: [generator: -2])
        precondition(moving[motor] == 2)
        precondition(moving[generator] == 2)
        precondition(moving[battery] == 10)
        precondition(moving[lamp] == nil) // no phantom connection
        precondition(CMOriginalWindowsPowerScalar.motorTriggersGoal(power: moving[motor]!))
        // Generator on one side of an open switch MUST NOT power motor.
        precondition(circuit.experimentalNetworkSignals(
            generatorRotorCommandsByDeviceID: [generator: 2])[motor] == nil)
        // A positive rotor movement yields the same power magnitude.
        precondition(circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            generatorRotorCommandsByDeviceID: [generator: 2])[motor] == 2)
        // A lamp connected only to a moving generator, via the motor load,
        // cannot leak electricity through that load.
        precondition(circuit.toggleCable(between: plug(1), and: plug(6)) == .connected)
        let parallel = circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            generatorRotorCommandsByDeviceID: [generator: 2])
        precondition(parallel[lamp] == 10)
        precondition(parallel[motor] == 2)
        precondition(circuit.toggleCable(between: plug(4), and: plug(5)) == .disconnected)
        precondition(circuit.experimentalNetworkSignals(
            closedSwitchIDs: [sw],
            generatorRotorCommandsByDeviceID: [generator: 2])[motor] == nil)
        print("Original generator rotor → abs power signal → wired switch → motor, no source hallucination")
    }
}