import Foundation

@main
struct OriginalWindowsMechanicalTransferSmoke {
    static func main() {
        typealias M = CMOriginalWindowsMechanicalTransfer
        func close(_ value: Float?, _ expected: Float) -> Bool {
            guard let value else { return false }
            return abs(value - expected) < 0.00001
        }
        // Values from original PC CML: motor rotor/gear VALF=0.125;
        // original conveyor wheel VALF=0.100.
        precondition(close(M.transmittedSignal(sourceSignal: 2,
            sourceVALF: 0.125, targetVALF: 0.125), 2))
        precondition(close(M.transmittedSignal(sourceSignal: 2,
            sourceVALF: 0.125, targetVALF: 0.1), 2.5))
        precondition(close(M.transmittedSignal(sourceSignal: 2,
            sourceVALF: 0.125, targetVALF: 0.1,
            reversesDirection: true), -2.5))
        precondition(close(M.transmittedSignal(sourceSignal: -2,
            sourceVALF: 0.1, targetVALF: 0.125), -1.6))
        precondition(M.transmittedSignal(sourceSignal: 0,
            sourceVALF: 0.125, targetVALF: 0.1) == 0)
        precondition(M.transmittedSignal(sourceSignal: 10,
            sourceVALF: 0.125, targetVALF: 0) == nil)
        precondition(M.transmittedSignal(sourceSignal: 10,
            sourceVALF: 0.125, targetVALF: -0.1) == nil)
        precondition(M.transmittedSignal(sourceSignal: .nan,
            sourceVALF: 0.125, targetVALF: 0.1) == nil)
        precondition(M.transmittedSignal(sourceSignal: Float.greatestFiniteMagnitude,
            sourceVALF: Float.greatestFiniteMagnitude,
            targetVALF: 0.01) == nil)
        precondition(close(M.decayedSignal(previous: 4,
            observedNativeStep: 0.25), 3))
        precondition(close(M.decayedSignal(previous: -4,
            observedNativeStep: 0.5), -2))
        precondition(close(M.decayedSignal(previous: 4,
            observedNativeStep: 1), 0))
        precondition(M.decayedSignal(previous: 4,
            observedNativeStep: -0.01) == nil)
        precondition(M.decayedSignal(previous: 4,
            observedNativeStep: .nan) == nil)
        typealias R = CMOriginalRope
        let hook = R.Endpoint(objectID: "hook", marker: "Rope")
        let lever = R.Endpoint(objectID: "lever", marker: "Rope02")
        precondition(R.Pair(hook, lever) == R.Pair(lever, hook))
        precondition(R.Pair(hook, hook) == nil)
        precondition(R.accepts(type: "tmo_rope_hook", marker: "Rope"))
        precondition(R.accepts(type: "tmo_rope_cage", marker: "Rope"))
        precondition(R.accepts(type: "tmo_rope_seesaw_lever", marker: "Rope02"))
        precondition(R.accepts(type: "tmo_rope_scissors_1", marker: "Rope01"))
        precondition(R.accepts(type: "tmo_rope_crossbow_lever", marker: "Rope"))
        precondition(!R.accepts(type: "tmo_rope_hook", marker: "rope"))
        precondition(!R.accepts(type: "tmo_rope_scissors_2", marker: "Cut01"))
        precondition(!R.accepts(type: "tmo_belt_gear", marker: "Rope"))
        precondition(R.tension(distance: 1, restLength: 1) == 0)
        precondition(R.tension(distance: 0.5, restLength: 1) == 0)
        precondition(abs(R.tension(distance: 1.1, restLength: 1) - 3.5) < 0.00001)
        precondition(R.tension(distance: 4, restLength: 1) == 25)
        precondition(R.tension(distance: .nan, restLength: 1) == 0)
        precondition(R.tension(distance: 1, restLength: 0) == 0)
        for i in 0..<1000 {
            let input = Float(i - 500) * 0.005
            let next = M.transmittedSignal(sourceSignal: input,
                sourceVALF: 0.125, targetVALF: 0.1)!
            precondition(next.isFinite)
            let old = M.decayedSignal(previous: input,
                observedNativeStep: 0.25)!
            precondition(abs(old) <= abs(input) + 0.00001)
        }
        print("Native mechanical VALF ratios, linked sign, observed stop decay: 1000 cases passed")
    }
}
