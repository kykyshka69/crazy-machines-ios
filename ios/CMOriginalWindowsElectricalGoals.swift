import Foundation

/// The subset of the original Win32 goal dispatcher that has an actual
/// power-dependent element callback proven by disassembly.
///
/// The original engine's generic GOAL flag alone is NOT a win signal.
/// Lamp: 0x44D9C4...0x44D9E5 and lightning: 0x450E5F...0x450E90
/// explicitly examine their +0x40 electrical values before calling 0x44B460.
/// A caller must provide an *actual or explicitly experimental* power state.
public enum CMOriginalWindowsElectricalGoals {
    public static func activeGoalIDs(
        session: CMOriginalGameplaySession,
        powerByDeviceID: [String: Float],
        // Explicit photometry produced from observed, original ray hits.
        // Solar GOAL is not awarded for battery voltage or mere proximity.
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        // Actual generator channel-0 GOAL depends on its rotor command,
        // not a voltage from an adjacent device.
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        // Original whistle receives steam from a real physical pressure
        // component, NOT an electrical cable or ordinary collision.
        steamPressureByObjectID: [String: Float] = [:],
        // Native belt-flag telescope and measured instantaneous wind sum, never
        // inferred from a rotating UCM wheel or a GOAL annotation alone.
        beltFlagRuntimeByObjectID: [String: CMOriginalWindowsBeltFlag.ObservedState] = [:],
        // Original flower's *physical* growth-state scalar (+0x130),
        // supplied only by a recovered native light/clock path.
        flowerNativeProgressByObjectID: [String: Float] = [:]
    ) -> Set<String> {
        var active = Set<String>()
        for object in session.objects {
            guard object.goalAnnotation == "1"
                    || object.fields["GOAL"]?.contains("1") == true
            else { continue }
            // Native 0x450018–0x450039 requires the genuine flower
            // physical progress +0x130 <= 0.5, not just a visible lamp
            // or unobstructed 3D line of sight. No invented photometry.
            if object.type == "tmo_light_flower" {
                if let progress = flowerNativeProgressByObjectID[object.id],
                   CMOriginalWindowsFlower.triggersGoal(
                        observedNativeProgress: progress
                   ) {
                    active.insert(object.id)
                }
                continue
            }
            // Original level 34 carries GOAL on tmo_belt_flag. Its
            // two x86 GOAL call sites at 0x44FA58/0x44FAA1 compare the
            // actual telescope/flag/native WIND state, not wheel rotation.
            // Missing runtime observations MUST NOT credit a puzzle.
            if object.type == "tmo_belt_flag" {
                if let state = beltFlagRuntimeByObjectID[object.id],
                   CMOriginalWindowsBeltFlag.triggersGoal(state) {
                    active.insert(object.id)
                }
                continue
            }
            // Native x87 0x44C7DF tests only the C0 less-than flag,
            // so the original steam-whistle GOAL includes pressure = 1.
            // This channel is entirely separate from electrical voltage.
            if object.type == "tmo_pipe_whistle" {
                if let steam = steamPressureByObjectID[object.id],
                   CMOriginalWindowsSteamWhistle.triggersGoal(
                        steamPower: steam
                   ) {
                    active.insert(object.id)
                }
                continue
            }
            // Photometric solar power and electrical receiver power are
            // separate channels; a battery connected to a solar cell must
            // not fabricate sunshine or its GOAL event.
            if object.type == "tmo_power_solarcell" {
                if let rays = solarRayContributionsByDeviceID[object.id],
                   let output = CMOriginalWindowsSolarSignal
                    .collectedPower(rayContributions: rays),
                   CMOriginalWindowsSolarSignal.triggersGoal(solarPower: output) {
                    active.insert(object.id)
                }
                continue
            }
            // Win32 0x44BCC7: generator GOAL uses the rotor's +0xE8
            // scalar. Cable power alone never substitutes for motion.
            if object.type == "tmo_power_generator" {
                if let rotor = generatorRotorCommandsByDeviceID[object.id],
                   CMOriginalWindowsPowerScalar.generatorTriggersGoal(rotor: rotor) {
                    active.insert(object.id)
                }
                continue
            }
            guard let power = powerByDeviceID[object.id], power.isFinite
            else { continue }
            switch object.type {
            case "tmo_power_motor":
                // Win32 0x450A2D: rotor command = -power; at 0x450A53
                // abs(command) > 0.5 dispatches its GOAL channel.
                if CMOriginalWindowsPowerScalar.motorTriggersGoal(power: power) {
                    active.insert(object.id)
                }
            case "tmo_power_lamp":
                if CMOriginalWindowsPowerScalar.lampTriggersGoal(power: power) {
                    active.insert(object.id)
                }
            case "tmo_power_lightning":
                if CMOriginalWindowsPowerScalar.lightningTriggersGoal(power: power) {
                    active.insert(object.id)
                }
            case "tmo_power_bell":
                if CMOriginalWindowsPowerScalar.bellTriggersGoal(power: power) {
                    active.insert(object.id)
                }
            default:
                // Switch, C4 and unrelated GOAL parts have their own
                // callbacks. Never infer those solely from voltage.
                break
            }
        }
        return active
    }
}