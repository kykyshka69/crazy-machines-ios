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
        precondition(test(.nan) == nil)
        precondition(test(0.2, direction: .infinity) == nil)
        print("Native blowtorch XY contact: PASS")
    }
}
