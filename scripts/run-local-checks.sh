#!/usr/bin/env bash
# Run portable checks without GitHub-hosted runners (Linux or macOS).
set -euo pipefail
cd "$(dirname "$0")/.."
# Fail fast if a Git tree update accidentally dropped a referenced
# original physics source, before spending minutes compiling Xcode/Swift.
python3 tools/check_stage1_source_references.py
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Swift toolchain: $(swiftc --version | head -1)"
# Parse iOS Swift sources even on Linux. This catches syntax errors in
# SceneKit/SwiftUI files without pretending Apple SDK typechecking succeeded.
for source in ios/*.swift; do
  swiftc -frontend -parse "$source" -o /dev/null
done
echo "iOS Swift syntax parsing passed (Apple SDK typecheck not performed)."
swiftc ios/CMPhysics2D.swift ios/CMPinJoint2D.swift ios/CMSpringJoint2D.swift ios/CMPivotJoint2D.swift ios/CMLevelDocument.swift tests/CMLevelDocumentSmoke.swift -o "$tmp/levels"
"$tmp/levels"
for spec in "CMPhysicsSmoke" "CMCircleCollisionSmoke" "CMSlopeSmoke" "CMFrictionSmoke" "CMAngularSmoke"; do
 swiftc ios/CMPhysics2D.swift "tests/$spec.swift" -o "$tmp/$spec"
 "$tmp/$spec"
done
swiftc ios/CMPhysics2D.swift ios/CMPinJoint2D.swift tests/CMPinSmoke.swift -o "$tmp/pins"
"$tmp/pins"
# Verify authentic PC scene metadata and model ownership on Linux too.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift ios/CMOriginalModelResolver.swift tests/OriginalSceneDocumentSmoke.swift -o "$tmp/original-scenes"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalModelResolver.swift tests/OriginalModelResolverSmoke.swift -o "$tmp/model-resolution"
"$tmp/model-resolution"
"$tmp/original-scenes"
# Avoid repeatedly decoding identical previous/next PC scenes while moving
# through all 102 levels on iPhone.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalLevelDocumentCache.swift \
  tests/OriginalSceneCacheSmoke.swift -o "$tmp/original-scene-cache"
"$tmp/original-scene-cache"
swiftc ios/CMOriginalLZW12.swift tests/OriginalLZW12Smoke.swift -o "$tmp/original-lzw"
"$tmp/original-lzw"
# Native CML decryption + scene export are portable Swift, not iOS-only stubs.
swiftc ios/CMOriginalLZW12.swift ios/CMOriginalWindows1251.swift ios/CMOriginalCMLContainer.swift ios/CMOriginalSceneDocument.swift ios/CMOriginalSceneTextParser.swift ios/CMOriginalLaboratorySceneInstaller.swift ios/CMOriginalPackScenePlanner.swift tests/OriginalCMLContainerSmoke.swift -o "$tmp/original-cml"
"$tmp/original-cml"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalSceneTextParser.swift tests/OriginalSceneTextParserSmoke.swift -o "$tmp/original-scene-text"
"$tmp/original-scene-text"
# Validate off-origin UCM sphere and zone sensor proxies without an Apple SDK.
swiftc ios/CMOriginalCollisionProxy.swift tests/OriginalCollisionProxySmoke.swift -o "$tmp/original-collision-proxies"
"$tmp/original-collision-proxies"
# Portable regression for genuine PC conveyor surface coordinates.
swiftc ios/CMOriginalConveyorContact.swift tests/OriginalConveyorContactSmoke.swift -o "$tmp/original-conveyor"
"$tmp/original-conveyor"
# Verify gear-to-gear and motor/gear/conveyor traction only at actual UCM contact.
swiftc ios/CMOriginalWindowsMechanicalTransfer.swift tests/OriginalWindowsMechanicalTransferSmoke.swift -o "$tmp/original-native-motion"
"$tmp/original-native-motion"
swiftc ios/CMOriginalWindowsMechanicalTransfer.swift ios/CMOriginalGearContactTransfer.swift tests/OriginalGearContactTransferSmoke.swift -o "$tmp/original-gears"
"$tmp/original-gears"
# Five PC glow references use authentic TGA images instead of UCM geometry.
swiftc ios/CMOriginalEffectBillboard.swift tests/OriginalEffectBillboardSmoke.swift -o "$tmp/original-glow"
"$tmp/original-glow"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalModelResolver.swift ios/CMUCMModel.swift ios/CMTGATexture.swift \
  ios/CMOriginalEffectBillboard.swift ios/CMOriginalAssetAudit.swift \
  tests/OriginalAssetAuditSmoke.swift -o "$tmp/original-assets"
"$tmp/original-assets"
# Original first-level puzzle objective uses only evidence from PC CONNECTED_TO.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPhysicsRolePlanner.swift ios/CMOriginalFirstLevelRun.swift \
  ios/CMOriginalElementsTemplateCatalog.swift ios/CMOriginalWindowsElementRules.swift \
  tests/OriginalFirstLevelRunSmoke.swift -o "$tmp/original-first-level"
"$tmp/original-first-level"
# User-placement Undo history is pure Swift; test reversibility and bounds.
swiftc ios/CMOriginalPlacementHistory.swift tests/OriginalPlacementHistorySmoke.swift -o "$tmp/original-undo"
"$tmp/original-undo"
swiftc ios/CMOriginalMagneticAttraction.swift tests/OriginalMagneticAttractionSmoke.swift -o "$tmp/original-magnet"
"$tmp/original-magnet"
# Original incoming CONNECTED_TO ball->bucket/cage target pairs MUST
# wait for native Catch/Test, not a generic exterior-wall collision.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalContainerCatchLinks.swift tests/OriginalContainerCatchLinksSmoke.swift \
  -o "$tmp/original-catch-links"
"$tmp/original-catch-links"
# Native Win32 0x44D9A2 GOAL tests STRICT distance < 0.1 for both
# authentic tmo_bucket and tmo_rope_cage owner IDs.
swiftc ios/CMOriginalWindowsCatchRadius.swift tests/OriginalWindowsCatchRadiusSmoke.swift \
  -o "$tmp/original-win32-catch-radius"
"$tmp/original-win32-catch-radius"
# Open tapered original rope-cage: convex hull would form a false lid.
swiftc ios/CMOriginalCageCollisionProxy.swift \
  tests/OriginalCageCollisionProxySmoke.swift -o "$tmp/original-rope-cage"
"$tmp/original-rope-cage"
# Build actual level-four container collider from measured original UCM bounds.
swiftc ios/CMOriginalBucketCollisionProxy.swift tests/OriginalBucketCollisionProxySmoke.swift -o "$tmp/original-bucket"
"$tmp/original-bucket"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalFourthLevelRun.swift tests/OriginalFourthLevelRunSmoke.swift \
  -o "$tmp/original-fourth"
"$tmp/original-fourth"
# Validate original Windows template inheritance, scene override priority,
# and genuine-object evidence-ledger wiring; no proprietary CI fixture.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPhysicsRolePlanner.swift ios/CMOriginalElementsScriptDecoder.swift \
  ios/CMOriginalElementsTemplateCatalog.swift ios/CMOriginalWindowsElementRules.swift \
  ios/CMOriginalWindowsScriptLibrary.swift ios/CMOriginalObjectiveEvidenceLedger.swift \
  tests/OriginalElementsPortableSmoke.swift -o "$tmp/original-windows"
"$tmp/original-windows"
# Exact once-only GOAL and CONNECTED_TO Win32 puzzle-completion counter.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsGoalCounter.swift tests/OriginalWindowsGoalCounterSmoke.swift \
  -o "$tmp/original-windows-win"
"$tmp/original-windows-win"
# Validate original Win32 two-ended power cable: real terminals and switch isolation.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsSolarSignal.swift ios/CMOriginalWindowsSwitchContactGate.swift ios/CMOriginalWindowsPowerDisrupter.swift ios/CMOriginalWindowsPowerScalar.swift \
  tests/OriginalPowerCircuitSmoke.swift \
  -o "$tmp/original-power"
"$tmp/original-power"
# Independently recovered Windows Value Script key: synthetic encrypted VSC
# and original completion-dialog button numbering, not bundled PC art.
swiftc ios/CMOriginalWindows1251.swift ios/CMOriginalVSCDecoder.swift \
  tests/OriginalVSCDecoderSmoke.swift -o "$tmp/original-vsc"
"$tmp/original-vsc"
swiftc ios/CMOriginalWindows1251.swift ios/CMOriginalVSCDecoder.swift \
  ios/CMOriginalVSCScriptLibrary.swift tests/OriginalVSCCompletionSmoke.swift \
  -o "$tmp/original-vsc-completion"
"$tmp/original-vsc-completion"
# Confirm exact Win32 scalar thresholds and original GOAL owner metadata.
swiftc ios/CMOriginalWindowsPowerScalar.swift tests/OriginalWindowsPowerScalarSmoke.swift \
  -o "$tmp/original-win32-power-scalar"
"$tmp/original-win32-power-scalar"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsPowerScalar.swift ios/CMOriginalWindowsSolarSignal.swift ios/CMOriginalWindowsSteamWhistle.swift ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsBeltFlag.swift ios/CMOriginalWindowsFlower.swift ios/CMOriginalWindowsRegionSelector.swift ios/CMOriginalWindowsRocketTimer.swift ios/CMOriginalWindowsElectricalGoals.swift \
  tests/OriginalWindowsElectricalGoalsSmoke.swift -o "$tmp/original-electrical-goals"
"$tmp/original-electrical-goals"
# Genuine generator is a mechanism-driven source, not an always-on battery.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsSolarSignal.swift ios/CMOriginalWindowsSwitchContactGate.swift ios/CMOriginalWindowsPowerDisrupter.swift ios/CMOriginalWindowsPowerScalar.swift \
  tests/OriginalGeneratorCircuitSmoke.swift -o "$tmp/original-generator"
"$tmp/original-generator"
# Recovered Win32 0x44CA59..0x44CAC8 disrupter gate, not a static
# always-on cable shortcut. Its wheel signal is orientation-dependent.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsSolarSignal.swift ios/CMOriginalWindowsSwitchContactGate.swift ios/CMOriginalWindowsPowerDisrupter.swift \
  ios/CMOriginalWindowsPowerScalar.swift \
  tests/OriginalWindowsPowerDisrupterSmoke.swift -o "$tmp/original-disrupter"
"$tmp/original-disrupter"
# Native original ammeter max+clamp and exact Z-axis indicator angle.
swiftc ios/CMOriginalWindowsAmmeter.swift tests/OriginalWindowsAmmeterSmoke.swift \
  -o "$tmp/original-ammeter"
"$tmp/original-ammeter"
# Exact native 0.3 windmill wheel +0xE0 abs threshold.
swiftc ios/CMOriginalWindowsWindmill.swift tests/OriginalWindowsWindmillSmoke.swift \
  -o "$tmp/original-windmill"
"$tmp/original-windmill"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsWindmill.swift tests/OriginalWindmillIdentitySmoke.swift \
  -o "$tmp/original-windmill-identity"
"$tmp/original-windmill-identity"
# Original motor GOAL is separate from rotor start/stop.
# The SceneKit torque/speed curve is still a declared bounded prototype.
swiftc ios/CMOriginalWindowsPowerScalar.swift ios/CMOriginalMotorActuator.swift \
  tests/OriginalMotorActuatorSmoke.swift -o "$tmp/original-motor-drive"
"$tmp/original-motor-drive"
# SceneKit generator motor-to-electric stop transition must not keep stale power.
swiftc ios/CMOriginalGeneratorRotorObservation.swift tests/OriginalGeneratorRotorObservationSmoke.swift -o "$tmp/original-generator-rest"
"$tmp/original-generator-rest"
# Exact Win32 solar-ray attenuation, 10x conversion, and solar-only GOAL.
swiftc ios/CMOriginalWindowsSolarSignal.swift tests/OriginalWindowsSolarSignalSmoke.swift \
  -o "$tmp/original-solar-scalar"
"$tmp/original-solar-scalar"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsSolarSignal.swift ios/CMOriginalWindowsSwitchContactGate.swift \
  ios/CMOriginalWindowsPowerDisrupter.swift ios/CMOriginalWindowsPowerScalar.swift \
  ios/CMOriginalWindowsSteamWhistle.swift ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsBeltFlag.swift ios/CMOriginalWindowsFlower.swift ios/CMOriginalWindowsRegionSelector.swift ios/CMOriginalWindowsRocketTimer.swift ios/CMOriginalWindowsElectricalGoals.swift \
  tests/OriginalWindowsSolarCircuitSmoke.swift -o "$tmp/original-solar-circuit"
"$tmp/original-solar-circuit"
# Authentic pocketlamp angular cone / native near and far beam constants.
swiftc ios/CMOriginalWindowsBeamRegion.swift ios/CMOriginalWindowsBeamFactory.swift \
  tests/OriginalWindowsBeamFactorySmoke.swift -o "$tmp/original-pocketlamp"
"$tmp/original-pocketlamp"
# Original Windows GOAL dispatcher SHA gate; no private EXE in public CI.
python3 -m unittest discover -s tools -p 'test_audit_windows_goal_calls.py'
# Verify the actual original region record identity before heat ignition.
swiftc ios/CMOriginalWindowsRegionSelector.swift tests/OriginalWindowsRegionSelectorSmoke.swift -o "$tmp/native-regions"
"$tmp/native-regions"

# Original UCM1 named attachment matrices, malformed-input safe.
swiftc ios/CMOriginalUCMNamedAnchors.swift tests/OriginalUCMNamedAnchorsSmoke.swift -o "$tmp/ucm-anchors"
"$tmp/ucm-anchors"

# Original x86 0x44F1DD..0x486400 physics force at body COM:
# exact live +0xFC scalar and native Direction, NOT invented power.
swiftc ios/CMOriginalWindowsRocketForce.swift tests/OriginalWindowsRocketForceSmoke.swift -o "$tmp/original-rocket-force"
"$tmp/original-rocket-force"

swiftc ios/CMOriginalWindowsBlowtorchHeat.swift tests/OriginalWindowsBlowtorchHeatSmoke.swift -o "$tmp/native-blowtorch"
"$tmp/native-blowtorch"
swiftc ios/CMOriginalRocketStageMachine.swift tests/OriginalRocketStageMachineSmoke.swift -o "$tmp/rocket-stage"
"$tmp/rocket-stage"
# Authentic mobile candle Heat UCM on moving original SceneKit bodies.
# Separate from Win32 native dynamic-candle region/effect proofs.
swiftc ios/CMOriginalRocketSceneHeatSources.swift tests/OriginalRocketSceneHeatSourcesSmoke.swift -o "$tmp/rocket-moving-candles"
"$tmp/rocket-moving-candles"
swiftc ios/CMOriginalWindowsDynamicCandleTilt.swift tests/OriginalWindowsDynamicCandleTiltSmoke.swift -o "$tmp/rocket-candle-tilt"
"$tmp/rocket-candle-tilt"
swiftc ios/CMOriginalRocketAnchorTelemetry.swift tests/OriginalRocketAnchorTelemetrySmoke.swift -o "$tmp/rocket-anchors"
"$tmp/rocket-anchors"
# Continuous original rocket force applied only to the exact native
# rocket child on measured flying/Engine/+0xFC evidence.
swiftc ios/CMOriginalWindowsRocketForce.swift ios/CMOriginalRocketForceDelivery.swift tests/OriginalRocketForceDeliverySmoke.swift -o "$tmp/rocket-delivery"
"$tmp/rocket-delivery"
swiftc ios/CMOriginalWindowsRocketVelocity.swift tests/OriginalWindowsRocketVelocitySmoke.swift -o "$tmp/original-rocket-velocity"
"$tmp/original-rocket-velocity"
# Native Win32 0x42FE12..0x42FFB1: named original UCM label -> selector.
# This is the missing source/receiver identity bridge (Heat -> type 3).
swiftc ios/CMOriginalWindowsNamedRegionRegistry.swift tests/OriginalWindowsNamedRegionRegistrySmoke.swift -o "$tmp/native-marker-registry"
"$tmp/native-marker-registry"
# Genuine lit original candle -> real UCM rocket Heat marker XY.
# This cannot trigger Win32 native selector-3 ignition by itself.
swiftc ios/CMOriginalWindowsNamedRegionRegistry.swift ios/CMOriginalRocketCandleHeatPair.swift tests/OriginalRocketCandleHeatPairSmoke.swift -o "$tmp/candle-rocket-heat"
"$tmp/candle-rocket-heat"
# Owner-original candle cone constructor: 17 degrees / near 0.2 /
# far +0.8; derived x86 0x431E80, NOT a guessed proximity radius.
swiftc ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsCandleHeatFactory.swift tests/OriginalWindowsCandleHeatFactorySmoke.swift -o "$tmp/original-candle-cone"
"$tmp/original-candle-cone"
# Win32 source candle's +0x20 cone must be kept distinct from the
# rocket receiver record +0x24; neither is a UCM Heat proximity check.
swiftc ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsRegionSelector.swift ios/CMOriginalWindowsRocketTimer.swift ios/CMOriginalWindowsCandleHeatFactory.swift ios/CMOriginalWindowsRocketNativeHeat.swift tests/OriginalWindowsRocketNativeHeatSmoke.swift -o "$tmp/native-rocket-heat"
"$tmp/native-rocket-heat"
# Original rocket state 2 + real engine countdown >3 seconds => state 3,
# never invent an ignition, physics explosion, or puzzle GOAL.
swiftc ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsRegionSelector.swift ios/CMOriginalWindowsRocketTimer.swift tests/OriginalWindowsRocketTimerSmoke.swift \
  -o "$tmp/original-rocket-fuse"
"$tmp/original-rocket-fuse"
python3 -m unittest discover -s tools -p 'test_audit_windows_rocket_exe.py'
# Native steam source pressure and >=1.0 whistle GOAL boundary.
swiftc ios/CMOriginalWindowsPowerScalar.swift ios/CMOriginalWindowsSteamWhistle.swift \
  tests/OriginalWindowsSteamWhistleSmoke.swift -o "$tmp/original-whistle-goal"
"$tmp/original-whistle-goal"
# Original 0x455241 snapshots +0xEC into +0xF0 and only a genuine
# source state difference dispatches native GOAL 0 (x86 0x434A76).
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsGoalCounter.swift tests/OriginalWindowsSourceClickGoalSmoke.swift \
  -o "$tmp/original-source-snapshot-goal"
"$tmp/original-source-snapshot-goal"
python3 -m unittest discover -s tools -p 'test_audit_windows_source_click_exe.py'
# Original Win32 candle/dynamic-candle/blowtorch click +0xEC and VALF state.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  tests/OriginalWindowsHeatSourceSwitchSmoke.swift -o "$tmp/original-heat-source-click"
"$tmp/original-heat-source-click"
# Original native pocketlamp click toggles +0xEC; never invent beam/GOAL.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  tests/OriginalWindowsPocketLampStateSmoke.swift -o "$tmp/original-pocketlamp-click"
"$tmp/original-pocketlamp-click"
# Recovered original Win32 0x409650 angular/radial beam region.
swiftc ios/CMOriginalWindowsBeamRegion.swift tests/OriginalWindowsBeamRegionSmoke.swift \
  -o "$tmp/original-win32-beam"
"$tmp/original-win32-beam"
swiftc ios/CMOriginalWindowsBeamRegion.swift ios/CMOriginalWindowsOpticalSample.swift \
  ios/CMOriginalOpticalSightline.swift ios/CMOriginalWindowsSolarSignal.swift \
  tests/OriginalWindowsOpticalSampleSmoke.swift -o "$tmp/original-win32-optical-solar"
"$tmp/original-win32-optical-solar"
# Actual UCM mesh-to-mesh path geometry and intervening original blockers.
swiftc ios/CMOriginalOpticalSightline.swift tests/OriginalOpticalSightlineSmoke.swift \
  -o "$tmp/original-optical-geometry"
"$tmp/original-optical-geometry"
# Real SceneKit switch-lever collision maps only original CML object IDs.
# The Win32 physics components +0xEC/+0xC8 are NOT synthesized from a hit.
swiftc ios/CMOriginalSwitchContactMapper.swift tests/OriginalSwitchContactSmoke.swift \
  -o "$tmp/original-switch-lever-hits"
"$tmp/original-switch-lever-hits"
# Recovered Win32 switch contact pair +0xEC/+0xC8 ±1 gate.
swiftc ios/CMOriginalWindowsSwitchContactGate.swift tests/OriginalWindowsSwitchContactGateSmoke.swift \
  -o "$tmp/original-win32-switch-contacts"
"$tmp/original-win32-switch-contacts"
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsSwitchContactGate.swift ios/CMOriginalWindowsSolarSignal.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsPowerScalar.swift \
  ios/CMOriginalWindowsPowerDisrupter.swift tests/OriginalWindowsSwitchCircuitSmoke.swift \
  -o "$tmp/original-switch-circuit"
"$tmp/original-switch-circuit"
python3 -m unittest discover -s tools -p 'test_*.py'
echo "Portable checks passed. iOS simulator build still requires Xcode/macOS."
