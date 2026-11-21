import Foundation

/// The fixed-width 12-bit LZW stream recovered from the original Windows
/// Crazy Machines level payloads. This is a byte decoder, not a level parser.
/// It does not interpret object positions, rules or electrical connections.
public enum CMOriginalLZW12 {
    public enum DecodeError: Error, Equatable {
        case invalidCode(Int)
        case missingEndMarker
        case outputTooLarge
        case invalidLevelSection
    }

    /// Original record payload: UInt32 LE byte length of the compressed
    /// scene graph followed by its LZW section. Other original record data
    /// may follow the declared section and is intentionally left untouched.
    /// Returns the raw CP1251 scene bytes for a future structured parser.
    public static func decodeLevelSection(_ payload: Data,
                                          maximumOutputBytes: Int = 8_000_000) throws -> Data {
        guard payload.count >= 4, payload.count <= 8_000_000 else {
            throw DecodeError.invalidLevelSection
        }
        let header = [UInt8](payload.prefix(4))
        let length = Int(header[0]) | (Int(header[1]) << 8)
                   | (Int(header[2]) << 16) | (Int(header[3]) << 24)
        guard length > 0, length <= payload.count - 4 else {
            throw DecodeError.invalidLevelSection
        }
        var scene = try decompress(payload.subdata(in: 4..<(4 + length)),
                                   maximumOutputBytes: maximumOutputBytes)
        while scene.last == 0 { scene.removeLast() }
        guard scene.starts(with: Data("level\r\n{".utf8)) else {
            throw DecodeError.invalidLevelSection
        }
        return scene
    }

    /// Expand the 12-bit big-endian code stream used in the PC level section.
    /// Code 4095 terminates the stream. The last incomplete three-byte group
    /// is zero-padded, matching the recovered Windows stream representation.
    /// No proprietary original level bytes are embedded in the decoder.
    public static func decompress(_ encoded: Data,
                                  maximumOutputBytes: Int = 8_000_000) throws -> Data {
        guard maximumOutputBytes >= 0, encoded.count <= 8_000_000 else {
            throw DecodeError.outputTooLarge
        }
        let bytes = [UInt8](encoded)
        var dictionary: [[UInt8]] = (0..<256).map { [UInt8($0)] }
        var previous: [UInt8] = []
        var output: [UInt8] = []
        output.reserveCapacity(min(maximumOutputBytes, 64 * 1024))

        func consume(_ code: Int) throws -> Bool {
            if code == 4095 { return true }
            let entry: [UInt8]
            if code < dictionary.count {
                entry = dictionary[code]
            } else if code == dictionary.count && !previous.isEmpty {
                // The one valid not-yet-defined code: KwKwK.
                entry = previous + [previous[0]]
            } else {
                throw DecodeError.invalidCode(code)
            }
            guard entry.count <= maximumOutputBytes - output.count else {
                throw DecodeError.outputTooLarge
            }
            output.append(contentsOf: entry)
            if !previous.isEmpty && dictionary.count < 4095 {
                dictionary.append(previous + [entry[0]])
            }
            previous = entry
            return false
        }

        for offset in stride(from: 0, to: bytes.count, by: 3) {
            let a = Int(bytes[offset])
            let b = offset + 1 < bytes.count ? Int(bytes[offset + 1]) : 0
            let c = offset + 2 < bytes.count ? Int(bytes[offset + 2]) : 0
            if try consume((a << 4) | (b >> 4)) { return Data(output) }
            if try consume(((b & 0x0f) << 8) | c) { return Data(output) }
        }
        throw DecodeError.missingEndMarker
    }
}
