import Foundation

/// Native reader for the *real* Windows FAKT Value Script (.vsc) files.
///
/// x86 verified chain: 0x423437 pushes the literal key at 0x4E97E8,
/// 0x41C755 calls 0x47B400 (set global script key), and 0x47B678 /
/// 0x47B9BB call 0x47E610 to decrypt VSC text. The original key is
/// `tz023416` (eight bytes), different from encrypted elements.fsc.
/// Proprietary .vsc bytes remain in the user's private game installation.
public enum CMOriginalVSCDecoder {
    public enum DecodeError: Error, Equatable {
        case invalidLength, invalidKey, invalidHeader, invalidText, invalidFormat
    }

    public static let key = Array("tz023416".utf8)
    private static let header = "# FAKT Software Value Script"

    public struct Property: Equatable {
        public let name: String
        public let value: String
    }

    public struct Section: Equatable {
        public let name: String
        public let properties: [Property]

        public func value(for key: String) -> String? {
            properties.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value
        }
    }

    public struct Script: Equatable {
        /// Repeated section names occur in genuine gfx/gfx.vsc: preserve order.
        public let sections: [Section]
        public func allSections(named name: String) -> [Section] {
            sections.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        public func section(named name: String) -> Section? {
            allSections(named: name).first
        }
    }

    public static func decode(_ encoded: Data) throws -> Data {
        guard encoded.count >= key.count + header.count,
              encoded.count <= 2_000_000 else { throw DecodeError.invalidLength }
        var bytes = Array(encoded)
        reverseAdjacentDelta(&bytes)
        let control = Array(key.reversed())
        for pair in stride(from: 0, to: control.count, by: 2) {
            let selector = Int(Int8(bitPattern: control[pair]))
            let parameter = Int(control[pair + 1])
            let remainder = selector - (selector / 3) * 3
            switch remainder {
            case 0: bytes.reverse()
            case 1:
                let count = bytes.count
                for index in bytes.indices {
                    bytes[index] = UInt8(truncatingIfNeeded:
                        Int(bytes[index]) - parameter - count - index)
                }
            case 2: reverseAdjacentDelta(&bytes)
            default: break // original signed idiv -1/-2 are no-ops
            }
        }
        guard bytes.prefix(key.count).elementsEqual(key) else {
            throw DecodeError.invalidKey
        }
        let body = Data(bytes.dropFirst(key.count))
        guard body.starts(with: Data(header.utf8)) else {
            throw DecodeError.invalidHeader
        }
        return body
    }

    public static func read(_ data: Data) throws -> Script {
        let decrypted = try decode(data)
        guard let text = CMOriginalWindows1251.decode(decrypted),
              !text.contains("\0") else { throw DecodeError.invalidText }
        return try parse(text)
    }

    /// Parse the real Windows [SECTION] and key=value text without altering
    /// duplicate entries, duplicate sections, or Windows-1251 strings.
    public static func parse(_ text: String) throws -> Script {
        guard text.hasPrefix(header), text.utf8.count <= 2_000_000 else {
            throw DecodeError.invalidHeader
        }
        var sections: [Section] = []
        var activeName: String?
        var properties: [Property] = []
        var lineCount = 0
        func finish() {
            if let activeName { sections.append(Section(name: activeName, properties: properties)) }
        }
        for raw in text.split(whereSeparator: \.isNewline) {
            lineCount += 1
            guard lineCount <= 100_000, raw.count <= 4096 else {
                throw DecodeError.invalidFormat
            }
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") || line.hasPrefix(";") {
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                finish()
                let start = line.index(after: line.startIndex)
                let end = line.index(before: line.endIndex)
                let name = String(line[start..<end]).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, name.count <= 256,
                      sections.count < 1000 else { throw DecodeError.invalidFormat }
                activeName = name
                properties = []
            } else if let equal = line.firstIndex(of: "=") {
                guard activeName != nil else { throw DecodeError.invalidFormat }
                let name = String(line[..<equal]).trimmingCharacters(in: .whitespaces)
                var value = String(line[line.index(after: equal)...])
                    .trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, name.count <= 256,
                      value.count <= 4096,
                      properties.count < 4096 else { throw DecodeError.invalidFormat }
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value.removeFirst()
                    value.removeLast()
                }
                properties.append(Property(name: name, value: value))
            } else {
                throw DecodeError.invalidFormat
            }
        }
        finish()
        guard !sections.isEmpty else { throw DecodeError.invalidFormat }
        return Script(sections: sections)
    }

    private static func reverseAdjacentDelta(_ bytes: inout [UInt8]) {
        guard bytes.count > 1 else { return }
        for index in stride(from: bytes.count - 1, through: 1, by: -1) {
            bytes[index] = bytes[index] &- bytes[index - 1]
        }
    }
}