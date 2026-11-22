# Original Crazy Machines Windows win counter: recovered execution path

This analysis is based on **the user's actual PE32 `CrazyMachines.exe`**, SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.
All addresses below are 32-bit virtual addresses specific to this build.
No original executable, script, texture, level text, or model bytes are distributed
with the source repository.

## Proven Win32 instructions

| Windows VA | Verified behavior |
|---|---|
| `0x422E80`, `0x422ECC` | Parse `GOAL` as integer into object `+0x160` |
| `0x422FE2`, `0x42302E` | Parse directional `CONNECTED_TO` object index into `+0x174` |
| `0x44AC46` | Resolve linked object index into a pointer stored at `+0x170` |
| `0x454DE0` | Scan scene objects, count one win input for each nonzero `GOAL` and one for each nonnull linked-target pointer, clearing their independent latches |
| `0x454E70` | Save the required number at controller `+0xA8`, reset delivered number `+0xAC` |
| `0x44B460` | Mechanism event dispatcher: input channel 0 latches GOAL at `+0x164`, input channel 1 latches linked-target event at `+0x168`, each incrementing `+0xAC` at most once |
| `0x44B54B` | Compare delivered `+0xAC` with required `+0xA8` |
| `0x44B592` | Set completion latch at controller `+0xD4` |

The dispatcher references the original `task_solved` event; the executable also
contains `level_done_0`, `level_done_1`, `level_done_2` event names. These names
are **not** evidence that arbitrary SceneKit collisions reproduce Windows
mechanism signals, nor that the original rule for each object type has been decoded.

The original win gate is **two input channels**, not just an AND of
`GOAL 1` *or* `CONNECTED_TO`. A source with both a GOAL flag and a linked-target
pointer contributes **two** required win events. Each channel is separately
latched once, irrespective of repeated contacts. Conversely, the `GOAL` field
by itself is a required event *declaration*, not evidence of the event.

## iOS implementation scope

`CMOriginalWindowsGoalCounter` mirrors the Windows gating mechanism with
canonical object identities from `CMOriginalGameplaySession`. No unsigned or
opaque original game bytes enter the Git tree. This is integrated with a narrow
set of **physically observed** iOS events: exact source→target contacts from
SceneKit, the real tennis ball inside the real level-four bucket, and the actual
lever state transition of an original switch object. Counter zero, pause,
unknown IDs, reverse-direction contact, duplicate events and stale scene IDs
must not credit progress. The UI explicitly marks experimental mechanisms.

This gate is necessary but **not sufficient** for full game parity: the Win32
caller decides which object action invokes `0x44B460` and which channel it
means. Reconstructing each mechanism event, electrical connectivity, thermal,
optical, hydraulic and pneumatic rules, and the original physics integration
is still required before any of the 102 puzzles can be claimed fully solved.

## FSC vs VSC evidence

The player's encrypted `scripts/elements/elements.fsc` was decoded with the
verified Win32 FSC transformation and yielded 157 original object templates.
These include model attachment, BITS defaults and field overrides; an actual
mechanism's source of power or physical event remains separate. Initial trials
of the same key against original `.vsc` scripts failed validation. Thus no VSC
execution semantics are claimed, and `.vsc` files cannot yet be represented as
readable source with this decoder.

## Reproduce the evidence privately

Run the read-only verifier against the player's owned executable:

```bash
python3 tools/audit_windows_goal_exe.py '/private/game/CrazyMachines.exe'
```

The tool rejects an EXE with a different SHA-256, missing PE structure, any
changed instruction site or event-name mismatch. Public CI uses only a
synthetic-invalid-file rejection unit test; **it does not execute, upload or
redistribute the private Windows executable**.