import Foundation

@main
struct OriginalWindowsSolarCircuitSmoke {
    static func main() throws {
        func part(_ type: String, number: Int?, goal: Bool = false) -> [String: Any] {
            let child = number.map { [["name": "tmo_power_plug",
                                       "fields": ["VALF \($0).000000"],
                                       "children": []] as [String: Any]] } ?? []
            return ["name": type, "fields": goal ? ["GOAL 1"] : [], "children": child]
        }
        let level: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1", "index": 33,
            "title": "Synthetic real-format solar circuit",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    part("tmo_power_solarcell", number: 1, goal: true),
                    part("tmo_power_lamp", number: 2, goal: true),
                    part("tmo_power_battery", number: 3),
                    part("tmo_power_bell", number: 4, goal: true)
                ]]
            ]]
        ]
        let doc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: level))
        let session = CMOriginalGameplaySession(document: doc)
        guard var net = CMOriginalPowerCircuit(session: session) else {
            preconditionFailure("Original-format solar circuit rejected")
        }
        func id(_ type: String) -> String {
            net.terminals.first { $0.deviceType == type }!.deviceID
        }
        func plug(_ n: Int) -> String { net.terminals.first { $0.number == n }!.plugID }
        let solar = id("tmo_power_solarcell"), lamp = id("tmo_power_lamp")
        let battery = id("tmo_power_battery"), bell = id("tmo_power_bell")
        precondition(net.toggleCable(between: plug(1), and: plug(2)) == .connected)
        precondition(net.toggleCable(between: plug(3), and: plug(4)) == .connected)
        // A solar panel in original CML cannot become a free power source.
        precondition(net.experimentalNetworkSignals()[solar] == nil)
        precondition(net.experimentalNetworkSignals()[lamp] == nil)
        precondition(net.experimentalNetworkSignals()[battery] == 10)
        precondition(net.experimentalNetworkSignals()[bell] == 10)
        let empty = net.experimentalNetworkSignals(
            solarRayContributionsByDeviceID: [solar: []])
        precondition(empty[solar] == nil && empty[lamp] == nil)
        // Ray hit: (10/10) * 0.6 / (1*5) => 0.12 => panel signal 1.2.
        let photons = [solar: [Float(0.12)]]
        let lit = net.experimentalNetworkSignals(
            solarRayContributionsByDeviceID: photons)
        precondition(abs(lit[solar]! - 1.2) < 0.00001)
        precondition(abs(lit[lamp]! - 1.2) < 0.00001)
        precondition(lit[bell] == 10)  // no invented cross-cable mixing
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: lit,
            solarRayContributionsByDeviceID: photons) == [solar, bell])
        // Electrical power from other sources never invents a solar hit.
        let noRayGoal = CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [solar: 10, lamp: 10])
        precondition(noRayGoal == [lamp])
        // Boundary: solar Win32 GOAL must be strictly greater than 1.0.
        let threshold = [solar: [Float(0.1)]]
        precondition(!CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            solarRayContributionsByDeviceID: threshold).contains(solar))
        // A spoofed solar event for the wrong PC device must be ignored.
        precondition(net.experimentalNetworkSignals(
            solarRayContributionsByDeviceID: [lamp: [3]])[lamp] == nil)
        precondition(net.experimentalNetworkSignals(
            solarRayContributionsByDeviceID: [solar: [Float.nan]])[lamp] == nil)
        print("Win32 solar output needs actual ray observations; exact power scaling and GOAL isolated")
    }
}