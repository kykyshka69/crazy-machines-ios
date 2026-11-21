import Foundation

/// The framed Professor Laboratory CML container recovered from the original
/// Windows reader. Decode only user-supplied game files; no levels are bundled.
/// Names and scene text use the original Windows-1251 encoding.
public enum CMOriginalCMLContainer {
    public enum DecodeError: Error, Equatable {
        case invalidHeader
        case invalidFrame
        case invalidRecord
        case trailingBytes
        case invalidText
    }

    public struct Record {
        public let index: Int
        public let flag: UInt8
        public let title: String
        public let payload: Data

        /// The outer record is decoded before the original 12-bit LZW section.
        /// This does not infer puzzle objects, physics, or completion logic.
        public func originalSceneText() throws -> String {
            let source = try CMOriginalLZW12.decodeLevelSection(payload)
            guard let text = String(data: source, encoding: .windowsCP1251),
                  text.hasPrefix("level\r\n{") else {
                throw DecodeError.invalidText
            }
            return text
        }
    }

    private static let key = [UInt8]("930%&g/2ANUBIS=!s?p$".utf8)
    private static let headerBytes = 256
    private static let maximumFileBytes = 32 * 1024 * 1024
    private static let maximumRecordBytes = 8_000_000

    /// Apply the inverse adjacent-byte transform (first difference).
    private static func adjacentDifference(_ bytes: [UInt8]) -> [UInt8] {
        guard bytes.count > 1 else { return bytes }
        var result = bytes
        for index in 1..<bytes.count {
            result[index] = bytes[index] &- bytes[index - 1]
        }
        return result
    }

    /// Inverse of the field framing applied by the original x86 CML reader.
    /// Each field must start with the 20-byte key after decoding.
    public static func decodeField(_ frame: Data, payloadLength: Int) throws -> Data {
        guard payloadLength >= 0, payloadLength <= maximumRecordBytes,
              frame.count == payloadLength + key.count else {
            throw DecodeError.invalidFrame
        }
        var result = adjacentDifference([UInt8](frame))
        let control = Array(key.reversed())
        for pair in stride(from: 0, to: control.count, by: 2) {
            let signedSelector = Int(Int8(bitPattern: control[pair]))
            let parameter = Int(control[pair + 1])
            switch signedSelector % 3 {
            case 0:
                result.reverse()
            case 1:
                // Reverse the Windows encoder's position-dependent addition.
                for index in result.indices {
                    result[index] = UInt8(truncatingIfNeeded:
                        Int(result[index]) - parameter - result.count - index)
                }
            case 2:
                result = adjacentDifference(result)
            default:
                // Negative x86 remainders -1 and -2 intentionally do nothing.
                break
            }
        }
        guard result.starts(with: key) else { throw DecodeError.invalidFrame }
        return Data(result.dropFirst(key.count))
    }

    public static func read(_ data: Data) throws -> [Record] {
        guard data.count >= headerBytes, data.count <= maximumFileBytes else {
            throw DecodeError.invalidHeader
        }
        let bytes = [UInt8](data)
        var offset = 0

        func takeField(_ length: Int) throws -> Data {
            guard length >= 0, length <= maximumRecordBytes,
                  offset <= bytes.count,
                  length + key.count <= bytes.count - offset else {
                throw DecodeError.invalidFrame
            }
            let end = offset + length + key.count
            let frame = Data(bytes[offset..<end])
            let decoded = try decodeField(frame, payloadLength: length)
            offset = end
            return decoded
        }
        func littleEndian32(_ data: Data) -> Int {
            let bytes = [UInt8](data)
            return Int(bytes[0]) | (Int(bytes[1]) << 8)
                 | (Int(bytes[2]) << 16) | (Int(bytes[3]) << 24)
        }

        // The original laboratory has three verified header frames of
        // 4, 80 and 4 bytes. The rest of its 256-byte prologue is retained
        // but not given undocumented semantics.
        let count = littleEndian32(try takeField(4))
        _ = try takeField(80)
        _ = try takeField(4)
        guard offset == 148, count >= 0, count <= 102 else {
            throw DecodeError.invalidHeader
        }
        offset = headerBytes
        var records: [Record] = []
        records.reserveCapacity(count)
        for index in 0..<count {
            let flag = try takeField(1).first!
            let length = littleEndian32(try takeField(4))
            guard length > 0, length <= maximumRecordBytes else {
                throw DecodeError.invalidRecord
            }
            let rawName = try takeField(80)
            let nameBytes = Data(rawName.prefix(while: { $0 != 0 }))
            guard let title = String(data: nameBytes, encoding: .windowsCP1251),
                  !title.isEmpty, title.count <= 160 else {
                throw DecodeError.invalidText
            }
            let payload = try takeField(length)
            records.append(Record(index: index + 1, flag: flag, title: title,
                                  payload: payload))
        }
        guard offset == bytes.count else { throw DecodeError.trailingBytes }
        return records
    }
}
