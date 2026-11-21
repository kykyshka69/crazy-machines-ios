import Foundation

@main
struct OriginalCMLContainerSmoke {
    private static let key = [UInt8]("930%&g/2ANUBIS=!s?p$".utf8)

    private static func prefixSum(_ source: [UInt8]) -> [UInt8] {
        guard source.count > 1 else { return source }
        var result = source
        for index in 1..<result.count {
            result[index] = result[index] &+ result[index - 1]
        }
        return result
    }

    /// Test-only inverse from independent original Python regression logic.
    private static func encodeFrame(_ payload: Data) -> Data {
        var current = key + [UInt8](payload)
        let control = Array(key.reversed())
        for pair in stride(from: control.count - 2, through: 0, by: -2) {
            let selector = Int(Int8(bitPattern: control[pair]))
            let parameter = Int(control[pair + 1])
            switch selector % 3 {
            case 0: current.reverse()
            case 1:
                for index in current.indices {
                    current[index] = UInt8(truncatingIfNeeded:
                        Int(current[index]) + parameter + current.count + index)
                }
            case 2: current = prefixSum(current)
            default: break
            }
        }
        return Data(prefixSum(current))
    }

    private static func littleEndian(_ value: Int) -> Data {
        precondition(value >= 0 && value <= Int(UInt32.max))
        return Data([UInt8(value & 255), UInt8((value >> 8) & 255),
                     UInt8((value >> 16) & 255), UInt8((value >> 24) & 255)])
    }

    private static func packCodes(_ codes: [Int]) -> Data {
        var result = [UInt8]()
        for index in stride(from: 0, to: codes.count, by: 2) {
            let first = codes[index]
            let second = index + 1 < codes.count ? codes[index + 1] : 0
            result.append(UInt8(first >> 4))
            result.append(UInt8(((first & 15) << 4) | (second >> 8)))
            result.append(UInt8(second & 255))
        }
        return Data(result)
    }

    private static func makeLab(count: Int, badKey: Bool = false) -> Data {
        var header = Data()
        header.append(encodeFrame(littleEndian(count)))
        header.append(encodeFrame(Data(repeating: 0xcd, count: 80)))
        header.append(encodeFrame(littleEndian(0)))
        precondition(header.count == 148)
        header.append(Data(repeating: 0, count: 108))
        if count == 0 { return header }

        let text = "level\r\n{\r\n}\r\n"
        let uncompressed = Array(text.utf8).map(Int.init)
        let packed = packCodes(uncompressed + [4095])
        let payload = littleEndian(packed.count) + packed
        let title = "Сначала наведем порядок"
        var name = title.data(using: .windowsCP1251)!
        name.append(Data(repeating: 0, count: 80 - name.count))
        for _ in 0..<count {
            header.append(encodeFrame(Data([1])))
            header.append(encodeFrame(littleEndian(payload.count)))
            header.append(encodeFrame(name))
            header.append(encodeFrame(payload))
        }
        if badKey { header[256] ^= 0x80 }
        return header
    }

    static func main() throws {
        // Frame decoding preserves bytes and field size across all original
        // field widths (including variable payloads and large frames).
        for size in [0, 1, 4, 80, 1755, 6070] {
            let payload = Data((0..<size).map { UInt8(($0 * 17 + 13) & 255) })
            let frame = encodeFrame(payload)
            let decoded = try CMOriginalCMLContainer.decodeField(
                frame, payloadLength: size)
            precondition(decoded == payload)
        }
        let emptyLab = try CMOriginalCMLContainer.read(makeLab(count: 0))
        precondition(emptyLab.isEmpty)
        let records = try CMOriginalCMLContainer.read(makeLab(count: 2))
        precondition(records.count == 2)
        precondition(records.map(\.index) == [1, 2])
        precondition(records.allSatisfy { $0.flag == 1 })
        precondition(records.map(\.title) == [
            "Сначала наведем порядок", "Сначала наведем порядок"
        ])
        let scene = try records[0].originalSceneText()
        precondition(scene == "level\r\n{\r\n}\r\n")

        do {
            _ = try CMOriginalCMLContainer.read(makeLab(count: 1, badKey: true))
            preconditionFailure("Accepted an altered original CML key")
        } catch CMOriginalCMLContainer.DecodeError.invalidFrame {}
        do {
            var truncated = makeLab(count: 1)
            truncated.removeLast()
            _ = try CMOriginalCMLContainer.read(truncated)
            preconditionFailure("Accepted truncated original CML record")
        } catch CMOriginalCMLContainer.DecodeError.invalidFrame {}
        do {
            _ = try CMOriginalCMLContainer.read(makeLab(count: 1) + Data([0]))
            preconditionFailure("Accepted trailing bytes in original CML")
        } catch CMOriginalCMLContainer.DecodeError.trailingBytes {}
        do {
            _ = try CMOriginalCMLContainer.read(makeLab(count: 103))
            preconditionFailure("Accepted out-of-range original level count")
        } catch CMOriginalCMLContainer.DecodeError.invalidHeader {}
        do {
            _ = try CMOriginalCMLContainer.read(Data(repeating: 0, count: 255))
            preconditionFailure("Accepted incomplete original lab header")
        } catch CMOriginalCMLContainer.DecodeError.invalidHeader {}
        do {
            _ = try CMOriginalCMLContainer.decodeField(encodeFrame(Data([1, 2])),
                                                      payloadLength: 3)
            preconditionFailure("Accepted incorrect original frame field size")
        } catch CMOriginalCMLContainer.DecodeError.invalidFrame {}
        print("Original encrypted CML container and LZW scenes: OK")
    }
}
