import Foundation

/// Original CrazyMachines.exe 0x4295A0 -> 0x47E610 encrypted-script reader.
/// The Windows loader tests for //#FAKT_SCRIPT# and calls 0x47E610 when
/// the file is encrypted. This implementation takes only the player's
/// original FSC bytes; it does not distribute any proprietary game script.
/// Confirmed against the user's 72,743-byte encrypted elements.fsc.
public enum CMOriginalElementsScriptDecoder {
    public enum Error: Swift.Error {
        case invalidLength
        case invalidControl
        case keyMismatch
        case invalidScriptPrefix
    }

    public static let originalKey = Array("930%&g/2ANUBIS=!s?p$".utf8)

    public static func decode(_ encoded: Data, key: [UInt8] = originalKey) throws -> Data {
        guard encoded.count >= key.count + 17,
              encoded.count <= 2_000_000 else {
            throw Error.invalidLength
        }
        guard !key.isEmpty, key.count <= 256, key.count.isMultiple(of: 2) else {
            throw Error.invalidControl
        }
        var bytes = Array(encoded)
        // Windows 0x47E610 first performs reverse adjacent delta on
        // the entire encrypted frame, then iterates pairs of reversed key.
        reverseAdjacentDelta(&bytes)
        let control = Array(key.reversed())
        for pair in stride(from: 0, to: control.count, by: 2) {
            let selector = Int(Int8(bitPattern: control[pair]))
            let parameter = Int(control[pair + 1])
            // x86 signed idiv by three, truncating toward zero.
            let quotient = selector / 3
            let remainder = selector - quotient * 3
            switch remainder {
            case 0:
                bytes.reverse()
            case 1:
                let length = bytes.count
                for index in bytes.indices {
                    bytes[index] = UInt8(truncatingIfNeeded:
                        Int(bytes[index]) - parameter - length - index)
                }
            case 2:
                reverseAdjacentDelta(&bytes)
            default:
                // Negative x86 idiv remainders are no-ops.
                break
            }
        }
        guard bytes.prefix(key.count).elementsEqual(key) else {
            throw Error.keyMismatch
        }
        let output = Data(bytes.dropFirst(key.count))
        guard output.starts(with: Data("//#FAKT_SCRIPT#".utf8)) else {
            throw Error.invalidScriptPrefix
        }
        return output
    }

    private static func reverseAdjacentDelta(_ bytes: inout [UInt8]) {
        guard bytes.count > 1 else { return }
        // Backwards makes the previous byte remain the ORIGINAL value.
        for index in stride(from: bytes.count - 1, through: 1, by: -1) {
            bytes[index] = bytes[index] &- bytes[index - 1]
        }
    }
}