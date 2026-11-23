import Foundation

/// Win32 0x44F9FB–0x44FAA1: belt-flag GOAL is a physical telescope
/// state transition, NOT a goal merely because its separate wheel spins.
/// Inputs must be observed original runtime scalars; SceneKit wheel speed
/// or CML annotations alone cannot substitute for native +0x90/+0x284.
public enum CMOriginalWindowsBeltFlag {
    public static let nativeTelescopeMarker = Float(bitPattern: 0x3EC28F5C)
    public static let nativeTravelCutoff: Float = 2

    public struct ObservedState {
        public let telescopeIndicator: Float // second telescope native +0x90
        public let flagState: Float          // flag element native +0xEC
        public let accumulatedTravel: Float  // signed native local +0x284

        public init(telescopeIndicator: Float, flagState: Float,
                    accumulatedTravel: Float) {
            self.telescopeIndicator = telescopeIndicator
            self.flagState = flagState
            self.accumulatedTravel = accumulatedTravel
        }
    }

    public static func triggersGoal(_ state: ObservedState) -> Bool {
        guard state.telescopeIndicator.isFinite, state.flagState.isFinite,
              state.accumulatedTravel.isFinite,
              state.flagState == 0 else { return false }
        let distance = abs(Double(state.accumulatedTravel))
        if state.telescopeIndicator == nativeTelescopeMarker {
            // 0x44FA3D–0x44FA58: fcomp 2; GOAL iff abs(travel) >= 2.
            return distance >= Double(nativeTravelCutoff)
        }
        // 0x44FA86–0x44FAA1: fcomp 2; GOAL iff abs(travel) < 2.
        return distance < Double(nativeTravelCutoff)
    }
}
