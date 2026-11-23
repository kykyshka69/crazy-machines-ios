# Original Crazy Machines: recovered cable construction and iOS electrical topology

**Source:** the user's privately extracted `CrazyMachines.exe`, SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.
All addresses below are VAs in this PE32 x86 binary; no proprietary executable,
model, or level file is committed.

## Verified Win32 instruction chain

| VA | Observation |
|---|---|
| `0x42FCB9` | Pushes the `power_cable` resource name (`0x4E9C48`) |
| `0x42FCDA` / `0x42FCE1` | Requests first end with arguments `(1,0)` via `0x41F7C0` |
| `0x42FCF0` / `0x42FCF7` | Requests second end with `(1,1)` via `0x41F7C0` |
| `0x42FD06` | Looks up the `Power` material (`0x4E9C54`) |
| `0x42FD27`, `0x42FD33` | Installs the same material pointer in each end's `+0x44` field |
| `0x42FD42`–`0x42FD4B` | Passes both retrieved endpoints and `power_cable` into `0x42CE60` to construct the cable |

Run `python3 tools/audit_windows_power_cables.py /private/path/CrazyMachines.exe` to check eight x86 sites and two immutable original resource names. The verifier refuses any different EXE hash. This is a **cable-construction** call path, not proof of cable electrical resistance, current, generator torque, or switch truth tables.

## Genuine power connections in the 102 Professor levels

The original level scenes contain **321 `tmo_power_plug`** objects. The engine-independent session already retains the exact imported plug ownership, parent device and optional `VALF` terminal number. A `VALF` number is an original terminal ID; it is **not** a voltage, a device-power Boolean, or a duplicate-pair key. Original numbered terminals are unique per puzzle, so pairing equal `VALF`s would create no real cables.

`CMOriginalPowerCircuit` now holds only explicitly connected pairs of original plug IDs. It prevents double-use of a plug, self-connections, unknown endpoints, or arbitrary same-type/nearest-neighbor links. Its connectivity tracer starts at genuine `tmo_power_battery` owners, traverses explicit connected devices, and allows pass-through across original `tmo_power_switch` objects only while the original lever is on. Original distributors pass through; motors and lamps are **loads, not bridges**. Generator and solar sources are NOT energized without separate mechanism/light input. Other devices are never secretly initialized as a source.

The iOS player can select two imported original `tmo_power_plug` meshes before starting physics to connect/remove their logical cable. The first selection is remembered and a text HUD reports what was accepted. **No fake wire graphics** or proprietary assets are bundled in public CI. The optional wired-rotor prototype uses reachability of a motor's real parent owner to drive its real imported rotor (with an explicitly approximate 3 rad/s cap); it must be opted into and is not described as recovered Windows current behavior.

## Not yet reverse-engineered

- How actual original CML saves *existing* cable end pairs, cable geometry and electrical terminal polarity.
- Original cable attachment constraints, conductivity, switch truth tables, parallel branching, source EMF, current, and return-path semantics.
- Generator mechanical-input torque, solar illumination, C4/disrupter behavior and lamp/bell effects.
- VSC binary script execution and all per-mechanism callbacks. Original VSC files have not been decoded into source by the FSC key; the fact that Windows itself can execute them is not evidence that the iOS implementation can.

This prevents false claims of faithfully running electrical puzzles or all 102 levels. It replaces phantom connections with a conservative native event/topology foundation for continuing recovery.
## Recovered native connector walk: multiport transmission (2026-11-23)

New direct disassembly of the user's hash-verified original executable (same
SHA-256 as above) clarifies the native `0x44C8A0` traversal:

- `0x44C8BE–0x44C8D5` checks and writes traversal guard byte `+0x178`
  (visited state 2) on the current attached native component.
- `0x44C8DD–0x44C8F8` zeroes source electrical scalar `+0x40` if the
  source's still-unidentified `+0x50` pointer is present, then copies this
  scalar to the receiving endpoint. The meaning of the `+0x50` field is
  not yet recovered; do not manufacture its state from CML `VALF`.
- `0x44C911–0x44C982` enumerates the physical connector slots tagged
  `0xFE` and identifies the incoming one; the loop excludes the incoming
  slot when a different output slot exists, then copies the scalar to
  the next output's `+0x40`.
- `0x44C98B–0x44CAC8` applies the already verified switch contact and
  disrupter wheel gates. `0x44CBD6–0x44CC37` recursively traverses
  another physical connection **except when its connected native object
  is `tmo_power_battery`** (exact type string at `0x4EC648`).

The 102 original CML scene exports contain genuine power motors and lamps
with more than one `tmo_power_plug` (including motor instances with 2–3
plugs). Previously the iOS experimental graph always stopped at a motor
or lamp even when two different physical ends were actually cabled.
`CMOriginalPowerCircuit` now supports that *explicit multiport* route,
without pairing by proximity or using original terminal numbers as voltages.
Switch/disrupter/conditional source behavior retains stricter independent
restrictions. This is an evidence-based topology improvement, **not yet
voltage/current, load drop, source-mixing or Win32 full circuit parity**.
