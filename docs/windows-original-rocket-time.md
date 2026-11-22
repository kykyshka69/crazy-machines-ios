# Native Win32 rocket fuse and explosion GOAL

Original user's CrazyMachines.exe SHA-256: 51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6.

At 0x44F03B–0x44F04E the original Windows engine requires rocket element physical state +0xEC to be precisely float 2.0, before selecting type tmo_heat_rocket at 0x44F1A2. A native engine clock read from +0x124 minus the rocket's recorded launch timestamp +0x130 is compared against original double 3.0 at 0x44F288–0x44F2A7. The x87 test ah,0x41; jne accepts elapsed time strictly GREATER THAN 3.0, rejecting equality. After running physical Engine/Explode operations it writes +0xEC=3.0 (0x44F33C) and emits the original GOAL 0 callback at 0x44F354.

CMOriginalWindowsRocketTimer implements these recovered type-specific transition conditions and rejects missing original flying/engine input, backwards time and nonfinite data. All 16 GOAL-marked rockets in the user's 102 scenes (11 in level 102) need real ignition, engine physics, force, and post-explosion state transitions to be wired before they can count as solved; this helper alone does NOT trigger them. Real Windows optical/thermal flame collisions and the complete 102-level wins are still unfinished.

Reproduce with python3 tools/audit_windows_rocket_exe.py /private/CrazyMachines.exe. It verifies 13 x86 instruction sites, original selector and native state/timer constants; no proprietary bytes are committed.
