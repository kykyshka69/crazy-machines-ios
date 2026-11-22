#!/usr/bin/env bash
# Local-only iPhone Simulator sweep of ALL 102 authentic PC Professor levels.
# This tests navigation and SceneKit mesh loading, NOT 102 puzzle solutions.
#
# Usage:
#   bash scripts/verify-private-all-102-levels.sh \
#     /private/CrazyMachines_Original_102Levels.cmassets
#
# No copyrighted game resources are ever uploaded to public GitHub CI.
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "Usage: $0 /private/your-owned-102-level.cmassets" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Authentic iPhone Simulator runtime testing requires macOS and Xcode." >&2
  exit 2
fi
for cmd in xcodegen xcodebuild xcrun python3; do
  command -v "$cmd" >/dev/null || {
    echo "Missing required command: $cmd" >&2
    exit 2
  }
done

repo="$(cd "$(dirname "$0")/.." && pwd)"
original="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
private="$repo/ios/CrazyMachines_Original_102Levels.cmassets"
created=0
if [[ -e "$private" ]]; then
  cmp -s "$original" "$private" || {
    echo "Different original pack already exists at $private; refusing overwrite." >&2
    exit 2
  }
else
  cp "$original" "$private"
  created=1
fi
cleanup() {
  # A pre-existing owner-owned pack must NEVER be deleted.
  if [[ "$created" == 1 ]]; then rm -f "$private"; fi
}
trap cleanup EXIT

out="$(printenv CM_PRIVATE_102_OUTPUT 2>/dev/null || mktemp -d -t cm-original-102)"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
result="$out/PrivateOriginal102.xcresult"
if [[ -e "$result" ]]; then
  echo "Refusing to overwrite prior private test results: $result" >&2
  exit 2
fi

cd "$repo"
xcodegen generate --spec project.yml

# Hosted CI's explicit simctl bootstatus often stalled; do not preboot.
# Xcode will own simulator startup, matching the now-verified public flow.
export CM_SIMULATOR_PREFERRED_NAME="iPhone 17 Pro"
device_id="$(python3 tools/boot_iphone_simulator_ci.py --select-only)"
test -n "$device_id"
echo "Private 102-level verification on iPhone Simulator: $device_id"

# TEST_RUNNER_* delivers these flags to the XCTest target process. The
# optional test is skipped in public CI, where the real pack is absent.
set +e
TEST_RUNNER_CM_PRIVATE_ORIGINAL_PACK_TEST=1 \
TEST_RUNNER_CM_PRIVATE_ALL_LEVELS_TEST=1 \
CM_PRIVATE_ORIGINAL_PACK_TEST=1 \
CM_PRIVATE_ALL_LEVELS_TEST=1 \
xcodebuild -project CrazyMachinesIOS.xcodeproj \
  -scheme CrazyMachinesIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -destination-timeout 180 \
  -parallel-testing-enabled NO \
  -derivedDataPath "$out/DerivedData" \
  -resultBundlePath "$result" \
  -only-testing:CrazyMachinesUITests/CrazyMachinesLaunchUITests/testPrivateAll102OriginalLevelsWhenOptedIn \
  CODE_SIGNING_ALLOWED=NO test > "$out/xcodebuild.log" 2>&1
status=$?
set -e

if [[ -d "$result" ]]; then
  xcrun xcresulttool get test-results summary \
    --path "$result" > "$out/test-summary.json" || true
  mkdir -p "$out/attachments"
  xcrun xcresulttool export attachments \
    --path "$result" \
    --output-path "$out/attachments" || true
  # A strict export prevents accidentally treating synthetic CI captures as
  # evidence for the owner's private original Professor levels.
  if ! python3 tools/export_private_102_report.py \
      --attachments-dir "$out/attachments" \
      --output "$out/PRIVATE-original-102-levels.csv"; then
    if [[ "$status" -eq 0 ]]; then
      echo "XCTest passed but the private 102-level CSV is missing." >&2
      exit 1
    fi
  fi
fi

echo "Private batch evidence: $out"
echo "102-level metadata CSV attachment: PRIVATE-102-original-levels-SceneKit.csv"
echo "Xcode run log: $out/xcodebuild.log"
echo "xcresult bundle: $result"
echo "This test checks original scene loading, not solved Windows puzzles."
if [[ "$status" -ne 0 ]]; then
  echo "One or more authentic levels did not load; examine xcresult attachments." >&2
  exit "$status"
fi
echo "Original 102-level SceneKit navigation and model checks: PASSED"
