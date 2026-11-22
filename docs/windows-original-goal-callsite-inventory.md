# Original Win32 GOAL dispatcher: 42 exact call sites

SHA-gated real original EXE: 51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6.

Decoded target 0x44B460 receives two independent event channels: channel zero GOAL and channel one CONNECTED_TO. All 42 direct x86 CALL rel32 instructions to that dispatcher have been independently audited, not inferred from the CML GOAL metadata. Reproduce with python3 tools/audit_windows_goal_calls.py /private/path/CrazyMachines.exe. The real EXE cannot be redistributed with public CI.

Particularly useful genuine callback sites:
- 0x44BCE5: generator electrical goal from measured rotor signal.
- 0x44C0D5: centrifugal rotation mechanism goal.
- 0x44C1DC: conveyor / gear mechanism goal.
- 0x44C7EF: steam whistle mechanism goal.
- 0x44D9A2: actual ball-inside-bucket geometry GOAL.
- 0x44D9E5: lamp powered goal.
- 0x450039: flower illumination / growth state GOAL.
- 0x4500B9: solar-cell power GOAL.
- 0x45086E: switch-goal dispatch, NOT simply a manual tap.
- 0x450A71: motor electrical goal.
- 0x450C7C: bell electrical goal.
- 0x450E90: lightning electrical goal.
- 0x450FED: ammeter electrical goal.
- 0x44F4D2: windmill rotation signal GOAL.
- 0x44FA58, 0x44FAA1: belt-flag rotational state GOAL branches.

These are source-call locations, not complete physical signal semantics. The real Windows code includes additional geometry, heat, valve, combustible, air and force state before most of those calls. Naming a callback does not supply the missing conditions nor authorize iOS to credit a goal. All 102 original levels must be played and verified in their actual imported 3D physics before stage one completion is claimed.
