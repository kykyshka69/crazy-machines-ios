# Windows electric motor start and goal are separate operations

Evidence: the owner's SHA-gated `CrazyMachines.exe` disassembly, documented in
`docs/windows-original-power-propagation.md`, addresses 0x450A2D–0x450A71.

* 0x450A2D–0x450A3E copies **negative incoming electrical power** into the
  motor child's rotor +0xE8 command. This operation has **no 0.5 cutoff**.
* 0x450A53–0x450A71 **separately** calls GOAL channel 0 when
  `abs(rotor +0xE8) > 0.5`. A nonzero, subthreshold motor is not a
  completed GOAL, but it still receives a rotor command.
* The motor may receive electricity only through real observed or
  explicitly player-connected power terminals, not mere CML proximity.

## iOS implementation

`CMOriginalQuickPlayView` no longer requires the GOAL threshold before
passing a genuine source scalar to its original UCM motor rotor. The renderer
commands rotation around the authentic Z axle. `CMOriginalMotorActuator`
implements the opt-in, **NOT reverse-engineered** bounded speed curve
(maximum 3 rad/s at a prototype command magnitude of 10) and acceleration
(9 rad/s²). A motor can now visibly respond to a 0.25 input while Win32
goal logic correctly refuses to credit that input. When power disappears
(e.g., an opened switch or stopped generator), the last driven rotor
ramps toward rest without an instantaneous pose reset. This coastdown
is a prototype, not proof of Windows inertia, mechanical torque, or drag.

Portable tests verify small signed inputs, the Win32 GOAL separation,
reversal, the post-power coastdown and non-finite rejection. CI also
typechecks the actual SceneKit bridge on macOS.

## Still unverified

The original transfer function from +0xE8 to motor torque/velocity,
actual rotational inertia, axle constraints, contact/gear forces,
bidirectional mechanical loading, return-path circuit behavior and
true PC level goals remain undecoded. No puzzle is marked completed
solely because a motor moves.
