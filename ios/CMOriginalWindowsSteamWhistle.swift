import Foundation

/// Grounded in the original CrazyMachines.exe x86 path at 0x44C7D1–0x44C7EF.
/// Genuine tmo_pipe_whistle receives a steam component +0x40 and invokes
/// GOAL when its float value is GREATER THAN OR EQUAL TO 1.0.
/// At 0x44C7DF: test ah, 0x01; at 0x44C7E2: jne skip, so x87
/// equality (C0=0) is accepted. This differs from other goal cutoffs.
/// No steam pressure may be fabricated from cable voltage or touch.
public enum CMOriginalWindowsSteamWhistle {
    public static let cutoff: Float = 1.0

    public static func triggersGoal(steamPower: Float) -> Bool {
        steamPower.isFinite && steamPower >= cutoff
    }
}


/// Reconstructed pipe topology from original UCM Pipe attachment frames.
/// The snap tolerance is a SceneKit approximation, not a native constant.
/// Only mutually unique opposed ports may join; unmatched ends vent.
/// Valve traversal uses measured relative lever angle. Whistle downstream
/// throttling remains unsupported until its native angle mapping is known.
public enum CMOriginalSteamNetwork {
    public struct Port {
        public let owner: String
        public let position: SIMD3<Float>
        public let normal: SIMD3<Float>
        public init(owner: String, position: SIMD3<Float>, normal: SIMD3<Float>) {
            self.owner = owner; self.position = position; self.normal = normal
        }
    }

    public static func portCount(type: String) -> Int? {
        switch type {
        case "tmo_boiler", "tmo_steam_body": return 1
        case "tmo_pipe", "tmo_pipe_corner", "tmo_pipe_whistle", "tmo_pipe_ventil": return 2
        case "tmo_pipe_distributor": return 3
        default: return nil
        }
    }

    private static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        a.x*b.x + a.y*b.y + a.z*b.z
    }

    public static func mates(_ ports: [Port]) -> [Int: Int] {
        guard ports.count <= 1024 else { return [:] }
        var candidates = [[Int]](repeating: [], count: ports.count)
        for i in ports.indices {
            let a = ports[i]
            for j in (i+1)..<ports.count {
                let b = ports[j]
                guard a.owner != b.owner else { continue }
                let span = a.position - b.position
                let lengths = sqrt(dot(a.normal,a.normal)*dot(b.normal,b.normal))
                guard lengths.isFinite, lengths > 0.00001,
                      dot(span,span) <= 0.025*0.025,
                      dot(a.normal,b.normal)/lengths <= -0.98 else { continue }
                candidates[i].append(j); candidates[j].append(i)
            }
        }
        var result: [Int: Int] = [:]
        for i in ports.indices where candidates[i].count == 1 {
            let j = candidates[i][0]
            if candidates[j] == [i] { result[i] = j }
        }
        return result
    }

    /// 0x44DF00..0x44DF4C: subtract dt * Float32(0.1), clamp below zero.
    /// The output is copied BEFORE this decay; a source heat hit writes
    /// 10 * measured fraction at 0x44E260..0x44E291.
    public static func decayedBoilerHeat(_ previous: Float, delta: Double) -> Float? {
        guard previous.isFinite, previous >= 0, delta.isFinite,
              delta >= 0, delta <= 0.25 else { return nil }
        return max(0, previous - Float(delta * Double(Float(0.1))))
    }

    public static func heatedBoilerSignal(fraction: Float) -> Float? {
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { return nil }
        return fraction * 10
    }

    /// 0x44C53D..0x44C56E: ordinary pipe output moves towards input,
    /// with default radius parameter 0.5, multiplier 1000 and +1 denominator.
    public static func nextPipeSignal(previous: Float, input: Float, delta: Double) -> Float? {
        guard previous.isFinite, input.isFinite, previous >= 0, input >= 0,
              delta.isFinite, delta > 0, delta <= 0.25 else { return nil }
        return previous + (input - previous) / Float(1 + 500 * delta)
    }

    /// Native exit-count gate 0x44C2B2–0x44C2F0, modulo π.
    /// Equality at π/4 conducts. Missing angle fails closed.
    public static func valveConducts(ownerAngle: Float, leverAngle: Float) -> Bool {
        guard ownerAngle.isFinite, leverAngle.isFinite else { return false }
        let relative = ownerAngle - leverAngle + Float(bitPattern: 0x41490FDB)
        guard relative.isFinite else { return false }
        let phase = relative.truncatingRemainder(dividingBy: Float(bitPattern: 0x40490FDB))
        return phase >= Float(bitPattern: 0x3F490FDB)
    }

    /// Reconstructed acyclic single-source steam flow. The original
    /// 0x44C270 counts terminal exits before 0x44C4C2 divides branch
    /// input. Track each outgoing pipe scalar separately. Ambiguous
    /// loops, multiple boilers and missing geometry fail closed.
    /// A whistle's incoming scalar precedes its downstream lever gate.
    public static func advance(
        ports: [Port], types: [String: String], boilerSignals: [String: Float],
        previous: [Int: Float], delta: Double,
        openValveIDs: Set<String> = []
    ) -> (outgoing: [Int: Float], receiverSignals: [String: Float]) {
        let joined = mates(ports)
        let indices = Dictionary(grouping: ports.indices, by: { ports[$0].owner })
        var output: [Int: Float] = [:], receivers: [String: Float] = [:]
        var claimed = Set<String>()
        for source in boilerSignals.keys.sorted() {
            guard types[source] == "tmo_boiler",
                  let signal = boilerSignals[source], signal.isFinite, signal >= 0,
                  let starts = indices[source], starts.count == 1,
                  let start = starts.first, let incoming = joined[start] else { continue }
            var visited: Set<String> = [source]
            var children: [Int: [Int]] = [:], exits: [Int: Int] = [:]
            var valid = true
            func count(_ port: Int) -> Int {
                let owner = ports[port].owner
                guard visited.insert(owner).inserted,
                      let type = types[owner], let all = indices[owner],
                      all.count == portCount(type: type) else {
                    valid = false; return 0
                }
                if type == "tmo_pipe_whistle" || type == "tmo_steam_body" {
                    exits[port] = 1; return 1
                }
                if type == "tmo_pipe_ventil", !openValveIDs.contains(owner) {
                    // A shut valve contributes no terminal exits (0x44C2EE).
                    exits[port] = 0; return 0
                }
                guard ["tmo_pipe", "tmo_pipe_corner", "tmo_pipe_distributor", "tmo_pipe_ventil"].contains(type) else {
                    valid = false; return 0
                }
                let next = all.filter { $0 != port }
                children[port] = next
                var total = 0
                for out in next {
                    total += joined[out].map { count($0) } ?? 1
                }
                exits[port] = total
                return total
            }
            _ = count(incoming)
            guard valid, claimed.isDisjoint(with: visited) else {
                // Do not keep a first-source result in a mixed network.
                if !claimed.isDisjoint(with: visited) { return ([:], [:]) }
                continue
            }
            claimed.formUnion(visited)
            output[start] = signal
            func propagate(_ port: Int, _ input: Float) {
                let owner = ports[port].owner
                if children[port] == nil {
                    if types[owner] != "tmo_pipe_ventil" { receivers[owner] = input }
                    return
                }
                let next = children[port] ?? []
                let target = next.count > 1 && exits[port] == 0 ? 0 :
                    input / Float(next.count > 1 ? max(1, exits[port] ?? 1) : 1)
                for out in next {
                    let value = nextPipeSignal(previous: previous[out] ?? 0,
                                               input: target, delta: delta) ?? 0
                    output[out] = value
                    if let mate = joined[out] { propagate(mate, value) }
                }
            }
            propagate(incoming, signal)
        }
        return (output, receivers)
    }
}


/// Win32 flask Gas output and lifetime/count state (not generic heat GOAL).
/// 0x44E260–0x44E2F4 candle hit copies 10*fraction into Gas;
/// 0x44CF08–0x44CF54 magnifier focus uses strict planar .08 radius;
/// 0x45139D–0x451438 decay, emission rate and speed; 0x432708
/// sets lifetime 2s; 0x47373B–0x4737C2 counts emitted particles;
/// 0x4737E2–0x473883 ages and removes them; GOAL 0x4514AF
/// is conditional on the active particle count > 5, not Gas alone.
public struct CMOriginalFlaskGas {
    public struct Particle {
        public var position: SIMD3<Float>
        public let velocity: SIMD3<Float>
        public var remaining: Double
    }
    public private(set) var gas: Float = 0
    public private(set) var particles: [Particle] = []
    private var remainder: Double = 0
    public init() {}

    public static func focusedHeat(light: Float, displacement: SIMD3<Float>) -> Float? {
        guard light.isFinite, light >= 0.5, light <= 1,
              displacement.x.isFinite, displacement.y.isFinite,
              displacement.x*displacement.x + displacement.y*displacement.y < Float(0.08)*Float(0.08)
        else { return nil }
        return 10 * light
    }

    public var goalReached: Bool { particles.count > 5 }

    /// SceneKit projects the original Gas marker into world coordinates.
    /// Position/velocity direction is an adapter; the native emission
    /// rate, lifetime, count, decay and speed scalars are preserved.
    @discardableResult
    public mutating func advance(input: Float?, delta: Double,
                                 origin: SIMD3<Float>, forward: SIMD3<Float>) -> Bool {
        guard delta.isFinite, delta > 0, delta <= 0.25,
              [origin.x, origin.y, origin.z, forward.x, forward.y, forward.z].allSatisfy(\.isFinite),
              (input.map { $0.isFinite && (0...10).contains($0) } ?? true)
        else { return false }
        let length = sqrt(forward.x*forward.x + forward.y*forward.y + forward.z*forward.z)
        guard length.isFinite, length > 0.00001 else { return false }
        let initial = input ?? gas
        gas = min(10, Float(Double(initial) - Double(initial) / 2 * delta))
        let births = Double(gas) * delta + remainder
        let whole = Int(births.rounded(.down))
        remainder = births - Double(whole)
        let count = min(whole, max(0, 1000 - particles.count))
        let velocity = forward / length * (gas * Float(0.8) / 10)
        for _ in 0..<count {
            particles.append(Particle(position: origin, velocity: velocity, remaining: 2))
        }
        // Match native traversal: removal swaps in the tail, then
        // advances to the next slot (0x473808–0x47388A).
        var i = 0
        while i < particles.count {
            particles[i].remaining -= delta
            if particles[i].remaining < 0 {
                particles[i] = particles[particles.count - 1]
                particles.removeLast()
            } else {
                particles[i].position += particles[i].velocity * Float(delta)
            }
            i += 1
        }
        return true
    }
}
