import Foundation
import CryptoKit

/// Installs a single user-owned local asset pack into the app's private sandbox.
/// The pack is assembled off-device from the user's original Windows installation.
/// No copyrighted game resources are checked into the iOS source repository.
///
/// Binary format: ASCII "CMASSET1", UInt32 LE entry count, then repeated:
/// UInt16 LE UTF-8 basename length, basename, UInt32 LE payload length,
/// 32 SHA-256 bytes, payload. All records are checked before any file is written.
enum CMOriginalAssetPackImporter {
    struct Result {
        let installed: Int
        let existing: Int
        let models: Int
        let textures: Int
        let levels: Int
    }

    enum PackError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            if case .invalid(let detail) = self { return detail }
            return "Invalid Crazy Machines pack"
        }
    }

    private struct Entry {
        let name: String
        let kind: String
        let bytes: Data
    }

    static func install(_ data: Data) throws -> Result {
        guard data.count <= 128 * 1024 * 1024 else {
            throw PackError.invalid("Original game pack exceeds the 128 MB safety limit")
        }
        var offset = 0
        func take(_ length: Int) throws -> Data {
            guard length >= 0, offset <= data.count,
                  length <= data.count - offset else {
                throw PackError.invalid("Truncated original game pack")
            }
            defer { offset += length }
            return data.subdata(in: offset..<(offset + length))
        }
        func uint16() throws -> Int {
            let raw = try take(2)
            return Int(raw[raw.startIndex]) | (Int(raw[raw.startIndex + 1]) << 8)
        }
        func uint32() throws -> Int {
            let raw = try take(4)
            return Int(raw[raw.startIndex])
                | (Int(raw[raw.startIndex + 1]) << 8)
                | (Int(raw[raw.startIndex + 2]) << 16)
                | (Int(raw[raw.startIndex + 3]) << 24)
        }

        guard try take(8) == Data("CMASSET1".utf8) else {
            throw PackError.invalid("Not a Crazy Machines original asset pack")
        }
        let count = try uint32()
        guard count > 0 && count <= 1024 else {
            throw PackError.invalid("Invalid game pack entry count")
        }
        let allowed = Set(["ucm", "tga", "cml", "json"])
        var entries: [Entry] = []
        entries.reserveCapacity(count)
        var names = Set<String>()
        var models = 0
        var textures = 0
        var levels = 0

        for _ in 0..<count {
            let nameLength = try uint16()
            guard (1...255).contains(nameLength),
                  let name = String(data: try take(nameLength), encoding: .utf8),
                  !name.isEmpty, name != ".", name != "..",
                  !name.contains("/") && !name.contains("\\"),
                  !name.contains(":") && !name.contains("\0"),
                  !name.contains("\r") && !name.contains("\n") else {
                throw PackError.invalid("Invalid original resource name")
            }
            let kind = (name as NSString).pathExtension.lowercased()
            guard allowed.contains(kind), names.insert(name.lowercased()).inserted else {
                throw PackError.invalid("Unexpected or duplicate resource in game pack")
            }
            let length = try uint32()
            guard length > 0 && length <= 64 * 1024 * 1024 else {
                throw PackError.invalid("Invalid original resource length")
            }
            let expectedHash = try take(32)
            let bytes = try take(length)
            let actualHash = Data(SHA256.hash(data: bytes))
            guard actualHash == expectedHash else {
                throw PackError.invalid("Checksum mismatch: \(name)")
            }
            if kind == "ucm" {
                guard bytes.prefix(4) == Data("UCM1".utf8),
                      (try? CMUCMModel(data: bytes)) != nil else {
                    throw PackError.invalid("Invalid original 3D model: \(name)")
                }
                models += 1
            } else if kind == "tga" {
                guard (try? CMTGATexture(data: bytes)) != nil else {
                    throw PackError.invalid("Invalid original texture: \(name)")
                }
                textures += 1
            } else if kind == "json" {
                guard (try? CMOriginalSceneDocument.read(bytes)) != nil else {
                    throw PackError.invalid("Invalid original level: \(name)")
                }
                levels += 1
            }
            entries.append(Entry(name: name, kind: kind, bytes: bytes))
        }
        guard offset == data.count else {
            throw PackError.invalid("Trailing bytes after original game pack")
        }

        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let original = support.appendingPathComponent("OriginalGame", isDirectory: true)
        let scenes = support.appendingPathComponent("OriginalScenes", isDirectory: true)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: scenes, withIntermediateDirectories: true)

        // Reject conflicting on-device files BEFORE any imports. Existing
        // matching assets are harmless and permit retrying interrupted imports.
        for entry in entries {
            let folder = entry.kind == "json" ? scenes : original
            let target = folder.appendingPathComponent(entry.name)
            if FileManager.default.fileExists(atPath: target.path),
               try Data(contentsOf: target) != entry.bytes {
                throw PackError.invalid("Different on-device file already exists: \(entry.name)")
            }
        }
        var installed = 0
        var existing = 0
        for entry in entries {
            let folder = entry.kind == "json" ? scenes : original
            let target = folder.appendingPathComponent(entry.name)
            if FileManager.default.fileExists(atPath: target.path) {
                existing += 1
            } else {
                try entry.bytes.write(to: target, options: .atomic)
                installed += 1
            }
        }
        return Result(installed: installed, existing: existing,
                      models: models, textures: textures, levels: levels)
    }
}
