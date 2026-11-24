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
  let collisionTypes = ["tmo_ball_steel","tmo_ball_basket","tmo_ball_billard",
      "tmo_ball_beach","tmo_ball_tennis","tmo_ball_tt","tmo_domino","tmo_crate",
      "tmo_bucket","tmo_rope_cage","tmo_weight","tmo_board","tmo_zone"]
  let collisionNames = ["BALL_STEEL","BALL_BASKET","BALL_BILLARD","BALL_BEACH",
      "BALL_TENNIS","BALL_TABLETENNIS","DOMINO","CRATE","BUCKET","CAGE","WEIGHT"]
  for (i,type) in collisionTypes.enumerated() {
      precondition(CMOriginalCollisionSound.effect(type:type)
          == (i < collisionNames.count ? "SOUND_FX_"+collisionNames[i] : nil))
  }
  for a in collisionTypes {
      for b in collisionTypes {
          for ma in [true,false] {
              for mb in [true,false] {
                  var gate = CMOriginalCollisionSound.Gate()
                  let expected = a == "tmo_zone" || b == "tmo_zone" ? [] :
                      Set([ma ? CMOriginalCollisionSound.effect(type:a) : nil,
                           mb ? CMOriginalCollisionSound.effect(type:b) : nil].compactMap{$0}).sorted()
                  for bad in [0,-1,0.02,.nan,.infinity] as [Double] {
                      precondition(gate.consume(a:"a",b:"b",typeA:a,typeB:b,movableA:ma,movableB:mb,impulse:bad).isEmpty)
                  }
                  precondition(gate.consume(a:"a",b:"b",typeA:a,typeB:b,movableA:ma,movableB:mb,impulse:1)==expected)
                  precondition(gate.consume(a:"b",b:"a",typeA:b,typeB:a,movableA:mb,movableB:ma,impulse:1).isEmpty)
                  gate.end("b","a")
                  precondition(gate.consume(a:"a",b:"b",typeA:a,typeB:b,movableA:ma,movableB:mb,impulse:1)==expected)
              }
          }
      }
  }
  print("Original Win32 completion-dialog value-script semantics verified")
 }
}