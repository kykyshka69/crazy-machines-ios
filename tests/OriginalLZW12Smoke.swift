import Foundation

@main
struct OriginalLZW12Smoke {
    static func codes(_ values: [Int]) -> Data {
        precondition(values.allSatisfy { 0 <= $0 && $0 <= 4095 })
        var packed = [UInt8]()
        for offset in stride(from: 0, to: values.count, by: 2) {
            let first = values[offset]
            let second = offset + 1 < values.count ? values[offset + 1] : 0
            packed.append(UInt8(first >> 4))
            packed.append(UInt8(((first & 0xf) << 4) | (second >> 8)))
            packed.append(UInt8(second & 0xff))
        }
        return Data(packed)
    }

    static func main() throws {
        let scenePrefix = Array("level\r\n{".utf8).map(Int.init)
        let prefixOutput = try CMOriginalLZW12.decompress(codes(scenePrefix + [4095]))
        precondition(prefixOutput == Data("level\r\n{".utf8))

        // A B AB ABA: the final 258 is the special KwKwK code.
        let repeated = codes([65, 66, 256, 258, 4095])
        let repeatedOutput = try CMOriginalLZW12.decompress(repeated)
        precondition(repeatedOutput == Data("ABABABA".utf8))
        let empty = try CMOriginalLZW12.decompress(codes([4095]))
        precondition(empty == Data())
        // Any data following 4095 is stream padding, not a puzzle object.
        let trailing = try CMOriginalLZW12.decompress(codes([65, 4095, 66, 400]))
        precondition(trailing == Data("A".utf8))

        // A real PC puzzle record starts with its little-endian section
        // length; unrelated record bytes may follow the LZW section.
        let section = codes(scenePrefix + [0, 4095])
        let count = section.count
        let payload = Data([UInt8(count & 255), UInt8((count >> 8) & 255),
                            0, 0]) + section + Data([0x42, 0x43])
        let level = try CMOriginalLZW12.decodeLevelSection(payload)
        precondition(level == Data("level\r\n{".utf8))
        do {
            _ = try CMOriginalLZW12.decodeLevelSection(Data([0, 0, 0, 0]))
            preconditionFailure("Accepted empty original level section")
        } catch CMOriginalLZW12.DecodeError.invalidLevelSection {}
        do {
            _ = try CMOriginalLZW12.decodeLevelSection(Data([255, 255, 0, 0, 65]))
            preconditionFailure("Accepted truncated original level section")
        } catch CMOriginalLZW12.DecodeError.invalidLevelSection {}
        do {
            _ = try CMOriginalLZW12.decodeLevelSection(Data([3, 0, 0, 0]) + codes([65, 4095]))
            preconditionFailure("Accepted non-level compressed content")
        } catch CMOriginalLZW12.DecodeError.invalidLevelSection {}

        do {
            _ = try CMOriginalLZW12.decompress(codes([65, 400, 4095]))
            preconditionFailure("Accepted invalid PC LZW dictionary index")
        } catch CMOriginalLZW12.DecodeError.invalidCode(let code) {
            precondition(code == 400)
        }
        do {
            _ = try CMOriginalLZW12.decompress(codes([65, 66]))
            preconditionFailure("Accepted PC LZW with no terminator")
        } catch CMOriginalLZW12.DecodeError.missingEndMarker {}
        do {
            _ = try CMOriginalLZW12.decompress(repeated, maximumOutputBytes: 6)
            preconditionFailure("Allowed LZW expansion above the output budget")
        } catch CMOriginalLZW12.DecodeError.outputTooLarge {}
        do {
            _ = try CMOriginalLZW12.decompress(repeated, maximumOutputBytes: -1)
            preconditionFailure("Accepted invalid decompression budget")
        } catch CMOriginalLZW12.DecodeError.outputTooLarge {}
        print("Original 12-bit PC LZW decoding: OK")
    }
}
