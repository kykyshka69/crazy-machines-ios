#!/usr/bin/env bash
# Build an independently signed Crazy Machines app for a physical iPhone.
# Copyrighted PC assets are imported on-device through Files after installation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM="${DEVELOPMENT_TEAM:-}"
BUNDLE="${CM_BUNDLE_ID:-org.crazymachines.port}"
OUTPUT="${CM_DEVICE_OUTPUT:-$ROOT/build/device}"
DEVICE="${CM_DEVICE_UDID:-}"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'A Mac with Xcode is required for native iPhoneOS builds.'
[[ -n "$TEAM" ]] || fail 'Set DEVELOPMENT_TEAM to your Apple development team ID (Xcode -> Settings -> Accounts).'
[[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || fail 'DEVELOPMENT_TEAM must be a 10-character Apple Team ID.'
[[ "$BUNDLE" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || fail 'CM_BUNDLE_ID must be a valid reverse-DNS bundle identifier.'
for tool in xcodebuild xcrun xcodegen python3; do
    command -v "$tool" >/dev/null 2>&1 || fail "Missing $tool. Install full Xcode and XcodeGen."
done
[[ -f "$ROOT/project.yml" ]] || fail "Missing project.yml in $ROOT"
[[ -d "$ROOT/ios" ]] || fail "Missing iOS Swift sources in $ROOT"
[[ ! -e "$ROOT/ios/CrazyMachines_Original_102Levels.cmassets" ]] || fail 'Private game data must not be added to iOS sources.'

mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
cd "$ROOT"
xcodegen generate --spec project.yml
xcodebuild -project CrazyMachinesIOS.xcodeproj \
    -scheme CrazyMachinesIOS -configuration Debug \
    -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "$OUTPUT/DerivedData" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" \
    build 2>&1 | tee "$OUTPUT/iphoneos-build.log"

APP="$OUTPUT/DerivedData/Build/Products/Debug-iphoneos/CrazyMachinesIOS.app"
[[ -d "$APP" ]] || fail 'Xcode returned without an iPhoneOS application.'
[[ ! -e "$APP/CrazyMachines_Original_102Levels.cmassets" ]] || fail 'Private game pack leaked into the app. Abort distribution.'
ACTUAL_BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
[[ "$ACTUAL_BUNDLE" == "$BUNDLE" ]] || fail "Unexpected built bundle ID: $ACTUAL_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP" || fail 'The app has no valid code signature.'

# This IPA is for local developer installation, not an App Store export.
mkdir -p "$OUTPUT/ipa-staging/Payload"
rm -rf "$OUTPUT/ipa-staging/Payload/CrazyMachinesIOS.app"
ditto "$APP" "$OUTPUT/ipa-staging/Payload/CrazyMachinesIOS.app"
(
    cd "$OUTPUT/ipa-staging"
    /usr/bin/zip -qry "$OUTPUT/CrazyMachinesIOS-development.ipa" Payload
)
rm -rf "$OUTPUT/ipa-staging"
printf 'Signed iPhone app: %s\nDeveloper IPA: %s\n' \
    "$APP" "$OUTPUT/CrazyMachinesIOS-development.ipa"

if [[ -n "$DEVICE" ]]; then
    xcrun devicectl device install app --device "$DEVICE" "$APP"
    xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE"
    printf 'Installed and launched on device %s\n' "$DEVICE"
else
    echo 'To install on a paired iPhone, rerun with CM_DEVICE_UDID set.'
fi
echo 'On iPhone: Game files -> Install original game pack (102 levels), choose your private .cmassets from Files.'