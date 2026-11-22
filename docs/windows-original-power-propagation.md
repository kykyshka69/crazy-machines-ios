# Original Crazy Machines Win32: electrical node values and real mechanism GOAL thresholds

Evidence is from the privately supplied original `CrazyMachines.exe`, SHA-256 `51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`, inspected as x86 PE32 machine code. All addresses refer to this specific user's executable. No proprietary binary data is committed. Reproduce with `python3 tools/audit_windows_power_propagation.py /private/game/CrazyMachines.exe`.

## Machine instructions, not inferred field names

| Win32 VA | Verified instruction / meaning |
| --- | --- |
| `0x4504C9` | Battery element writes IEEE-754 float **10.0** (`0x41200000`) to the electrical element-state slot `+0x40` |
| `0x44C8E8` | Power propagation path explicitly sets source `+0x40` to **zero** when a blocking condition at `+0x50` is present; the full meaning of this latter field is still being recovered |
| `0x44C8F2–0x44C8F8` | Copies source electrical state `+0x40` to target state `+0x40`, while traversing existing original wired endpoints |
| `0x450A2D–0x450A3E` | For `tmo_power_motor`, loads a float at the element state `+0x40`, **negates it**, and stores it as the child rotor's scalar command at `+0xE8` |
| `0x450A53–0x450A71` | Compares the **absolute magnitude** of that rotor command to double **0.5** and calls the already-confirmed GOAL event dispatcher `0x44B460` when it exceeds the threshold |
| `0x44D9C4–0x44D9E5` | For `tmo_power_lamp`, compares its electrical state `+0x40` to float **3.0** and calls `0x44B460` for values **strictly above 3** |
| `0x450E5F–0x450E90` | For `tmo_power_lightning`, compares its electrical state `+0x40` to float **1.0** and calls `0x44B460` for values **strictly above 1** |
| `0x451E21–0x451E2A` | Lamp visual animation uses the element power state **divided by 10**, not a fixed on/off number |

All the instruction bytes, thresholds, original resource names and file identity are independently validated by the read-only auditor. It checks 13 exact x86 sites, three float constants, and one double. The native portable Swift tests exercise these exact scalar operations, including signs, boundaries, NaN, duplicates and nonmatching GOAL elements.

## iOS integration and limitations

`CMOriginalWindowsPowerScalar` encapsulates the verified battery value, one-step power transfer, motor sign inversion, threshold rules and lamp visual factor. `CMOriginalWindowsElectricalGoals` accepts canonical, imported `tmo_` object IDs and checks only the lamp and lightning goal types proven to call the Win32 dispatcher for a power signal. Bell, switch, C4 and unrelated goals are **not** credited by electricity merely because they have GOAL markers.

`CMOriginalPowerCircuit` remains a restricted **experimental** topology runner: a player must explicitly pair original `tmo_power_plug` objects and may opt in to simulated electrical actions. Its graph traversal uses the real device ownership and switch states but lacks the original file's cable persistence, physical wire/circuit constraints, source polarity, current/resistance, generator/solar inputs, and return-path solver. In this prototype, battery-reachable nodes inherit 10.0 as a provisional state, instead of inventing a voltage from `VALF` or claiming faithful electrical parity. The rotor drive uses the recovered sign but its iOS capped speed and inertial response are still approximations.

The Win32 machine-code functions describe **how a device reacts to an electrical value**, not the complete process that calculates it. Reconstructing the source field `+0x50`, switch lever mechanical thresholds, generator input graph, and cable traversal/solver remains necessary. All 102 original levels must still be physically played and compared to the original Windows behavior before claiming a full port.