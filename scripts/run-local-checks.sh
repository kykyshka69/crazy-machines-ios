#!/usr/bin/env bash
# Run portable checks without GitHub-hosted runners (Linux or macOS).
set -euo pipefail
cd "$(dirname "$0")/.."
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
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsPowerScalar.swift \
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
  ios/CMOriginalWindowsPowerScalar.swift ios/CMOriginalWindowsElectricalGoals.swift \
  tests/OriginalWindowsElectricalGoalsSmoke.swift -o "$tmp/original-electrical-goals"
"$tmp/original-electrical-goals"
# Genuine generator is a mechanism-driven source, not an always-on battery.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsPowerScalar.swift \
  tests/OriginalGeneratorCircuitSmoke.swift -o "$tmp/original-generator"
"$tmp/original-generator"
python3 -m unittest discover -s tools -p 'test_*.py'
echo "Portable checks passed. iOS simulator build still requires Xcode/macOS."
