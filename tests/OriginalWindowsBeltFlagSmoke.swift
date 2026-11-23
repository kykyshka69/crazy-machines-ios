import Foundation

@main
struct OriginalWindowsBeltFlagSmoke {
    static func main() {
        typealias F = CMOriginalWindowsBeltFlag
        func goal(_ indicator: Float, _ state: Float, _ travel: Float) -> Bool {
            F.triggersGoal(.init(telescopeIndicator: indicator,
                                 flagState: state, accumulatedTravel: travel))
        }
        let mark = F.nativeTelescopeMarker
        precondition(mark.bitPattern == 0x3ec28f5c)
        precondition(!goal(mark, 0, 1.999))
        precondition(goal(mark, 0, 2))
        precondition(goal(mark, 0, -2))
        precondition(!goal(mark, 1, 10))
        precondition(!goal(mark, 0, 0))
        precondition(goal(0, 0, 1.999))
        precondition(!goal(0, 0, 2))
        precondition(!goal(0, 0, -2.001))
        precondition(!goal(0, 1, 0))
        precondition(!goal(.nan, 0, 1))
        precondition(!goal(0, 0, .infinity))
        precondition(!goal(0, .nan, 1))
        print("Original Win32 belt-flag native GOAL branches (strict bounds): OK")
    }
}
