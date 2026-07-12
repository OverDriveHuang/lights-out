## LightsOut 2.0.0

This release turns the restore-only safety fork into a session-aware display layout switcher.

### Highlights

- `Control + Command + P` cycles through Show All, Hide External, and Custom Layout.
- The selected mode is applied one second after all shortcut keys are released, so cycling does not flash the displays.
- The panel opens at the top-right of the screen containing the pointer.
- Custom Layout remembers physical displays saved as Off and supports removing unavailable saved targets.
- Sleep, wake, lid, and hot-plug events are coalesced before the current layout is reconciled.
- Safety Restore and last-physical-display guards reduce black-screen risk.
- The menu is organized as Display Layout → Displays → build footer.

### Install

Download `LightsOut-v2.0.0-macOS-arm64.zip`, unzip it, and open `LightsOut.app`. The app is ad-hoc signed but not notarized, so macOS may require Control-click → Open the first time.

### Verification

- App source commit embedded in the release build: `b9126da`
- 44 pure safety/policy checks passed in Debug, Release, and Address Sanitizer builds.
- Xcode Debug and optimized Release builds passed.
- Xcode Analyze passed.
- The uploaded ZIP was extracted and its app signature and embedded commit were reverified.
- ZIP SHA-256: `0665551b070a0a4fb0f26a513f6cfc36aad0fb9d1eb8854dd570a722fc31ff6b`

Tested on macOS Tahoe 26 with Apple silicon. Display enable/disable uses private macOS services and may be affected by future macOS releases.
