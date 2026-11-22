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
  print("Original Win32 completion-dialog value-script semantics verified")
 }
}