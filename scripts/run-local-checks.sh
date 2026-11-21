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
python3 -m unittest discover -s tools -p 'test_*.py'
echo "Portable checks passed. iOS simulator build still requires Xcode/macOS."
