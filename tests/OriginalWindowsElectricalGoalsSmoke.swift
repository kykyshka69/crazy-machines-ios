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
                    object("tmo_power_lamp", goal: false),
                    object("tmo_power_motor"),
                    object("tmo_power_generator"),
                    object("tmo_power_generator", goal: false),
                    object("tmo_pipe_whistle"),
                    object("tmo_pipe_whistle", goal: false),
                    object("tmo_belt_flag"),
                    object("tmo_belt_flag", goal: false),
                    object("tmo_light_flower"),
                    object("tmo_light_flower", goal: false),
                    object("tmo_windmill", goal: false),
                    object("tmo_heat_rocket"),
                    object("tmo_heat_rocket", goal: false)
                ]]
            ]]
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: root))
        let session = CMOriginalGameplaySession(document: document)
        precondition(session.objects.count == 18)
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
        // Motor requires an actual finite electrical input.
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[6]: 0.5]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[6]: -0.5001]) == [ids[6]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[6]: 0.5001]) == [ids[6]])
        // A generator receiving cable voltage is NOT a spinning generator.
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[7]: 10]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            generatorRotorCommandsByDeviceID: [ids[7]: 1]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            generatorRotorCommandsByDeviceID: [ids[7]: -1.0001]) == [ids[7]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[6]: -10],
            generatorRotorCommandsByDeviceID: [
                ids[7]: 2, ids[8]: 3, ids[4]: 4
            ]) == Set([ids[6], ids[7]]))
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            generatorRotorCommandsByDeviceID: [ids[7]: .nan]).isEmpty)
        // Only a real steam-source +0x40 can credit a whistle.
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[9]: 10]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            steamPressureByObjectID: [ids[9]: 1]) == [ids[9]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            steamPressureByObjectID: [ids[9]: 0.99999]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            steamPressureByObjectID: [ids[9]: .nan]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            steamPressureByObjectID: [ids[10]: 2]).isEmpty)
        // A native level-34 GOAL requires real telescope state +0x90,
        // source +0xEC, and abs(per-call summed wind at [ebp-0x284]).
        // An electrically powered flag, generic wheel contact or
        // invented telemetry for a GOAL-free object never counts.
        typealias Flag = CMOriginalWindowsBeltFlag
        let qualified = Flag.PhysicalObservation(
            telescopeIndicator: Flag.nativeTelescopeMarker, flagState: 0,
            windSources: [.init(originalSourceID: ids[15],
                originalSourceType: "tmo_windmill",
                signedIntersection: 0.8, originalWindPower: 10)],
            allOriginalSourcesObserved: true)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[11]: 10]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            beltFlagPhysicalInputsByObjectID: [ids[11]: qualified]) == [ids[11]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            beltFlagPhysicalInputsByObjectID: [ids[12]: qualified]).isEmpty)
        // Same real source ID but falsely labelled as a different
        // native emitter kind must not count as a valid physical event.
        let incorrectOriginalKind = Flag.PhysicalObservation(
            telescopeIndicator: Flag.nativeTelescopeMarker, flagState: 0,
            windSources: [.init(originalSourceID: ids[15],
                originalSourceType: "tmo_wind_bellows",
                signedIntersection: 0.8, originalWindPower: 10)],
            allOriginalSourcesObserved: true)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            beltFlagPhysicalInputsByObjectID:
                [ids[11]: incorrectOriginalKind]).isEmpty)
        let tooShort = Flag.PhysicalObservation(
            telescopeIndicator: Flag.nativeTelescopeMarker, flagState: 0,
            windSources: [.init(originalSourceID: ids[15],
                originalSourceType: "tmo_windmill",
                signedIntersection: 0.2, originalWindPower: 10)],
            allOriginalSourcesObserved: true)
        // A missing actual windmill must not trigger a low-wind GOAL.
        let missing = Flag.PhysicalObservation(
            telescopeIndicator: 0, flagState: 0,
            windSources: [], allOriginalSourcesObserved: true)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            beltFlagPhysicalInputsByObjectID: [ids[11]: missing]).isEmpty)
        let incomplete = Flag.PhysicalObservation(
            telescopeIndicator: 0, flagState: 0,
            windSources: qualified.windSources, allOriginalSourcesObserved: false)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            beltFlagPhysicalInputsByObjectID: [ids[11]: incomplete]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            beltFlagPhysicalInputsByObjectID: [ids[11]: tooShort]).isEmpty)
        // Native original tmo_light_flower uses physical growth +0x130;
        // CML GOAL or an unrelated battery does not provide that input.
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[13]: 10]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            flowerNativeProgressByObjectID: [ids[13]: 0.5]) == [ids[13]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            flowerNativeProgressByObjectID: [ids[13]: 0.5001]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            flowerNativeProgressByObjectID: [ids[14]: 0.2]).isEmpty)
        // Rocket requires a real Engine child and an actual observed
        // explosion effect, after its SECOND >3s native clock.
        typealias Rocket = CMOriginalWindowsRocketTimer
        let tooEarlyRocket = Rocket.ObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7, originalLaunchTime: 4,
            actualExplosionEffectObserved: true)
        let explodedRocket = Rocket.ObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7.01, originalLaunchTime: 4,
            actualExplosionEffectObserved: true)
        let unconfirmedRocket = Rocket.ObservedExplosion(
            nativeRocketState: 2, nativeEnginePresent: true,
            engineTime: 7.01, originalLaunchTime: 4,
            actualExplosionEffectObserved: false)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [ids[16]: 10]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            rocketExplosionByObjectID: [ids[16]: tooEarlyRocket]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            rocketExplosionByObjectID: [ids[16]: unconfirmedRocket]).isEmpty)
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            rocketExplosionByObjectID: [ids[16]: explodedRocket]) == [ids[16]])
        precondition(CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: session, powerByDeviceID: [:],
            rocketExplosionByObjectID: [ids[17]: explodedRocket]).isEmpty)
        print("Recovered Win32 GOAL: original electric, steam, flower, wind and rocket explosion gates")
    }
}