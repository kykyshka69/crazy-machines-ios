# Authentic Windows candle and blowtorch user interaction (0x4349A0)

Recovered from the owner's SHA-256-verified original CrazyMachines.exe (SHA-256 51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6).

At 0x434903 the native player click checks object interaction flag bit 0x10 in the object's +0x188 byte and rejects noninteractive elements. At 0x4349A0 the Windows handler handles the original tmo_candle family (including the dynamic tmo_candle_dyn prefix) and tmo_heat_blowtorch. At 0x4349EF..0x434A20, the source +0xEC is toggled exactly 0 to 1 or 1 to 0. The selected native heat visual or pump component +0xFC is then written at 0x434A20..0x434A44. At 0x434A50..0x434A76, the native engine separately compares the source +0xEC with its internal +0xF0 before calling GOAL: **the iOS source toggle alone must never credit the level.**

This change wires genuine click state into the iOS imported CML scene. Original per-instance VALF 1 means active when the scene begins or resets. The authentic light_glow.tga billboard on to_candle_glow now responds on/off per original candle object; blowtorch state is tracked independently even when it has no billboard. No source heat emission, pressure, ignition spread, false GOAL, or Windows callback is manufactured. At least seven real GOAL-marked candles, one dynamic candle and two blowtorches exist across 102 original level exports; their Win32 physical GOAL semantics beyond this direct UI state still need completion. 

## Native GOAL trigger recovered (not guessed)

The native scene initializer at **0x45523B–0x455241** copies each actual element state `+0xEC` into its baseline `+0xF0` at the start of the puzzle, before the player can press it. This establishes the previously unknown value used by the click condition. Candle/blowtorch input at **0x434A50–0x434A76** and pocketlamp input at **0x434AE6–0x434B12** compare the updated state against that captured baseline with x87 `fucompp`, `test ah,0x44`, `jnp`. Equal 0/1 states skip GOAL; unequal states reach native dispatcher `0x44B460` channel 0. The Swift session now preserves exactly that baseline using the scene-authored `VALF 1` or the original default 0, and emits GOAL only for a genuine GOAL-marked source that changed against its own baseline. Toggling the same item back to its original state is *not* a new GOAL; the counter latches first eligible events just once. It is never enough to fake fire, optical rays, or electrical flow.

## Reproducible native Windows proof

The author's original x86 `CrazyMachines.exe` was individually checked at 22 x86 instruction sites from 0x4226DE through 0x455241/0x434B12, including `VALF` load to +0xEC, start-state snapshot into +0xF0, clickable flag 0x10, both 0/1 toggles, both x87 status comparisons, and GOAL calls. Four exact original type/field selector strings were also verified. `python3 tools/audit_windows_source_click_exe.py /private/CrazyMachines.exe` reproduces the proof with SHA-256 verification. CI tests rejection of nonmatching EXEs, never redistributes proprietary game data.

## Real original CML active source state before Run

The per-element CML `VALF 1` initializes native source `+0xEC` when the scene is imported, **not** only when the player starts physics. Native pocketlamp/candle visual glow billboards in the iOS arrangement scene now begin in their authentic original on/off state. A player may not toggle them while the simulation is stopped; Run and Reset restore each element's authored initial scalar.
