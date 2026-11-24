import Foundation
@main
struct OriginalVSCCompletionSmoke {
 static func main() throws {
  let text = "# FAKT Software Value Script\n[DIALOG]\nName = \"task_done\"\n[BUTTON_CONTINUE]\nName = \"Continue\"\nID = 1\n[BUTTON_REPLAY]\nName = \"Replay\"\nID = 2\n[BUTTON_MAINMENU]\nName = \"Main_menu\"\nID = 3\n"
  let script = try CMOriginalVSCDecoder.parse(text)
  let actions = CMOriginalVSCScriptLibrary.CompletionActions(script: script)!
  precondition(actions.dialogName == "task_done")
  precondition(actions.continueName == "Continue")
  precondition(actions.replayName == "Replay")
  precondition(actions.mainMenuName == "Main_menu")
  let invalid = try CMOriginalVSCDecoder.parse(text.replacingOccurrences(of:"ID = 2",with:"ID = 5"))
  precondition(CMOriginalVSCScriptLibrary.CompletionActions(script:invalid) == nil)
  let sound = try CMOriginalVSCDecoder.parse("""
  # FAKT Software Value Script
  [SOUND_FX_SPRING]
  Type = "FAKTSOUND_SOUND_2D"
  File = "data/sounds/fx/spring.wav"
  MultiStatic = 1
  MultiStaticCount = 4
  [SOUND_FX_MOTOR]
  Type = "FAKTSOUND_SOUND_2D"
  File = "data/sounds/fx/motor.wav"
  Loop = 1
  [SOUND_FX_INVALID]
  Type = "FAKTSOUND_SOUND_2D"
  File = "data/sounds/fx/../bad.wav"
  """)
  let effects = CMOriginalSoundLibrary.effects(script:sound)
  precondition(effects.count == 2)
  precondition(effects["SOUND_FX_SPRING"]?.filename == "spring.wav")
  precondition(effects["SOUND_FX_SPRING"]?.voiceCount == 4)
  precondition(effects["SOUND_FX_SPRING"]?.loops == false)
  precondition(effects["SOUND_FX_MOTOR"]?.loops == true)
  let wav = Data([82,73,70,70,38,0,0,0,87,65,86,69,
      102,109,116,32,16,0,0,0,1,0,1,0,34,86,0,0,
      68,172,0,0,2,0,16,0,100,97,116,97,2,0,0,0,0,0])
  precondition(CMOriginalSoundLibrary.validWAV(wav))
  precondition(!CMOriginalSoundLibrary.validWAV(Data(wav.dropLast())))
  var bad = wav; bad[4] = 0
  precondition(!CMOriginalSoundLibrary.validWAV(bad))
  print("Original Win32 completion-dialog value-script semantics verified")
 }
}