#!/usr/bin/env bash
# Fast Stage-1 native-mechanics regression: NO Xcode, app bundle or simulator.
# Use between batches of changes. Run full CI once when a related feature
# group is ready, not on every small implementation commit.
set -euo pipefail
cd "$(dirname "$0")/.."
# Fail fast if a Git tree update accidentally dropped a referenced
# original physics source, before spending minutes compiling Xcode/Swift.
python3 tools/check_stage1_source_references.py
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc ios/CMOriginalGeneratorRotorObservation.swift     tests/OriginalGeneratorRotorObservationSmoke.swift -o "$tmp/generator"
"$tmp/generator"
swiftc ios/CMOriginalWindowsMechanicalTransfer.swift     ios/CMOriginalGearContactTransfer.swift     tests/OriginalGearContactTransferSmoke.swift -o "$tmp/gears"
"$tmp/gears"
swiftc ios/CMOriginalWindowsMechanicalTransfer.swift     tests/OriginalWindowsMechanicalTransferSmoke.swift -o "$tmp/native-motion"
"$tmp/native-motion"
# Native GOAL checks must complete before reporting this batch successful.

# Native flower GOAL and illumination-dependent +0x130 progress for five real originals.
swiftc ios/CMOriginalWindowsFlower.swift tests/OriginalWindowsFlowerSmoke.swift -o "$tmp/original-flower"
"$tmp/original-flower"
# Preserve original named Heat/Engine/Explode/Direction UCM frames.
swiftc ios/CMOriginalUCMNamedAnchors.swift tests/OriginalUCMNamedAnchorsSmoke.swift -o "$tmp/ucm-anchors"
"$tmp/ucm-anchors"

# Native Win32 belt-flag GOAL gate from actual level-34 telescope states.
swiftc ios/CMOriginalWindowsWindRegion.swift tests/OriginalWindowsWindRegionSmoke.swift -o "$tmp/original-wind-region"
"$tmp/original-wind-region"
swiftc ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsBeltFlag.swift tests/OriginalWindowsBeltFlagSmoke.swift -o "$tmp/original-flag"
"$tmp/original-flag"

# Genuine Win32 selector 3/ordinal 0, skipped unlinked region entries.
swiftc ios/CMOriginalWindowsRegionSelector.swift tests/OriginalWindowsRegionSelectorSmoke.swift -o "$tmp/native-regions"
"$tmp/native-regions"

# Original x86 0x44F1DD..0x486400 physics force at body COM:
# exact live +0xFC scalar and native Direction, NOT invented power.
swiftc ios/CMOriginalWindowsRocketForce.swift tests/OriginalWindowsRocketForceSmoke.swift -o "$tmp/original-rocket-force"
"$tmp/original-rocket-force"

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
# Both ORIGINAL rocket phases 1→2 and 2→3 use separate engine
# clocks and strict >3 seconds. No fabricated heat ignition or GOAL.
swiftc ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsRegionSelector.swift ios/CMOriginalWindowsRocketTimer.swift tests/OriginalWindowsRocketTimerSmoke.swift -o "$tmp/original-rocket"
"$tmp/original-rocket"

# Actual original object GOAL resolver: run BOTH mechanical native predicates
# alongside original electrical and steam GOAL without building the iOS app.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsPowerScalar.swift ios/CMOriginalWindowsSolarSignal.swift \
  ios/CMOriginalWindowsSteamWhistle.swift ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsBeltFlag.swift \
  ios/CMOriginalWindowsFlower.swift ios/CMOriginalWindowsRegionSelector.swift ios/CMOriginalWindowsRocketTimer.swift ios/CMOriginalWindowsElectricalGoals.swift \
  tests/OriginalWindowsElectricalGoalsSmoke.swift -o "$tmp/original-goal-dispatch"
"$tmp/original-goal-dispatch"
printf '%s\n' "All focused Stage-1 native-mechanics and goal-dispatch checks passed; iOS app NOT built."
