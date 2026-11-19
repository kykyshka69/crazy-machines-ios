import Foundation

/// Conservative metadata for original proprietary CML laboratory files.
/// Does not claim to decode level records or game mechanics.
public struct CMOriginalCMLProbe {
    public let byteCount: Int
    public let headerHex: String
    public let zeroByteCount: Int
    public let asciiClues: [String]

    public init(data: Data) {
        byteCount = data.count
        headerHex = data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
        zeroByteCount = data.reduce(0) { $0 + ($1 == 0 ? 1 : 0) }
        var clues: [String] = []
        var current: [UInt8] = []
        for byte in data {
            if byte >= 32 && byte <= 126 {
                if current.count < 128 { current.append(byte) }
            } else {
                if current.count >= 5 && clues.count < 24 {
                    clues.append(String(decoding: current, as: UTF8.self))
                }
                current.removeAll(keepingCapacity: true)
            }
        }
        if current.count >= 5 && clues.count < 24 {
            clues.append(String(decoding: current, as: UTF8.self))
        }
        asciiClues = clues
    }
}
