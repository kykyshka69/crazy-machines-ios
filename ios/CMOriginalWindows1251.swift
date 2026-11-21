import Foundation

/// Deterministic CP1251 codec for original PC level names and scene text.
/// Foundation's .windowsCP1251 transcoders are unavailable on some Swift
/// runtimes (including Linux CI), so use the explicit Windows code page.
/// Byte 0x98 is undefined in CP1251 and must not silently corrupt a level.
public enum CMOriginalWindows1251 {
    private static let extended: [UInt32] = [
        0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
        0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
        0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0x0000, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
        0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
        0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
        0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
        0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
    ]

    public static func decode(_ data: Data) -> String? {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(data.count)
        for byte in data {
            let value: UInt32
            if byte < 0x80 {
                value = UInt32(byte)
            } else if byte >= 0xC0 {
                value = UInt32(byte) - 0xC0 + 0x0410
            } else {
                value = extended[Int(byte) - 0x80]
            }
            guard value != 0 || byte == 0, let scalar = UnicodeScalar(value) else {
                return nil
            }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    /// Also used by tests to generate faithful named PC records.
    public static func encode(_ text: String) -> Data? {
        var reverse: [UInt32: UInt8] = [:]
        for (index, scalar) in extended.enumerated() where scalar != 0 {
            reverse[scalar] = UInt8(index + 0x80)
        }
        var bytes: [UInt8] = []
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if value < 0x80 {
                bytes.append(UInt8(value))
            } else if (0x0410...0x044F).contains(value) {
                bytes.append(UInt8(value - 0x0410 + 0xC0))
            } else if let byte = reverse[value] {
                bytes.append(byte)
            } else {
                return nil
            }
        }
        return Data(bytes)
    }
}
