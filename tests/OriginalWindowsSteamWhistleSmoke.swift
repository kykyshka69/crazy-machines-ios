import Foundation

@main
struct OriginalWindowsSteamWhistleSmoke {
    static func main() {
        precondition(!CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: 0))
        precondition(!CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: 0.999999))
        precondition(CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: 1))
        precondition(CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: 2))
        precondition(!CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: -1))
        precondition(!CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: .nan))
        precondition(!CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: .infinity))
        precondition(!CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: -.infinity))
        // Win32 lamp uses a separate strictly-greater-than-three cutoff.
        precondition(!CMOriginalWindowsPowerScalar.lampTriggersGoal(power: 3))
        print("Win32 original steam whistle: pressure >= 1.0 inclusive x87 goal OK")
    }
}
