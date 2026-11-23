import Foundation

@main struct OriginalWindowsBlowtorchHeatSmoke {
    static func main() {
        typealias B = CMOriginalWindowsBlowtorchHeat
        func test(_ x: Float, _ y: Float = 0,
                  direction: Float = 1) -> Bool? {
            B.hits(sourceX: 0, sourceY: 0,
                   receiverX: x, receiverY: y,
                   sourceHorizontalDirection: direction)
        }
        precondition(B.halfHeight.bitPattern == 0x3D8F5C29)
        precondition(B.horizontalReach.bitPattern == 0x3ECCCCCD)
        precondition(test(0) == true)
        precondition(test(0.2) == true)
        precondition(test(0.39) == true)
        precondition(test(0.41) == false)
        precondition(test(-0.001) == false)
        precondition(test(0.2, 0.069) == true)
        precondition(test(0.2, 0.071) == false)
        precondition(test(0.2, -0.071) == false)
        precondition(test(-0.2, direction: -1) == true)
        precondition(test(-0.4, direction: -1) == true)
        precondition(test(0, direction: -1) == true)
        precondition(test(0.2, direction: -1) == false)
        precondition(test(-0.2, direction: 0) == true)
        // Original owner's level-074.json + genuine
        // heat_blowtorch_body.ucm / heat_rocket_rocket.ucm Heat matrices:
        // original lit blowtorch/rocket anchors align within native strip.
        // This is real source data, not a fabricated scene screenshot.
        precondition(B.hits(
            sourceX: -1.782162, sourceY: -0.499563,
            receiverX: -1.428228, receiverY: -0.528940,
            sourceHorizontalDirection: 1) == true)
        precondition(test(.nan) == nil)
        precondition(test(0.2, direction: .infinity) == nil)
        print("Native blowtorch XY contact: PASS")
    }
}
