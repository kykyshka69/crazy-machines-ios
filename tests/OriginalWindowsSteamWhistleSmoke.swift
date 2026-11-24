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
        typealias Flask = CMOriginalFlaskGas
        precondition(Flask.focusedHeat(light: 0.5, displacement: .zero) == 5)
        precondition(Flask.focusedHeat(light: Float(0.5).nextDown, displacement: .zero) == nil)
        precondition(Flask.focusedHeat(light: 1, displacement: .init(0.08,0,0)) == nil)
        precondition(Flask.focusedHeat(light: 1, displacement: .init(0.079,0,2)) == 10)
        precondition(Flask.focusedHeat(light: .nan, displacement: .zero) == nil)
        let axis = SIMD3<Float>(0,1,0)
        for hz in [30,60,120] {
            var flask = Flask()
            let dt = 1/Double(hz)
            for _ in 0..<(hz*2) {
                precondition(flask.advance(input: nil, delta: dt, origin: .zero, forward: axis))
                precondition(flask.particles.isEmpty && !flask.goalReached)
            }
            precondition(!flask.advance(input: 11, delta: dt, origin: .zero, forward: axis))
            precondition(!flask.advance(input: 10, delta: dt, origin: .zero, forward: .zero))
            var first: Int?
            for i in 0..<(hz*3) {
                precondition(flask.advance(input: 10, delta: dt, origin: .zero, forward: axis))
                if flask.goalReached && first == nil {
                    first = i+1
                    precondition(flask.particles.count == 6)
                }
                precondition(flask.particles.count < 23)
            }
            precondition(first != nil && Double(first!)/Double(hz) > 0.5 && Double(first!)/Double(hz) < 0.8)
            for _ in 0..<(hz*25) {
                precondition(flask.advance(input: nil, delta: dt, origin: .zero, forward: axis))
            }
            precondition(flask.particles.isEmpty && !flask.goalReached && flask.gas < 0.001)
        }
        print("Win32 original steam whistle: pressure >= 1.0 inclusive x87 goal OK")
    }
}
