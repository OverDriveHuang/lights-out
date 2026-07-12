#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Swift toolchain =="
swift --version

echo
echo "== Pure safety checks =="
swift run LightsOutSafetyCoreChecks

echo
echo "== Typecheck pure safety modules =="
swiftc -typecheck \
  LightsOut/Services/RestoreCandidateAggregator.swift \
  LightsOut/Services/DisplayLayoutModels.swift \
  LightsOut/Services/PersistentDisplayIdentity.swift \
  LightsOut/Services/DisplayLayoutPolicy.swift \
  LightsOut/Services/DisplaySafetyPolicy.swift \
  LightsOut/Services/ReconfigurationDangerPolicy.swift

echo
echo "== Typecheck hotkey helper =="
swiftc -typecheck LightsOut/GlobalDisplayLayoutHotKey.swift

echo
echo "== Hotkey binding check =="
rg -q 'controlKey \| cmdKey' LightsOut/GlobalDisplayLayoutHotKey.swift
! rg -q 'optionKey \| cmdKey' LightsOut/GlobalDisplayLayoutHotKey.swift
rg -q 'kEventHotKeyReleased' LightsOut/GlobalDisplayLayoutHotKey.swift
rg -q 'flagsState' LightsOut/GlobalDisplayLayoutHotKey.swift
rg -q 'keyState' LightsOut/GlobalDisplayLayoutHotKey.swift
! rg -q '\(1\.\.\.10\)' LightsOut/DisplaysViewModel.swift

echo
echo "== Xcode availability =="
if xcodebuild -version >/tmp/lightsout-xcode-version.txt 2>&1; then
  cat /tmp/lightsout-xcode-version.txt
else
  cat /tmp/lightsout-xcode-version.txt
  echo "Full Xcode is not selected; app build must wait."
fi

echo
echo "Static checks finished."
