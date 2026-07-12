#!/bin/zsh

set -euo pipefail

source_root="$(cd "$(dirname "$0")/.." && pwd)"
artifacts_root="$(cd "$source_root/../.." && pwd)"
build_started_epoch="$(date '+%s')"
timestamp="$(date '+%Y-%m-%d-%H%M%S')"
day="$(date '+%Y-%m-%d')"
output_dir="$artifacts_root/${day}_lightsout_display_layout_build"
app_name="LightsOut-display-layout-${timestamp}.app"
derived_data="$output_dir/DerivedData"
destination_app="$output_dir/$app_name"
trap 'rm -rf "$destination_app"' ERR

commit_id="$(git -C "$source_root" rev-parse --short=7 HEAD)"
commit_label="$commit_id"
if ! git -C "$source_root" diff --quiet \
    || ! git -C "$source_root" diff --cached --quiet \
    || test -n "$(git -C "$source_root" ls-files --others --exclude-standard)"; then
    commit_label="$commit_id + local changes"
fi

mkdir -p "$output_dir"
xcodebuild -quiet \
    -project "$source_root/LightsOut.xcodeproj" \
    -scheme LightsOut \
    -configuration Debug \
    -derivedDataPath "$derived_data" \
    CODE_SIGN_IDENTITY=- \
    build

source_app="$derived_data/Build/Products/Debug/LightsOut.app"
test ! -e "$destination_app"
cp -R "$source_app" "$destination_app"
/usr/libexec/PlistBuddy -c "Add :GitCommit string $commit_label" "$destination_app/Contents/Info.plist"
codesign --force --deep --sign - "$destination_app"
codesign --verify --deep --strict "$destination_app"

embedded_commit="$(/usr/libexec/PlistBuddy -c 'Print :GitCommit' "$destination_app/Contents/Info.plist")"
test "$embedded_commit" = "$commit_label"

build_finished_epoch="$(date '+%s')"
birth_epoch="$(stat -f '%B' "$destination_app")"
modified_epoch="$(stat -f '%m' "$destination_app")"
test "$birth_epoch" -ge "$build_started_epoch"
test "$birth_epoch" -le "$((build_finished_epoch + 2))"
test "$modified_epoch" -ge "$build_started_epoch"
test "$modified_epoch" -le "$((build_finished_epoch + 2))"
birth_time="$(stat -f '%SB' -t '%Y-%m-%d %H:%M:%S %Z' "$destination_app")"
modified_time="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %Z' "$destination_app")"
trap - ERR

echo "$destination_app"
echo "Commit: $embedded_commit"
echo "Finder birth: $birth_time"
echo "Finder modified: $modified_time"
shasum -a 256 "$destination_app/Contents/MacOS/LightsOut"
