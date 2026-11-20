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
python3 -m unittest discover -s tools -p 'test_*.py'
echo "Portable checks passed. iOS simulator build still requires Xcode/macOS."
