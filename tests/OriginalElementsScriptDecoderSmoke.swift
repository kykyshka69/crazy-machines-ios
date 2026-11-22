import Foundation

@main
struct OriginalElementsScriptDecoderSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Pass the user's ORIGINAL encrypted elements.fsc path")
        }
        let encrypted = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        precondition(encrypted.count == 72743)
        let plain = try CMOriginalElementsScriptDecoder.decode(encrypted)
        precondition(plain.count == 72723)
        guard let source = String(data: plain, encoding: .windowsCP1252) else {
            fatalError("Decoded source not CP1252 readable")
        }
        precondition(source.hasPrefix("//#FAKT_SCRIPT#\r\n"))
        for type in ["tmo_bucket", "tmo_ball_tennis", "tmo_magnetic_permanent",
                     "tmo_heat_rocket", "tmo_power_lamp", "tmo_rope_cage"] {
            precondition(source.contains(type), "Missing authentic template \(type)")
        }
        precondition(plain.contains(Data("BITS".utf8)))
        do {
            var damaged = encrypted
            damaged[0] ^= 0xff
            _ = try CMOriginalElementsScriptDecoder.decode(damaged)
            fatalError("Corrupt script unexpectedly accepted")
        } catch CMOriginalElementsScriptDecoder.Error.keyMismatch {
            // Expected
        }
        print("PASS: Original 72,743-byte FSC encrypted script decrypted on native Swift")
        print("PASS: 72,723 decoded authentic template text bytes, no proprietary bytes embedded")
    }
}