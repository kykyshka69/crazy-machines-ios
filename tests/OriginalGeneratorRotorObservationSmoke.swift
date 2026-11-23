import Foundation

@main
struct OriginalGeneratorRotorObservationSmoke {
    static func main() {
        typealias P = CMOriginalGeneratorRotorObservation
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
        print("Original generator rotor source stop: stale low nonzero power cleared")
    }
}
