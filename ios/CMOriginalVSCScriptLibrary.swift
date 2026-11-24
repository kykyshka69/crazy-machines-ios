import Foundation

/// Load the user's own Windows Value Script files from the original private
/// iPhone sandbox, never from invented source-code defaults. The original
/// FAKT `leveldone.vsc` has one DIALOG and three actions (Continue, Replay,
/// Main_menu). This is UI metadata, NOT Windows puzzle win calculation.
public enum CMOriginalVSCScriptLibrary {
    public struct CompletionActions: Equatable {
        public let dialogName: String
        public let continueName: String
        public let replayName: String
        public let mainMenuName: String

        public init?(script: CMOriginalVSCDecoder.Script) {
            guard let dialog = script.section(named: "DIALOG"),
                  let name = dialog.value(for: "Name"),
                  name == "task_done",
                  let cont = script.section(named: "BUTTON_CONTINUE"),
                  cont.value(for: "ID") == "1",
                  let contName = cont.value(for: "Name"),
                  let replay = script.section(named: "BUTTON_REPLAY"),
                  replay.value(for: "ID") == "2",
                  let replayName = replay.value(for: "Name"),
                  let main = script.section(named: "BUTTON_MAINMENU"),
                  main.value(for: "ID") == "3",
                  let mainName = main.value(for: "Name"),
                  !contName.isEmpty, !replayName.isEmpty, !mainName.isEmpty,
                  [contName, replayName, mainName].allSatisfy({ $0.count <= 80 })
            else { return nil }
            dialogName = name
            continueName = contName
            self.replayName = replayName
            mainMenuName = mainName
        }
    }

    public static func loadLevelDone(directory: URL) -> CompletionActions? {
        let file = directory.appendingPathComponent("leveldone.vsc")
        guard let properties = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              properties.isRegularFile == true,
              let size = properties.fileSize,
              (32...100_000).contains(size),
              let bytes = try? Data(contentsOf: file),
              bytes.count == size,
              let script = try? CMOriginalVSCDecoder.read(bytes) else { return nil }
        return CompletionActions(script: script)
    }
}

/// Exact effect names and filenames from the private original soundfx.vsc.
/// No fallback sounds or inference from anonymous CAB entry numbers.
public enum CMOriginalSoundLibrary {
    public struct Effect: Equatable {
        public let filename: String
        public let loops: Bool
        public let voiceCount: Int
    }

    public static func effects(script: CMOriginalVSCDecoder.Script) -> [String: Effect] {
        var effects: [String: Effect] = [:]
        var seen = Set<String>()
        for section in script.sections {
            let id = section.name.uppercased()
            guard id.hasPrefix("SOUND_FX_") else { continue }
            guard seen.insert(id).inserted else { effects.removeValue(forKey: id); continue }
            guard section.value(for: "Type") == "FAKTSOUND_SOUND_2D",
                  let raw = section.value(for: "File"),
                  raw.hasPrefix("data/sounds/fx/") else { continue }
            let filename = String(raw.dropFirst("data/sounds/fx/".count))
            guard filename.count <= 128, filename.lowercased().hasSuffix(".wav"),
                  filename.utf8.allSatisfy({ (65...90).contains($0) ||
                    (97...122).contains($0) || (48...57).contains($0) ||
                    $0 == 95 || $0 == 45 || $0 == 46 }),
                  !filename.contains("..") else { continue }
            let count = section.value(for: "MultiStatic") == "1"
                ? (Int(section.value(for: "MultiStaticCount") ?? "") ?? 1) : 1
            guard (1...8).contains(count) else { continue }
            effects[id] = Effect(filename: filename, loops: section.value(for: "Loop") == "1",
                                 voiceCount: count)
        }
        return effects
    }

    public static func load(directory: URL) -> [String: Effect] {
        let file = directory.appendingPathComponent("soundfx.vsc")
        guard let metadata = try? file.resourceValues(forKeys: [.isRegularFileKey,.fileSizeKey]),
              metadata.isRegularFile == true, let size = metadata.fileSize,
              (32...100_000).contains(size),
              let bytes = try? Data(contentsOf: file), bytes.count == size,
              let script = try? CMOriginalVSCDecoder.read(bytes) else { return [:] }
        return effects(script: script)
    }

    /// Accept bounded PCM RIFF/WAVE effects, checking all chunk bounds.
    public static func validWAV(_ data: Data) -> Bool {
        guard (44...8_000_000).contains(data.count) else { return false }
        let b = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(b[i]) | Int(b[i+1]) << 8 }
        func u32(_ i: Int) -> Int {
            Int(b[i]) | Int(b[i+1]) << 8 | Int(b[i+2]) << 16 | Int(b[i+3]) << 24
        }
        guard b[0..<4].elementsEqual("RIFF".utf8),
              b[8..<12].elementsEqual("WAVE".utf8), u32(4) == b.count-8 else { return false }
        var i = 12
        var alignment: Int?
        var length: Int?
        while i < b.count {
            guard i <= b.count-8 else { return false }
            let size = u32(i+4), start = i+8
            guard size <= b.count-start, size+(size%2) <= b.count-start else { return false }
            if b[i..<i+4].elementsEqual("fmt ".utf8) {
                guard alignment == nil, size >= 16, u16(start) == 1 else { return false }
                let channels = u16(start+2), rate = u32(start+4), bits = u16(start+14)
                guard (1...2).contains(channels), (8000...96000).contains(rate),
                      bits == 8 || bits == 16,
                      u16(start+12) == channels*bits/8,
                      u32(start+8) == rate*channels*bits/8 else { return false }
                alignment = channels*bits/8
            } else if b[i..<i+4].elementsEqual("data".utf8) {
                guard length == nil, size > 0 else { return false }
                length = size
            }
            i = start+size+(size%2)
        }
        guard let alignment, let length else { return false }
        return length % alignment == 0
    }
}


/// Original collision effect selection recovered from the Windows dispatcher.
/// Impulse is a SceneKit observation, not the original native scalar.
public enum CMOriginalCollisionSound {
    public static func effect(type: String) -> String? {
        switch type {
        case "tmo_ball_steel": return "SOUND_FX_BALL_STEEL"
        case "tmo_ball_basket": return "SOUND_FX_BALL_BASKET"
        case "tmo_ball_billard": return "SOUND_FX_BALL_BILLARD"
        case "tmo_ball_beach": return "SOUND_FX_BALL_BEACH"
        case "tmo_ball_tennis": return "SOUND_FX_BALL_TENNIS"
        case "tmo_ball_tt": return "SOUND_FX_BALL_TABLETENNIS"
        case "tmo_domino": return "SOUND_FX_DOMINO"
        case "tmo_crate": return "SOUND_FX_CRATE"
        case "tmo_bucket": return "SOUND_FX_BUCKET"
        case "tmo_rope_cage": return "SOUND_FX_CAGE"
        case "tmo_weight": return "SOUND_FX_WEIGHT"
        default: return nil
        }
    }

    public struct Gate {
        private struct Pair: Hashable {
            let first: String
            let second: String
            init(_ a: String, _ b: String) {
                first = min(a,b); second = max(a,b)
            }
        }
        private var sounded = Set<Pair>()
        public init() {}
        public mutating func consume(a: String, b: String, typeA: String, typeB: String,
                                     movableA: Bool, movableB: Bool, impulse: Double) -> [String] {
            guard a != b, typeA != "tmo_zone", typeB != "tmo_zone",
                  impulse.isFinite, impulse > 0.02 else { return [] }
            let ids = Set([movableA ? CMOriginalCollisionSound.effect(type: typeA) : nil,
                           movableB ? CMOriginalCollisionSound.effect(type: typeB) : nil].compactMap { $0 })
            guard !ids.isEmpty, sounded.insert(Pair(a,b)).inserted else { return [] }
            return ids.sorted()
        }
        public mutating func end(_ a: String, _ b: String) {
            sounded.remove(Pair(a,b))
        }
    }
}
