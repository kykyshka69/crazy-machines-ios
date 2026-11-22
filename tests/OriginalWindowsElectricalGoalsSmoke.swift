import Foundation

@main
struct OriginalWindowsElectricalGoalsSmoke {
    static func main() throws {
        func object(_ name: String, goal: Bool = true) -> [String: Any] {
            ["name": name, "fields": goal ? ["GOAL 1"] : [], "children": []]
        }
        let root: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 14, "title": "Synthetic Win32 power threshold fixture",
            "scene_sha256": String(repeating: "d", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    object("tmo_power_lamp"),
                    object("tmo_power_lamp"),
                    object("tmo_power_lightning"),
                    object("tmo_power_bell"),
                    object("tmo_power_switch"),
                    object("tmo_power_lamp", goal: false)
                ]]
            ]]
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: root))
        let session = CMOriginalGameplaySession(document: document)
        precondition(session.objects.count == 6)
        let ids = session.objects.map(\.id)
        let powered = [ids[0]: Float(10), ids[1]: Float(3),
                       ids[2]: Float(1.5), ids[3]: Float(10),
                       ids[4]: Float(10), ids[5]: Float(10)]
        let active = CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: powered)
        precondition(active == Set([ids[0], ids[2], ids[3]]))
        let reverse = [ids[0]: Float(-10), ids[1]: Float(3.1),
                       ids[2]: Float(-10)]
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: reverse) == Set([ids[1]]))
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[3]: Float(-1.0001)]) == [ids[3]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[3]: Float(1)]) == [])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[0]: .nan]).isEmpty)
        print("Real Win32 electrical GOAL dispatch: lamp >3, lightning >1, bell abs(power) >1; never switch by voltage")
    }
}