# LightsOut

LightsOut is a free macOS menu bar utility for switching display layouts and hiding individual displays in software. It is designed for Mac setups where the preferred display arrangement should survive sleep, wake, lid changes, and external-display reconnects without risking a fully black desktop.

> This is a safety-focused fork of the original LightsOut project. It has been tested on macOS Tahoe 26 with Apple silicon. Other macOS versions may work but have not been verified.

## Features

- Three display-layout modes:
  - **Show All Displays**
  - **Hide External Displays** (built-in display only when available)
  - **Custom Layout** (choose any non-empty subset of physical displays)
- `Control + Command + P` cycles through the three modes.
  - Repeated presses only preview the selection.
  - The final selection is applied one second after all shortcut keys are released, preventing displays from flashing while cycling.
- The layout panel opens near the top-right corner of the screen containing the pointer.
- Custom Layout remembers physical displays configured as Off using stable display identities.
- Missing saved-Off displays appear as removable `Unavailable` entries.
- Sleep, wake, lid, and hot-plug changes are coalesced before the selected layout is reconciled.
- Protects against hiding the last confirmed physical display.
- Safety Restore brings back a real display when the current topology would otherwise leave no visible screen.
- All displays are restored when the app exits.
- Optional launch at login.

## Install

1. Download the latest ZIP from [GitHub Releases](https://github.com/OverDriveHuang/lights-out/releases/latest).
2. Unzip `LightsOut.app` and move it to `/Applications` if desired.
3. Open the app. Because the release is ad-hoc signed rather than notarized, macOS may require **Control-click → Open** the first time.

## Usage

Open the menu bar panel and choose a layout at the top:

- **Show All Displays** restores every currently available real display.
- **Hide External Displays** keeps the built-in display visible. If the built-in display cannot currently be used, LightsOut preserves a safe external fallback instead of blacking out the Mac.
- **Custom Layout** enables the per-display power controls shown below the layout section. At least one real display must remain targeted On.

The footer shows the short Git commit used for the build. A `+ local changes` suffix means the app was built from a working tree containing uncommitted changes.

## Safety and limitations

- Display enable/disable uses private macOS display services and may be affected by future macOS updates.
- Virtual/headless displays are excluded from Custom targets and cannot protect the last physical display.
- LightsOut does not manage display arrangement, mirroring, resolution, refresh rate, HDR, brightness, or DDC power state.
- The selected mode is kept for the current app session. Custom Off choices persist, but quitting and reopening the app starts from Show All Displays.
- Keep a recovery path available when testing display-management software remotely.

## Build and checks

Requirements:

- Xcode 26 or a compatible recent Xcode
- Swift 6 toolchain

Run the pure safety and policy checks:

```sh
./Scripts/static-checks.sh
```

Create a locally signed test app with immutable date-time naming and verified build metadata:

```sh
./Scripts/build-test-app.sh
```

## Credits

Forked from [LightsOut](https://github.com/AlonX2/LightsOut) by AlonX2, with additional safety and display-layout work based on the fork maintained by [delie](https://github.com/delie/lights-out).

Licensed under the MIT License.
