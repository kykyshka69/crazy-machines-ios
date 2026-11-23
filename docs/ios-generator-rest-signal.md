# Original generator rotor — exact zero on observed stop

The actual original Windows generator source is tied to the motion of its
`tmo_power_generator_rotor` (native power via absolute rotor +0xE8), not
an always-on battery. The original scalar conversion remains implemented
separately by `CMOriginalWindowsPowerScalar.generatorSignal`.

The iOS SceneKit coordinator samples the real imported original rotor body
periodically and debounces tiny speed fluctuations. Previously a last-reported
nonzero speed such as 0.03 could persist forever once the physical angular
speed became exactly zero: the old 0.05 polling debounce silently discarded
that change, so `generatorRotorSpeedsByDeviceID` could continue energizing
downstream consumers.

`CMOriginalGeneratorRotorObservation` now has an explicit stop transition:
- It never reports a source activation when the initial wheel is idle.
- A previously reported nonzero source changes to exactly zero once the
  observed wheel is at SceneKit rest, regardless of the debounce difference.
- The usual debounce remains for normal nonzero rotation.
- Repeated zero observations are ignored, with no invented GOAL or energy.

**Accuracy limit:** the 0.01 SceneKit rest epsilon is a prototype numerical
threshold, **not** a recovered Windows rotor/torque parameter. The physical
motor/generator transfer ratios and original shaft dynamics still need
genuine in-game parity tests. This fix is lifecycle/source-state correctness
for the current iOS engine, not completion of Stage 1.
