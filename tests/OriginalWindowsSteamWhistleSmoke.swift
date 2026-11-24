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
        typealias S = CMOriginalSteamNetwork
        func port(_ owner: String, _ x: Float, _ sign: Float) -> S.Port {
            .init(owner: owner, position: .init(x, 0, 0), normal: .init(sign, 0, 0))
        }
        let ports = [port("b",0,1),port("p",0.01,-1),port("p",1,1),
                     port("w",1.01,-1),port("w",2,1)]
        let types = ["b":"tmo_boiler","p":"tmo_pipe","w":"tmo_pipe_whistle"]
        precondition(S.mates(ports).count == 4)
        precondition(S.mates(ports + [port("other",0.012,-1)])[0] == nil)
        precondition(S.heatedBoilerSignal(fraction: 0.5) == 5)
        precondition(S.heatedBoilerSignal(fraction: .nan) == nil)
        precondition(S.decayedBoilerHeat(0.001, delta: 0.1) == 0)
        var state: [Int: Float] = [:]
        for _ in 0..<120 {
            state = S.advance(ports: ports, types: types, boilerSignals: ["b":5],
                              previous: state, delta: 1/60).outgoing
        }
        let r = S.advance(ports: ports, types: types, boilerSignals: ["b":5],
                          previous: state, delta: 1/60)
        precondition(abs(r.receiverSignals["w"]! - 5) < 0.001)
        let broken = [ports[0],ports[1],ports[2],port("w",1.1,-1),ports[4]]
        precondition(S.advance(ports: broken, types: types, boilerSignals: ["b":5],
                               previous: state, delta: 1/60).receiverSignals.isEmpty)
        precondition(S.advance(ports: ports, types: types, boilerSignals: ["b":0],
                               previous: [:], delta: 1/60).receiverSignals["w"] == 0)
        print("Win32 original steam whistle: pressure >= 1.0 inclusive x87 goal OK")
    }
}
