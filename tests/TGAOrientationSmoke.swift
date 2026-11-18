import Foundation

// Synthetic 2x2, 24-bit TGA; verifies all four origin conventions.
// Expected output is top-left RGBA order: red, green / blue, yellow.
@main
struct TGAOrientationSmoke {
    static func main() throws {
        let topLeft: [[UInt8]] = [
            [255, 0, 0], [0, 255, 0],
            [0, 0, 255], [255, 255, 0]
        ]
        let expected = topLeft.flatMap { $0 + [255] }
        for topOrigin in [false, true] {
            for rightOrigin in [false, true] {
                var header = [UInt8](repeating: 0, count: 18)
                header[2] = 2
                header[12] = 2
                header[14] = 2
                header[16] = 24
                header[17] = (topOrigin ? 0x20 : 0) | (rightOrigin ? 0x10 : 0)
                var payload: [UInt8] = []
                for storedY in 0..<2 {
                    for storedX in 0..<2 {
                        let x = rightOrigin ? 1 - storedX : storedX
                        let y = topOrigin ? storedY : 1 - storedY
                        let rgb = topLeft[y * 2 + x]
                        payload += [rgb[2], rgb[1], rgb[0]]
                    }
                }
                let decoded = try CMTGATexture(data: Data(header + payload))
                precondition(decoded.width == 2 && decoded.height == 2)
                precondition([UInt8](decoded.rgba) == expected,
                             "Wrong TGA orientation top=\(topOrigin) right=\(rightOrigin)")
            }
        }
        print("TGA orientation: all four origins passed")
    }
}
