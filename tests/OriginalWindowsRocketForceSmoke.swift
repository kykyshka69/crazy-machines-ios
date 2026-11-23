import Foundation

@main
struct OriginalWindowsRocketForceSmoke {
    static func main() {
        typealias F = CMOriginalWindowsRocketForce
        let direction = F.Vector3(2, -3, 900)
        let center = F.Vector3(1.5, 2.5, -6)
        func sample(_ state: Float = 2, _ engine: Bool = true,
                    _ vector: F.Vector3? = nil, _ scalar: Float? = 0.125,
                    _ at: F.Vector3? = nil,
                    _ type: String = "tmo_heat_rocket") -> F.Sample? {
            F.observedThrust(
                rocketType: type, parentState: state,
                nativeEngineChildActive: engine,
                originalDirectionVector: vector ?? direction,
                observedChildForceScalar: scalar,
                physicsBodyCenter: at ?? center)
        }
        precondition(sample()?.force == F.Vector3(0.25, -0.375, 0))
        precondition(sample()?.bodyCenter == center)
        precondition(sample(1) == nil)
        precondition(sample(3) == nil)
        precondition(sample(2, false) == nil)
        precondition(sample(2, true, nil, nil) == nil)
        precondition(sample(2, true, nil, .nan) == nil)
        precondition(sample(2, true, nil, .infinity) == nil)
        precondition(sample(2, true, F.Vector3(.nan, 1), 1) == nil)
        precondition(sample(2, true, F.Vector3(Float.greatestFiniteMagnitude, 1), 2) == nil)
        precondition(sample(2, true, nil, 1, F.Vector3(0, .infinity)) == nil)
        precondition(sample(2, true, nil, 1, nil, "tmo_heat_dynamite") == nil)
        precondition(sample(2, true, nil, 0)?.force == F.Vector3(0, 0, 0))
        precondition(sample(2, true, nil, -1)?.force == F.Vector3(-2, 3, 0))
        print("Original rocket: native XY force +0xFC at body center; missing telemetry fail-closed")
    }
}
