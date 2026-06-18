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
  LightsOut/Services/DisplaySafetyPolicy.swift \
  LightsOut/Services/ReconfigurationDangerPolicy.swift

echo
echo "== Typecheck hotkey helper =="
swiftc -typecheck LightsOut/GlobalRestoreHotKey.swift

echo
echo "== Hotkey binding check =="
grep -q 'controlKey | cmdKey' LightsOut/GlobalRestoreHotKey.swift
! grep -q 'optionKey | cmdKey' LightsOut/GlobalRestoreHotKey.swift

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
