import Foundation

@main
struct OriginalRocketForceDeliverySmoke {
    static func main() {
        typealias B = CMOriginalRocketForceDelivery
        typealias V = CMOriginalWindowsRocketForce.Vector3
        func observation(parent: String = "rocket-0", child: String = "rocket-part-0",
                         sequence: UInt64 = 1,
                         state: Float = 2, active: Bool = true,
                         vector: V? = .init(2, -4, 700),
                         scalar: Float? = 0.5,
                         center: V? = .init(1, 3, -2)) -> B.Observation {
            .init(nativeSampleSequence: sequence,
                  rocketParentID: parent, rocketChildID: child,
                  nativeParentState: state,
                  actualOriginalEngineActivated: active,
                  nativeDirectionVector: vector,
                  nativeChildFCScalar: scalar,
                  observedNativeBodyCenter: center)
        }
        func force(_ input: B.Observation,
                   parent: String = "rocket-0",
                   child: String = "rocket-part-0",
                   parentType: String = "tmo_heat_rocket",
                   childType: String = "tmo_heat_rocket_rocket",
                   dynamic: Bool = true) -> CMOriginalWindowsRocketForce.Sample? {
            B.force(observed: input,
                    realParentID: parent, realChildID: child,
                    actualParentType: parentType, actualChildType: childType,
                    childPhysicsIsDynamic: dynamic)
        }
        precondition(force(observation())?.force == .init(1, -2, 0))
        precondition(B.fresh(observation(sequence: 1), afterLastApplied: nil))
        precondition(B.fresh(observation(sequence: 2), afterLastApplied: 1))
        precondition(!B.fresh(observation(sequence: 1), afterLastApplied: 1))
        precondition(!B.fresh(observation(sequence: 1), afterLastApplied: 2))
        precondition(!B.fresh(observation(sequence: 0), afterLastApplied: nil))
        precondition(force(observation(sequence: 0)) == nil)
        precondition(force(observation())?.bodyCenter == .init(1, 3, -2))
        precondition(force(observation(), dynamic: false) == nil)
        precondition(force(observation(), parentType: "tmo_candle") == nil)
        precondition(force(observation(), childType: "tmo_windmill_wings") == nil)
        precondition(force(observation(), parent: "another") == nil)
        precondition(force(observation(), child: "another") == nil)
        precondition(force(observation(parent: "another")) == nil)
        precondition(force(observation(child: "another")) == nil)
        precondition(force(observation(state: 1)) == nil)
        precondition(force(observation(state: 3)) == nil)
        precondition(force(observation(active: false)) == nil)
        precondition(force(observation(vector: nil)) == nil)
        precondition(force(observation(scalar: nil)) == nil)
        precondition(force(observation(center: nil)) == nil)
        precondition(force(observation(scalar: .nan)) == nil)
        precondition(force(observation(scalar: .infinity)) == nil)
        precondition(force(observation(vector: .init(.infinity, 0))) == nil)
        precondition(force(observation(center: .init(0, .nan))) == nil)
        precondition(force(observation(parent: "")) == nil)
        precondition(force(observation(child: "")) == nil)
        print("Original rocket Engine: exact child, genuine active state, continuous center-force gated")
    }
}
