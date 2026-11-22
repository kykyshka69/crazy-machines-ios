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
        solarRayContributionsByDeviceID: [String: [Float]] = [:]
    ) -> Set<String> {
        var active = Set<String>()
        for object in session.objects {
            guard object.goalAnnotation == "1"
                    || object.fields["GOAL"]?.contains("1") == true
            else { continue }
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
            guard let power = powerByDeviceID[object.id], power.isFinite
            else { continue }
            switch object.type {
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
                // Switch, C4, motor and unrelated GOAL parts have their own
                // callbacks. Never infer those solely from voltage.
                break
            }
        }
        return active
    }
}