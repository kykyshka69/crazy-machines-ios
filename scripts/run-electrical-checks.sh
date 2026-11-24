#!/usr/bin/env bash
# Run the real committed electrical model tests without Xcode or private assets.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

swiftc ios/CMOriginalSceneDocument.swift ios/CMOriginalGameplaySession.swift \
  ios/CMOriginalPowerCircuit.swift ios/CMOriginalWindowsSolarSignal.swift \
  ios/CMOriginalWindowsWindRegion.swift ios/CMOriginalWindowsSwitchContactGate.swift \
  ios/CMOriginalWindowsPowerDisrupter.swift ios/CMOriginalWindowsPowerScalar.swift \
  tests/OriginalPowerCircuitSmoke.swift -o "$tmp/original-power"
"$tmp/original-power"
