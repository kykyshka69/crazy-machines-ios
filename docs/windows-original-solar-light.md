# Crazy Machines original Windows engine — solar ray energy (2026-11-22)

Original source of evidence: privately supplied user-owned `CrazyMachines.exe`, SHA-256 `51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`. Machine instructions were inspected in the local x86 disassembly and checked against the original PE32 using `python3 tools/audit_windows_solar_exe.py /private/path/CrazyMachines.exe`. **No proprietary Windows assets or executable bytes are committed.** The read-only audit checks 26 original instruction sites, 3 IEEE-754 float constants, and 4 type strings.

## Recovered original mathematical stages

- `0x44FB90–0x44FBDC`: optical interactions dispatch based on original object types `tmo_light_flower`, `tmo_power_solarcell`, and `tmo_light_magnifier`; they are not unconditional sources.
- `0x44FC53`, `0x44FD77–0x44FD98`, `0x44FDCF–0x44FE23`: when an actual original light-emitter hit is resolved, input power at the source state `+0x40` is divided by **10**, multiplied by a geometric intersection weight, and divided by **(measured path length × 5.0)**. The exact geometric intersection comes from separate `0x409650` collision/raycast routines; *we have not yet reconstructed those hit tests*.
- `0x44FE2E–0x44FF30`: original pocket-lamp/optics branches contribute additional geometrically measured light; these need the true ray/object hit evidence.
- `0x44FF35–0x44FF52`: the light accumulator is **upper-clamped to 1.0**. It is **not** forced to 1.0 if no light enters (zero input remains zero).
- `0x450043–0x450092`: for `tmo_power_solarcell` only, the clamped fraction is multiplied by **10.0** and stored in electric state `+0x40`.
- `0x450095–0x4500B9`: the original cell invokes the `0x44B460` GOAL dispatcher if its output is **strictly greater than 1.0**. Zero light must not count as a GOAL.
- `0x45010F–0x450115`: the powered solar cell forwards that electrical state into the original wired endpoint dispatcher `0x44C8A0` when a connection exists. Other flower/magnifier branches are distinct and cannot silently share the same solar output equation.

The Swift `CMOriginalWindowsSolarSignal` implements **only the evidenced scalar stages**. The imported original `tmo_power_solarcell` remains unpowered without independently observed ray contributions. `CMOriginalPowerCircuit.experimentalNetworkSignals(solarRayContributionsByDeviceID:)` accepts ray contributions **only for actual imported solar-device IDs** and only when the supplied observations are finite/nonnegative; it cannot fabricate sunlight merely from an original level's `VALF`, the presence of a light-emitting object, or device proximity. `CMOriginalWindowsElectricalGoals.activeGoalIDs(solarRayContributionsByDeviceID:)` uses the same optically derived signal for authentic solar GOALs; a battery voltage on a solar object cannot substitute for a light hit. The graph remains an explicitly experimental approximation rather than the complete electrical solver.

The original 102 Professor scenes include solar cells on levels 15, 16, 33, 44, 54, 65 and 92. No genuine test of correct play/completion in those levels has yet been performed with the recovered Win32 photometry and 3D source-ray intersection model.

## Still required before stage 1 completion

1. Recover original raycasting and occlusion routines (`0x409650`, geometric vectors and optical effects), including lamp/pocketlamp/magnifier/flower reflections, ray intersection weights, attenuation path length, and correct coordinate space for SceneKit.
2. Feed the measured rays into the evidence-only collector on real iPhone 3D scenes, with deterministic frame stepping and physics contact ordering; verify exact source state changes as lights rotate or switch off.
3. Reconstruct the entire Win32 circuit solution, native switch `+0xEC / +0xC8` gate, disrupter phase physical units, non-electric mechanism physics and 102 puzzle goal/lifecycle parity; do not treat CI fixture success as original Windows victory.