import Foundation

@main
struct OriginalGeneratorRotorObservationSmoke {
    static func main() {
        typealias P = CMOriginalGeneratorRotorObservation
        // The live electrical path needs precise per-frame observations,
        // including observed zero, and must distinguish unavailable data.
        precondition(P.frameReport(previous: nil, measured: 0) == 0)
        precondition(P.frameReport(previous: 0, measured: 0) == nil)
        precondition(P.frameReport(previous: 10, measured: Float(10).nextDown) == Float(10).nextDown)
        precondition(P.frameReport(previous: 10, measured: 10) == nil)
        precondition(P.frameReport(previous: 0, measured: 0.02) == 0.02)
        precondition(P.frameReport(previous: 0.02, measured: 0) == 0)
        precondition(P.frameReport(previous: 0, measured: nil)?.isNaN == true)
        precondition(P.frameReport(previous: nil, measured: .infinity)?.isNaN == true)
        precondition(P.frameReport(previous: .nan, measured: nil) == nil)
        precondition(P.frameReport(previous: .nan, measured: 0) == 0)
        precondition(P.frameReport(previous: .nan, measured: -2) == -2)
        precondition(P.frameReport(previous: 0.02, measured: 0.009) == 0)
        precondition(P.report(previous: nil, measured: 0) == nil)
        precondition(P.report(previous: nil, measured: 0.009) == nil)
        precondition(P.report(previous: nil, measured: -2) == -2)
        precondition(P.report(previous: -2, measured: -2.01) == nil)
        precondition(P.report(previous: -2, measured: 0) == 0)
        precondition(P.report(previous: 0.03, measured: 0) == 0)
        precondition(P.report(previous: 0.03, measured: 0.009) == 0)
        precondition(P.report(previous: 0, measured: 0) == nil)
        // Very slow but real rotor movement must START electrical output.
        // Numeric poll debounce cannot silently switch off a generator.
        precondition(P.report(previous: 0, measured: 0.02) == 0.02)
        precondition(P.report(previous: 0, measured: -0.02) == -0.02)
        // Signed rotor reversal changes the downstream motor command.
        precondition(P.report(previous: 0.03, measured: -0.02) == -0.02)
        precondition(P.report(previous: -0.03, measured: 0.02) == 0.02)
        precondition(P.report(previous: 0, measured: 0.1) == 0.1)
        precondition(P.report(previous: .nan, measured: 0.1) == nil)
        precondition(P.report(previous: nil, measured: .infinity) == nil)
        precondition(P.sourceUnavailable(previous: nil) == nil)
        precondition(P.sourceUnavailable(previous: 0) == nil)
        precondition(P.sourceUnavailable(previous: 0.02) == 0)
        precondition(P.sourceUnavailable(previous: -2) == 0)
        precondition(P.sourceUnavailable(previous: .nan) == 0)
        // All recovered strict electrical goal thresholds must survive
        // the SceneKit reporting debounce, in both directions and signs.
        for cutoff: Float in [0.5, 1, 3] {
            let above = cutoff.nextUp
            precondition(P.report(previous: cutoff, measured: above) == above)
            precondition(P.report(previous: above, measured: cutoff) == cutoff)
            precondition(P.report(previous: -cutoff, measured: -above) == -above)
            precondition(P.report(previous: -above, measured: -cutoff) == -cutoff)
        }
        var previous: Float? = nil
        for measured: Float in [2, 1, 0.5, 0.1, 0.04, 0.02, 0.007, 0] {
            if let result = P.report(previous: previous, measured: measured) {
                previous = result
            }
        }
        precondition(previous == 0)
        // A real rotor going missing after starting must emit an exact
        // stop once; subsequent missing polls must remain silent.
        var lost: Float? = P.report(previous: nil, measured: 2)
        precondition(lost == 2)
        lost = P.sourceUnavailable(previous: lost)
        precondition(lost == 0)
        precondition(P.sourceUnavailable(previous: lost) == nil)
        // Exercise the same projected observation now shared by all
        // SceneKit planar mechanisms; off-plane spin cannot create power
        // or satisfy the windmill GOAL. Real signed planar spin is kept.
        for axis in [SIMD3<Float>(1,0,0), .init(0,1,0), .init(-2,3,0)] {
            for magnitude: Float in [-80,-10,-1,0,1,10,80] {
                let speed = CMOriginalDriveBelt.planarAngularSpeed(axis:axis,magnitude:magnitude)!
                precondition(speed == 0)
                precondition(!CMOriginalWindowsWindmill.triggersGoal(nativeWingsSignal:speed))
                precondition(P.report(previous:1,measured:speed) == 0)
                precondition(P.report(previous:nil,measured:speed) == nil)
            }
        }
        for sign: Float in [-1,1] {
            for scale: Float in [0.1,1,2,100] {
                for magnitude: Float in [0,0.01,0.1,0.3,0.301,0.5,1,3,80] {
                    let speed = CMOriginalDriveBelt.planarAngularSpeed(
                        axis:.init(0,0,sign*scale),magnitude:magnitude)!
                    precondition(speed == sign*magnitude)
                    precondition(CMOriginalWindowsWindmill.triggersGoal(
                        nativeWingsSignal:speed) == (magnitude > 0.3))
                }
            }
        }
        precondition(CMOriginalDriveBelt.planarAngularSpeed(axis:.init(.nan,0,1),magnitude:1) == nil)
        precondition(P.sourceUnavailable(previous:2) == 0)
        print("Original generator rotor source stop: stale low nonzero power cleared")
    }
}
