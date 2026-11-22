import Foundation

@main
struct OriginalVSCDecoderSmoke {
    static let key = CMOriginalVSCDecoder.key

    // Invert the verified Win32 read pipeline to make a copyright-free
    // encrypted VSC fixture. This is NOT a known original script.
    private static func encode(_ text: String) -> Data {
        var bytes = key + Array(text.utf8)
        let pairs = Array(key.reversed())
        for index in stride(from: pairs.count - 2, through: 0, by: -2) {
            let selector = Int(Int8(bitPattern: pairs[index]))
            let parameter = Int(pairs[index + 1])
            let rem = selector - (selector / 3) * 3
            switch rem {
            case 0: bytes.reverse()
            case 1:
                let count = bytes.count
                for i in bytes.indices {
                    bytes[i] = UInt8(truncatingIfNeeded:
                        Int(bytes[i]) + parameter + count + i)
                }
            case 2:
                for i in 1..<bytes.count { bytes[i] = bytes[i] &+ bytes[i-1] }
            default: break
            }
        }
        for i in 1..<bytes.count { bytes[i] = bytes[i] &+ bytes[i-1] }
        return Data(bytes)
    }

    static func main() throws {
        let original = "# FAKT Software Value Script\r\n\r\n[Config]\r\nShadows = 1.000000\r\nMusic = 0.000000\r\n\r\n[DIALOG]\r\nName = \"task_done\"\r\n[BUTTON_CONTINUE]\r\nName = \"Continue\"\r\nID = 1\r\n[DIALOG]\r\nName = \"Again\"\r\n"
        let encoded = encode(original)
        let decoded = try CMOriginalVSCDecoder.decode(encoded)
        precondition(decoded == Data(original.utf8))
        let script = try CMOriginalVSCDecoder.read(encoded)
        precondition(script.sections.count == 4)
        precondition(script.allSections(named: "dialog").count == 2)
        precondition(script.section(named: "config")?.value(for: "shadows") == "1.000000")
        precondition(script.section(named: "BUTTON_CONTINUE")?.value(for: "ID") == "1")
        precondition(script.section(named: "BUTTON_CONTINUE")?.value(for: "Name") == "Continue")
        // Original Windows byte transform is NOT an authenticated cipher:
        // some single-byte changes can preserve the key prefix. Do not
        // claim integrity beyond its actual key/header checks.
        do {
            _ = try CMOriginalVSCDecoder.decode(Data(repeating: 0, count: 128))
            preconditionFailure("Wrong-key VSC bytes were accepted")
        } catch CMOriginalVSCDecoder.DecodeError.invalidKey { }
        do {
            _ = try CMOriginalVSCDecoder.parse("[DIALOG]\nID=4")
            preconditionFailure("No FAKT header was accepted")
        } catch CMOriginalVSCDecoder.DecodeError.invalidHeader { }
        do {
            _ = try CMOriginalVSCDecoder.parse("# FAKT Software Value Script\nID=2\n[DIALOG]")
            preconditionFailure("Orphaned key-value entry was accepted")
        } catch CMOriginalVSCDecoder.DecodeError.invalidFormat { }
        print("Windows VSC key + CP1251/FAKT section parser: portable smoke passed")
    }
}