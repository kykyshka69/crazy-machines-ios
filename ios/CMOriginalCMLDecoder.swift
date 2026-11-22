import Foundation

/// Decode the original Windows CML field framing, LZW level stream and
/// original scene tree natively on iOS. This recovers objects, NOT game rules.
/// Never bundles the original game's proprietary level bytes.
enum CMOriginalCMLDecoder {
    enum DecodeError: Error, Equatable {
        case invalidLaboratory, invalidFrame, unsupportedRecordCount
        case truncated, invalidRecord, invalidLevelStream, invalidScene
        case outputLimit
    }

    private static let key = Array("930%&g/2ANUBIS=!s?p$".utf8)
    private static let maxSceneBytes = 8_000_000

    struct Record {
        let index: Int
        let title: String
        let sceneBytes: [UInt8]
    }

    static func decode(_ data: Data) throws -> [CMOriginalSceneDocument] {
        try readRecords(data).map { record in
            let root = try parseScene(record.sceneBytes)
            let hash = CMOriginalSHA256.digest(record.sceneBytes)
                .map { String(format: "%02x", $0) }.joined()
            let doc = CMOriginalSceneDocument(
                schema: "crazy-machines-original-scene-v1",
                index: record.index, title: record.title,
                sceneSHA256: hash, root: root
            )
            // Apply precisely the same validation as imported scene JSON.
            return try CMOriginalSceneDocument.read(JSONEncoder().encode(doc))
        }
    }

    static func readRecords(_ data: Data) throws -> [Record] {
        guard data.count >= 256 && data.count <= 64 * 1024 * 1024 else {
            throw DecodeError.invalidLaboratory
        }
        let bytes = Array(data)
        let first = try decodeFrame(Array(bytes[0..<24]), size: 4)
        let count = Int(le32(first, at: 0))
        guard (0...102).contains(count) else { throw DecodeError.unsupportedRecordCount }
        // First three header fields are individually framed at offsets
        // 0, 24, 124. The original Windows record reader begins at 256.
        var offset = 256
        func field(_ size: Int) throws -> [UInt8] {
            guard size >= 0, size <= bytes.count - offset - key.count else {
                throw DecodeError.truncated
            }
            let end = offset + size + key.count
            let result = try decodeFrame(Array(bytes[offset..<end]), size: size)
            offset = end
            return result
        }
        var result: [Record] = []
        result.reserveCapacity(count)
        for index in 1...max(count, 1) {
            if count == 0 { break }
            _ = try field(1) // Preserved original flag, semantics unknown.
            let length = Int(le32(try field(4), at: 0))
            guard length >= 4 && length <= maxSceneBytes else {
                throw DecodeError.invalidRecord
            }
            let rawTitle = try field(80)
            let title = try decodeWindows1251(Array(rawTitle.prefix(while: { $0 != 0 })))
            guard !title.isEmpty && title.count <= 160 else {
                throw DecodeError.invalidRecord
            }
            let payload = try field(length)
            result.append(Record(index: index, title: title,
                                 sceneBytes: try decompressScene(payload)))
        }
        guard offset == bytes.count else { throw DecodeError.invalidLaboratory }
        return result
    }

    private static func le32(_ bytes: [UInt8], at o: Int) -> UInt32 {
        UInt32(bytes[o]) | (UInt32(bytes[o+1]) << 8) |
        (UInt32(bytes[o+2]) << 16) | (UInt32(bytes[o+3]) << 24)
    }

    static func decodeFrame(_ raw: [UInt8], size: Int) throws -> [UInt8] {
        guard size >= 0 && size <= maxSceneBytes && raw.count == size + key.count else {
            throw DecodeError.invalidFrame
        }
        var working = raw
        if raw.count > 1 {
            for i in 1..<raw.count { working[i] = raw[i] &- raw[i-1] }
        }
        // Disassembled Windows 0x47E610 read mode, signed selector modulo 3.
        let control = Array(key.reversed())
        for i in stride(from: 0, to: control.count, by: 2) {
            let remainder = Int(Int8(bitPattern: control[i])) % 3
            let parameter = control[i+1]
            switch remainder {
            case 0: working.reverse()
            case 1:
                let length = working.count
                for j in working.indices {
                    working[j] = working[j] &- parameter &- UInt8(truncatingIfNeeded: length+j)
                }
            case 2:
                if working.count > 1 {
                    let original = working
                    for j in 1..<original.count {
                        working[j] = original[j] &- original[j-1]
                    }
                }
            default: break // Windows negative -1/-2 are no-ops.
            }
        }
        guard Array(working.prefix(key.count)) == key else {
            throw DecodeError.invalidFrame
        }
        return Array(working.dropFirst(key.count))
    }

    static func decompressScene(_ payload: [UInt8]) throws -> [UInt8] {
        guard payload.count >= 4 else { throw DecodeError.invalidLevelStream }
        let length = Int(le32(payload, at: 0))
        guard length > 0 && length <= payload.count-4 else {
            throw DecodeError.invalidLevelStream
        }
        let result = try decompress12Bit(Array(payload[4..<(4+length)]))
        var end = result.count
        while end > 0 && result[end-1] == 0 { end -= 1 }
        let scene = Array(result[..<end])
        guard scene.starts(with: Array("level\r\n{".utf8)) else {
            throw DecodeError.invalidLevelStream
        }
        return scene
    }

    static func decompress12Bit(_ bytes: [UInt8]) throws -> [UInt8] {
        var dict: [[UInt8]?] = Array(repeating: nil, count: 4095)
        for i in 0..<256 { dict[i] = [UInt8(i)] }
        var nextCode = 256
        var previous: [UInt8] = []
        var output: [UInt8] = []
        var ended = false
        // Big-endian 12-bit codes; final partial triplet is zero padded.
        let padded = ((bytes.count+2)/3)*3
        for offset in stride(from: 0, to: padded, by: 3) {
            let a = offset < bytes.count ? bytes[offset] : 0
            let b = offset+1 < bytes.count ? bytes[offset+1] : 0
            let c = offset+2 < bytes.count ? bytes[offset+2] : 0
            let codes = [(Int(a)<<4) | (Int(b)>>4), ((Int(b)&15)<<8) | Int(c)]
            for code in codes {
                if ended { break }
                if code == 4095 { ended = true; break }
                let entry: [UInt8]
                if code < dict.count, let known = dict[code] {
                    entry = known
                } else if code == nextCode && !previous.isEmpty {
                    entry = previous + [previous[0]]
                } else {
                    throw DecodeError.invalidLevelStream
                }
                guard entry.count <= maxSceneBytes - output.count else {
                    throw DecodeError.outputLimit
                }
                output.append(contentsOf: entry)
                if !previous.isEmpty && nextCode < 4095 {
                    dict[nextCode] = previous + [entry[0]]
                    nextCode += 1
                }
                previous = entry
            }
            if ended { break }
        }
        guard ended else { throw DecodeError.invalidLevelStream }
        return output
    }

    // Complete Windows-1251 mapping, not lossy UTF-8 decoding.
    private static let cp1251High: [UInt32] = [
        0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
        0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
        0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
        0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
        0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
        0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
        0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
        0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416, 0x0417,
        0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, 0x041F,
        0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, 0x0427,
        0x0428, 0x0429, 0x042A, 0x042B, 0x042C, 0x042D, 0x042E, 0x042F,
        0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437,
        0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F,
        0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447,
        0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F
    ]

    static func decodeWindows1251(_ bytes: [UInt8]) throws -> String {
        var scalars = String.UnicodeScalarView()
        for byte in bytes {
            let value: UInt32 = byte < 128 ? UInt32(byte) : cp1251High[Int(byte)-128]
            guard value != 0xFFFD, let scalar = UnicodeScalar(value) else {
                throw DecodeError.invalidScene
            }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    private struct RawNode {
        let name: String
        var fields: [String] = []
        var children: [Int] = []
    }

    private static func parseVector(_ raw: String?) throws -> [Double]? {
        guard let raw else { return nil }
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw DecodeError.invalidScene }
        return try parts.map {
            let text = $0.trimmingCharacters(in: .whitespaces)
            guard let value = Double(text), value.isFinite,
                  abs(value) <= Double(Float.greatestFiniteMagnitude) else {
                throw DecodeError.invalidScene
            }
            return value
        }
    }

    static func parseScene(_ scene: [UInt8]) throws -> CMOriginalSceneDocument.Node {
        guard scene.count <= maxSceneBytes else { throw DecodeError.outputLimit }
        let text = try decodeWindows1251(scene)
        var nodes: [RawNode] = []
        var stack: [Int] = []
        var rootIndex: Int?
        var pending: String?
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line == "{" {
                guard let name = pending, !name.isEmpty, nodes.count < 20_000,
                      stack.count < 64 else { throw DecodeError.invalidScene }
                let id = nodes.count
                nodes.append(RawNode(name: name))
                if let parent = stack.last {
                    nodes[parent].children.append(id)
                } else if rootIndex == nil {
                    rootIndex = id
                } else { throw DecodeError.invalidScene }
                stack.append(id)
                pending = nil
            } else if line == "}" {
                if let value = pending {
                    guard let parent = stack.last else { throw DecodeError.invalidScene }
                    nodes[parent].fields.append(value)
                    pending = nil
                }
                guard !stack.isEmpty else { throw DecodeError.invalidScene }
                stack.removeLast()
            } else {
                if let value = pending {
                    guard let parent = stack.last else { throw DecodeError.invalidScene }
                    nodes[parent].fields.append(value)
                }
                pending = line
            }
        }
        if let value = pending {
            guard let parent = stack.last else { throw DecodeError.invalidScene }
            nodes[parent].fields.append(value)
        }
        guard stack.isEmpty, let rootIndex, nodes[rootIndex].name == "level" else {
            throw DecodeError.invalidScene
        }
        func ownModels(_ id: Int) -> [String] {
            var result: [String] = []
            var pending = [id]
            while let current = pending.popLast() {
                if current != id && nodes[current].name.hasPrefix("3DO ") {
                    result.append(String(nodes[current].name.dropFirst(4)))
                }
                for child in nodes[current].children.reversed()
                    where !nodes[child].name.hasPrefix("tmo_") {
                    pending.append(child)
                }
            }
            return result
        }
        func build(_ id: Int) throws -> CMOriginalSceneDocument.Node {
            let raw = nodes[id]
            func first(_ keyword: String) -> String? {
                for value in raw.fields {
                    if value == keyword { return "" }
                    if value.hasPrefix(keyword + " ") {
                        return String(value.dropFirst(keyword.count + 1))
                    }
                }
                return nil
            }
            return try CMOriginalSceneDocument.Node(
                name: raw.name, fields: raw.fields,
                children: raw.children.map { try build($0) },
                position: try parseVector(first("POS")),
                positionRelative: try parseVector(first("POSREL")),
                rotationRaw: first("ROT"),
                rotationRelativeRaw: first("ROTREL"),
                models: raw.name.hasPrefix("tmo_") ? ownModels(id) : nil,
                goalRaw: raw.name.hasPrefix("tmo_") ? first("GOAL") : nil
            )
        }
        return try build(rootIndex)
    }
}
