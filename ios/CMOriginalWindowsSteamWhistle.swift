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
/// Valves and whistle downstream throttling are deliberately not traversed
/// until their native angle correspondence is available.
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
}
