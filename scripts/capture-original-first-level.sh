#!/usr/bin/env bash
# Run on a Mac with Xcode + XcodeGen and locally owned original PC game data.
# Does not upload copyrighted assets to GitHub or generate synthetic screenshots.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /private/level-001.json /private/original-ucm-folder" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "A real iPhone Simulator and xcodebuild require macOS/Xcode." >&2
  exit 2
fi
for executable in xcrun xcodebuild xcodegen python3; do
  command -v "$executable" >/dev/null || {
    echo "Missing required program: $executable" >&2; exit 2;
  }
done

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
scene_file="$1"
models_folder="$2"
# Keep proprietary game files and resulting screenshots outside the Git repo.
output="$(printenv CM_FIRST_LEVEL_OUTPUT 2>/dev/null || mktemp -d -t cm-original-level)"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
stage_dir="$output/private-original-assets"
derived_dir="$output/DerivedData"
result_bundle="$output/FirstOriginalLevel.xcresult"
screenshots="$output/screenshots"

python3 "$repo_root/tools/stage_original_first_level.py" \
  "$scene_file" "$models_folder" --output-dir "$stage_dir"

device_id="$(printenv CM_SIMULATOR_UDID 2>/dev/null || true)"
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group
           if d["name"].startswith("iPhone")]
booted = next((d for d in devices if d["state"] == "Booted"), None)
shut = next((d for d in devices if d["state"] == "Shutdown"), None)
print((booted or shut or {}).get("udid", ""))
')"
fi
if [[ -z "$device_id" ]]; then
  echo "No supported iPhone Simulator is available." >&2
  exit 2
fi
# Booting an already booted device is unnecessary and may error.
xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b

cd "$repo_root"
xcodegen generate --spec project.yml
xcodebuild -project CrazyMachinesIOS.xcodeproj \
  -scheme CrazyMachinesIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$derived_dir" CODE_SIGNING_ALLOWED=NO \
  build-for-testing >"$output/build.log" 2>&1

app="$derived_dir/Build/Products/Debug-iphonesimulator/CrazyMachinesIOS.app"
if [[ ! -d "$app" ]]; then
  echo "Build completed without the iPhone Simulator application; see build.log." >&2
  exit 1
fi
xcrun simctl install "$device_id" "$app"
app_data="$(xcrun simctl get_app_container "$device_id" org.crazymachines.port data)"
support="$app_data/Library/Application Support"
mkdir -p "$support/OriginalScenes" "$support/OriginalGame"
cp "$stage_dir/OriginalScenes/level-001.json" "$support/OriginalScenes/level-001.json"
cp -R "$stage_dir/OriginalGame/." "$support/OriginalGame/"

xctestrun="$(find "$derived_dir/Build/Products" -maxdepth 1 \
  -name '*.xctestrun' -type f -print -quit)"
if [[ -z "$xctestrun" ]]; then
  echo "Xcode did not generate an .xctestrun file; see build.log." >&2
  exit 1
fi
# Run ONLY the genuine level-one test. It skips on ordinary public CI,
# but here the staged scene must load and contain at least one UCM mesh.
xcodebuild test-without-building \
  -xctestrun "$xctestrun" \
  -destination "platform=iOS Simulator,id=$device_id" \
  -only-testing:CrazyMachinesUITests/CrazyMachinesLaunchUITests/testCaptureFirstRealLevel3DWhenSeeded \
  -resultBundlePath "$result_bundle" CODE_SIGNING_ALLOWED=NO \
  >"$output/ui-test.log" 2>&1 || {
    echo "First-level UI test failed; review $output/ui-test.log" >&2
    exit 1
  }

mkdir -p "$screenshots"
xcrun xcresulttool export attachments \
  --path "$result_bundle" --output-path "$screenshots"
first_png="$(find "$screenshots" -type f -iname '*.png' -size +0c -print -quit)"
if [[ -z "$first_png" ]]; then
  echo "No screenshot exported. Level may have been skipped or rendered blank." >&2
  exit 1
fi
cp "$first_png" "$output/original-level-001-iphone-simulator.png"
echo "Captured real original level 1 from an iPhone Simulator:"
echo "$output/original-level-001-iphone-simulator.png"
echo "Build log: $output/build.log"
echo "UI test log: $output/ui-test.log"
