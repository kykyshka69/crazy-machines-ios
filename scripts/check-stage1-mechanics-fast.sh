#!/usr/bin/env bash
# Fast Stage-1 native-mechanics regression: NO Xcode, app bundle or simulator.
# Use between batches of changes. Run full CI once when a related feature
# group is ready, not on every small implementation commit.
set -euo pipefail
cd "$(dirname "$0")/.."
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
# Native Win32 belt-flag GOAL gate from actual level-34 telescope states.
swiftc ios/CMOriginalWindowsBeltFlag.swift tests/OriginalWindowsBeltFlagSmoke.swift -o "$tmp/original-flag"
"$tmp/original-flag"

# Actual original object GOAL resolver: run BOTH mechanical native predicates
# alongside original electrical and steam GOAL without building the iOS app.
swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalWindowsPowerScalar.swift ios/CMOriginalWindowsSolarSignal.swift \
  ios/CMOriginalWindowsSteamWhistle.swift ios/CMOriginalWindowsBeltFlag.swift \
  ios/CMOriginalWindowsFlower.swift ios/CMOriginalWindowsElectricalGoals.swift \
  tests/OriginalWindowsElectricalGoalsSmoke.swift -o "$tmp/original-goal-dispatch"
"$tmp/original-goal-dispatch"
printf '%s\n' "All focused Stage-1 native-mechanics and goal-dispatch checks passed; iOS app NOT built."
