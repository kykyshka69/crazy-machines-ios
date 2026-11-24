import Foundation

@main
struct OriginalWindowsSwitchContactGateSmoke {
    static func main() {
        let gate = CMOriginalWindowsSwitchContactGate.self
        func allowed(_ x: Float, _ y: Float, _ yes: Bool) {
            let actual = gate.preservesPower(.init(selectedContact: x,
                                                   matingContact: y))
            precondition(actual == yes, "Win32 contact \(x) \(y): \(String(describing: actual))")
            let power = gate.propagatedPower(10, contacts: .init(
                selectedContact: x, matingContact: y))
            precondition(power == (yes ? 10 : 0))
        }
        // Real +/-1 states, unlike the experimental SwiftUI tap bool.
        allowed(1, 1, true)
        allowed(1, -1, false)
        allowed(1, 0, false)
        allowed(-1, -1, true)
        allowed(-1, 1, false)
        allowed(-1, 0, false)
        // The exact assembly skips the zero-write if the selected field
        // itself does not match ±1; don't fabricate other thresholds.
        allowed(0, 1, true)
        allowed(0, -1, true)
        allowed(0.5, -1, true)
        allowed(2, 1, true)
        precondition(gate.preservesPower(.init(selectedContact: .nan,
                                              matingContact: 1)) == nil)
        precondition(gate.preservesPower(.init(selectedContact: 1,
                                              matingContact: .infinity)) == nil)
        precondition(gate.propagatedPower(.infinity,
            contacts: .init(selectedContact: 1, matingContact: 1)) == nil)
        precondition(gate.settledNativeContact(matingContact: -1, motion: -10) == -1)
        precondition(gate.settledNativeContact(matingContact: -2, motion: -10) == -1)
        precondition(gate.settledNativeContact(matingContact: -0.999, motion: -10) == nil)
        precondition(gate.settledNativeContact(matingContact: -1, motion: 0) == nil)
        precondition(gate.settledNativeContact(matingContact: .nan, motion: -10) == nil)
        var impact = CMOriginalSwitchImpactGoal()
        precondition(!impact.observe("s", requestedOn: true, observedClosed: true))
        impact.arm("s", requestedOn: true, previouslyClosed: false)
        precondition(!impact.observe("s", requestedOn: true, observedClosed: false))
        precondition(!impact.observe("other", requestedOn: true, observedClosed: true))
        precondition(impact.observe("s", requestedOn: true, observedClosed: true))
        precondition(!impact.observe("s", requestedOn: true, observedClosed: true))
        impact.arm("s", requestedOn: true, previouslyClosed: false)
        precondition(!impact.observe("s", requestedOn: true, observedClosed: true))
        impact.arm("t", requestedOn: true, previouslyClosed: true)
        precondition(!impact.observe("t", requestedOn: true, observedClosed: true))
        impact.arm("t", requestedOn: true, previouslyClosed: false)
        impact.cancel("t")
        precondition(!impact.observe("t", requestedOn: true, observedClosed: true))
        impact.arm("t", requestedOn: true, previouslyClosed: false)
        precondition(!impact.observe("t", requestedOn: false, observedClosed: true))
        precondition(!impact.observe("t", requestedOn: true, observedClosed: true))
        impact = CMOriginalSwitchImpactGoal()
        impact.arm("s", requestedOn: true, previouslyClosed: false)
        precondition(impact.observe("s", requestedOn: true, observedClosed: true))
        print("Verified Win32 contact pair +0xEC/+0xC8 exact ±1 signal gate")
    }
}