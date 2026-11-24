import Foundation

@main
struct OriginalWindowsSolarSignalSmoke {
    static func main() {
        let scalar = CMOriginalWindowsSolarSignal.self
        func eq(_ x: Float?, _ y: Float) {
            precondition(x != nil && abs(x! - y) < 0.00001, "\(String(describing: x)) != \(y)")
        }
        // Machine-code constants: emitter power/10, intersection fraction,
        // geometric length * 5, then accumulated fraction capped to 1.
        eq(scalar.rayContribution(emitterPower: 10, interceptedFraction: 0.5,
                                  pathLength: 1), 0.1)
        eq(scalar.rayContribution(emitterPower: 10, interceptedFraction: 1,
                                  pathLength: 2), 0.1)
        eq(scalar.rayContribution(emitterPower: 2.5, interceptedFraction: 1,
                                  pathLength: 1), 0.05)
        eq(scalar.rayContribution(emitterPower: 10, interceptedFraction: 0,
                                  pathLength: 1), 0)
        eq(scalar.collectedPower(rayContributions: []), 0)
        eq(scalar.collectedPower(rayContributions: [0.05, 0.05]), 1)
        eq(scalar.collectedPower(rayContributions: [0.1, 0.1]), 2)
        eq(scalar.collectedPower(rayContributions: [0.5, 0.9, 5]), 10)
        precondition(!scalar.triggersGoal(solarPower: 1))
        precondition(scalar.triggersGoal(solarPower: 1.0001))
        precondition(!scalar.triggersGoal(solarPower: 0))
        precondition(!scalar.triggersGoal(solarPower: .nan))
        precondition(scalar.rayContribution(emitterPower: 10,
                     interceptedFraction: 1, pathLength: 0) == nil)
        precondition(scalar.rayContribution(emitterPower: 10,
                     interceptedFraction: 1.5, pathLength: 1) == nil)
        precondition(scalar.rayContribution(emitterPower: .infinity,
                     interceptedFraction: 1, pathLength: 1) == nil)
        precondition(scalar.rayContribution(emitterPower: -1,
                     interceptedFraction: 1, pathLength: 1) == nil)
        precondition(scalar.collectedPower(rayContributions: [-0.1]) == nil)
        precondition(scalar.collectedPower(rayContributions: [.nan]) == nil)
        typealias O = CMOriginalLiveOptics
        eq(O.lampContribution(power: 10, pathLength: 0.4, unobstructed: true), 0.5)
        eq(O.lampContribution(power: 0, pathLength: 0.4, unobstructed: true), 0)
        eq(O.lampContribution(power: 10, pathLength: 0.4, unobstructed: false), 0)
        precondition(O.lampContribution(power: 10, pathLength: 0, unobstructed: true) == nil)
        let axis = SIMD3<Float>(1, 0, 0)
        let target = SIMD3<Float>(0.4, 0, 0)
        let ray = O.pocketContribution(lit: true, axis: axis,
            displacement: target, unobstructed: true)!
        precondition(ray > 0.5 && ray <= 1)
        eq(O.pocketContribution(lit: false, axis: axis,
            displacement: target, unobstructed: true), 0)
        eq(O.pocketContribution(lit: true, axis: axis,
            displacement: target, unobstructed: false), 0)
        eq(O.pocketContribution(lit: true, axis: axis,
            displacement: -target, unobstructed: true), 0)
        eq(O.pocketContribution(lit: true, axis: -axis,
            displacement: -target, unobstructed: true), ray)
        eq(O.pocketContribution(lit: true, axis: axis,
            displacement: .init(3, 0, 0), unobstructed: true), 0)
        eq(O.pocketContribution(lit: true, axis: axis,
            displacement: .init(0.4, 0.4, 0), unobstructed: true), 0)
        print("Win32 solar ray attenuation / accumulator saturation / GOAL threshold passed")
    }
}