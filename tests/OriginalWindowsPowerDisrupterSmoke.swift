import Foundation

@main
struct OriginalWindowsPowerDisrupterSmoke {
    static func main() throws {
        let pi = CMOriginalWindowsPowerDisrupter.period
        let h = CMOriginalWindowsPowerDisrupter.halfTurnGate
        func gate(_ x: Float) -> Bool {
            CMOriginalWindowsPowerDisrupter.conducts(rotorAngle: x)
        }
        precondition(gate(0))
        precondition(gate(h * 0.5))
        precondition(!gate(h))
        precondition(!gate(h * 1.5))
        precondition(gate(pi)) // fmod(+Pi,+Pi) = +0
        precondition(gate(-pi)) // fmod(-Pi,+Pi) = -0
        precondition(!gate(-h))
        precondition(!gate(-h * 0.5))
        precondition(gate(-h * 1.5))
        precondition(!gate(.nan))
        precondition(!gate(.infinity))
        precondition(!gate(-.infinity))

        typealias Observation = CMOriginalWindowsPowerDisrupter.Observation
        var previous: Observation?
        var transitions: [Observation] = []
        // Rapid closed/open transitions and the unavailable-to-measured
        // blocked transition must all survive renderer change suppression.
        for angle: Float in [.nan, .nan, h, h * 1.1, 0, h, 0, .nan, h] {
            let sample = CMOriginalWindowsPowerDisrupter.observation(rotorAngle: angle)
            if sample != previous {
                transitions.append(sample)
                previous = sample
            }
        }
        precondition(transitions == [.unavailable, .blocked, .conducting,
            .blocked, .conducting, .unavailable, .blocked])
        precondition(CMOriginalWindowsPowerDisrupter.observation(rotorAngle: .infinity) == .unavailable)

        // Use the same tmo_* hierarchy roles as the original Windows scene:
        // a battery, two disrupter terminals, and a lamp (not scene replicas).
        func item(_ name: String, _ terminals: [Int]) -> [String: Any] {
            ["name": name, "fields": [], "children": terminals.map { n in
                ["name": "tmo_power_plug", "fields": ["VALF \(n).000000"],
                 "children": []] as [String: Any]
            }]
        }
        let raw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1", "index": 18,
            "title": "Disrupter original-format connection contract",
            "scene_sha256": String(repeating: "b", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    item("tmo_power_battery", [1]),
                    item("tmo_power_disrupter", [2, 3]),
                    item("tmo_power_switch", [4, 5]),
                    item("tmo_power_lamp", [6])
                ]]
            ]]
        ]
        let doc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        let session = CMOriginalGameplaySession(document: doc)
        guard var net = CMOriginalPowerCircuit(session: session) else {
            preconditionFailure("Real-format disrupter not recognized")
        }
        func plug(_ n: Int) -> String {
            net.terminals.first { $0.number == n }!.plugID
        }
        func owner(_ type: String) -> String {
            net.terminals.first { $0.deviceType == type }!.deviceID
        }
        let disrupter = owner("tmo_power_disrupter")
        let sw = owner("tmo_power_switch")
        let lamp = owner("tmo_power_lamp")
        precondition(net.toggleCable(between: plug(1), and: plug(2)) == .connected)
        precondition(net.toggleCable(between: plug(3), and: plug(4)) == .connected)
        precondition(net.toggleCable(between: plug(5), and: plug(6)) == .connected)

        func powered(_ angle: Float?, switchClosed: Bool) -> Bool {
            let phases = angle.map { [disrupter: $0] } ?? [:]
            let closed = switchClosed ? Set([sw]) : Set<String>()
            return net.experimentalBatterySignals(
                closedSwitchIDs: closed,
                disrupterRotorAnglesByDeviceID: phases
            )[lamp] == CMOriginalWindowsPowerScalar.batterySource
        }
        precondition(!powered(nil, switchClosed: true)) // missing orientation: fail closed
        precondition(net.experimentalBatterySignals(closedSwitchIDs: [sw])[disrupter] == nil)
        precondition(!powered(0, switchClosed: false)) // original switch not toggled
        precondition(powered(0, switchClosed: true))
        precondition(!powered(h, switchClosed: true))
        precondition(net.experimentalBatterySignals(closedSwitchIDs: [sw],
            disrupterRotorAnglesByDeviceID: [disrupter: h])[disrupter] == nil)
        precondition(powered(-h * 1.5, switchClosed: true))
        precondition(!powered(-h * 0.5, switchClosed: true))
        precondition(!powered(.nan, switchClosed: true))
        print("Verified original Win32 disrupter phase gating and switch-controlled cable route")
    }
}