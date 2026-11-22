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