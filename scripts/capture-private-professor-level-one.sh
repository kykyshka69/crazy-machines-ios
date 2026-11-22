#!/usr/bin/env bash
# REAL original Professor level 1, never a synthetic CI preview.
# Usage: bash scripts/capture-private-professor-level-one.sh /private/Original_102Levels.cmassets
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /private/your-own-CrazyMachines_Original_102Levels.cmassets" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "An actual iPhone Simulator capture requires macOS with Xcode." >&2
  exit 2
fi
for command in xcodegen xcodebuild xcrun python3; do
  command -v "$command" >/dev/null || { echo "Missing $command" >&2; exit 2; }
done

repo="$(cd "$(dirname "$0")/.." && pwd)"
original="$1"
[[ -f "$original" ]] || { echo "Original user-owned asset pack is missing" >&2; exit 2; }
original="$(cd "$(dirname "$original")" && pwd)/$(basename "$original")"

private_dir="$repo/ios"
pack="$private_dir/CrazyMachines_Original_102Levels.cmassets"
# Never overwrite a different user-owned resource pack in the local checkout.
created_private_pack=0
if [[ -e "$pack" ]]; then
  cmp -s "$original" "$pack" || {
    echo "Different private asset pack already exists at $pack" >&2
    exit 2
  }
else
  cp "$original" "$pack"
  created_private_pack=1
fi
# The source repo must not retain a copied proprietary game pack after the
# local build. Never delete a private pack that was already present.
cleanup_private_pack() {
  if [[ "$created_private_pack" == "1" ]]; then
    rm -f "$pack"
  fi
}
trap cleanup_private_pack EXIT

output="$(printenv CM_PRIVATE_CAPTURE_OUTPUT 2>/dev/null || mktemp -d -t cm-private-original)"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
[[ ! -e "$output/PrivateOriginalLevel.xcresult" ]] || {
  echo "Refusing to overwrite an earlier private .xcresult" >&2; exit 2;
}

cd "$repo"
xcodegen generate --spec project.yml

# Use the same bounded boot routine as GitHub CI. The helper honors
# CM_SIMULATOR_UDID when explicitly supplied and refuses mismatched devices.
device_id="$(python3 "$repo/tools/boot_iphone_simulator_ci.py")"
test -n "$device_id"

# Only the opt-in private test is allowed; public CI must never bundle
# user-owned original PC media or upload resulting screens/artwork.
# TEST_RUNNER_ prefix allows test process environment injection on Xcode.
TEST_RUNNER_CM_PRIVATE_ORIGINAL_PACK_TEST=1 CM_PRIVATE_ORIGINAL_PACK_TEST=1 \
xcodebuild -project CrazyMachinesIOS.xcodeproj \
  -scheme CrazyMachinesIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$output/DerivedData" \
  -resultBundlePath "$output/PrivateOriginalLevel.xcresult" \
  -only-testing:CrazyMachinesUITests/CrazyMachinesLaunchUITests/testPrivateOriginalLevelOneWhenOptedIn \
  CODE_SIGNING_ALLOWED=NO test > "$output/xcodebuild.log" 2>&1 || {
    echo "Xcode did not pass the real original first-level test. See $output/xcodebuild.log" >&2
    exit 1
  }

xcrun xcresulttool get test-results summary \
  --path "$output/PrivateOriginalLevel.xcresult" > "$output/test-summary.json"
mkdir -p "$output/attachments"
xcrun xcresulttool export attachments \
  --path "$output/PrivateOriginalLevel.xcresult" \
  --output-path "$output/attachments"
python3 tools/select_first_level_screenshot.py \
  --attachments-dir "$output/attachments" \
  --summary "$output/test-summary.json" \
  --output "$output/REAL-original-professor-level-001.png"

echo "Verified genuine original level-one XCTest screenshot:"
echo "$output/REAL-original-professor-level-001.png"
echo "Private test log: $output/xcodebuild.log"
echo "Private result: $output/PrivateOriginalLevel.xcresult"
