import Foundation

@main
struct OriginalGearContactTransferSmoke {
    typealias G = CMOriginalGearContactTransfer

    static func coupling(
        _ first: Float, _ second: Float,
        radiusA: Float = 0.12, radiusB: Float = 0.12,
        kindA: String = "tmo_power_motor_rotor",
        kindB: String = "tmo_belt_gear"
    ) -> G.TorquePair? {
        G.correction(firstKind: kindA, secondKind: kindB,
            firstRadius: radiusA, secondRadius: radiusB,
            firstAngularSpeed: first, secondAngularSpeed: second,
            firstMass: 1, secondMass: 1)
    }

    static func main() {
        precondition(G.accepts("tmo_belt_gear", "tmo_belt_gear"))
        precondition(G.accepts("tmo_power_motor_rotor", "tmo_belt_gear"))
        precondition(G.accepts("tmo_belt_gear", "tmo_belt_conveyer_wheel"))
        precondition(!G.accepts("tmo_power_motor_rotor", "tmo_belt_conveyer_wheel"))
        precondition(!G.accepts("tmo_belt_gear", "tmo_ball_basket"))
        // Stationary pair and already-opposed rolling pair are unforced.
        precondition(coupling(0, 0) == nil)
        precondition(coupling(3, -3) == nil)
        precondition(coupling(3, -1.5, radiusB: 0.24) == nil)
        // A genuinely powered gear applies a nonzero CORRECTIVE torque,
        // reversing the passive gear, with equal-sign reaction torque.
        let right = coupling(3, 0)!
        precondition(right.first < 0 && right.second < 0)
        let left = coupling(-3, 0)!
        precondition(left.first > 0 && left.second > 0)
        let alreadyFast = coupling(3, -5)!
        precondition(alreadyFast.first > 0 && alreadyFast.second > 0)
        // The physically contacted conveyor wheel can be driven by a gear,
        // not merely because it appears somewhere in the CML.
        let conveyor = coupling(3, 0, kindA: "tmo_belt_gear",
                                kindB: "tmo_belt_conveyer_wheel")!
        precondition(conveyor.second < 0)
        precondition(coupling(3, 0, kindB: "tmo_zone") == nil)
        precondition(coupling(3, 0, radiusA: 0) == nil)
        precondition(coupling(3, 0, radiusB: .infinity) == nil)
        precondition(coupling(.nan, 0) == nil)
        precondition(coupling(100, 0) == nil)
        precondition(G.correction(firstKind: "tmo_belt_gear",
            secondKind: "tmo_belt_gear", firstRadius: .nan,
            secondRadius: 0.12, firstAngularSpeed: 2,
            secondAngularSpeed: 0, firstMass: 1,
            secondMass: 1) == nil)
        for i in 0..<1000 {
            let a = Float(i % 80 - 40) / 3
            let b = Float(i % 63 - 31) / 4
            if let torque = coupling(a, b) {
                precondition(torque.first.isFinite && torque.second.isFinite)
                precondition(abs(torque.first) <= 1.921)
                precondition(abs(torque.second) <= 1.921)
                precondition((torque.first > 0) == (torque.second > 0))
            }
        }
        print("Original UCM gear contact: counterrotation, motor/gear/conveyor and 1000 bounded cases OK")
    }
}
