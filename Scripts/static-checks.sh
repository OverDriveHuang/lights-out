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

  echo
  echo "== Optimized app Release build =="
  release_derived_data="$(mktemp -d "${TMPDIR:-/tmp}/lightsout-release-check.XXXXXX")"
  trap 'rm -rf "$release_derived_data"' EXIT
  xcodebuild -quiet \
    -project LightsOut.xcodeproj \
    -scheme LightsOut \
    -configuration Release \
    -derivedDataPath "$release_derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build
  rm -rf "$release_derived_data"
  trap - EXIT
else
  cat /tmp/lightsout-xcode-version.txt
  echo "Full Xcode is not selected; app build must wait."
fi

echo
echo "Static checks finished."
