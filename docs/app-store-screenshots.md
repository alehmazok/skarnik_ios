# App Store screenshots

Plain screens from a UI test, uploaded as they are: no captions, no frame, no marketing text (issue #60).
The listing stays strict, like the app; features that a screen cannot show go in the description.

## Capture

On a Mac with Xcode and the internet:

```bash
scripts/app-store-screenshots.sh                     # iPhone + iPad, light + dark
DEVICES=iphone APPEARANCES=dark SKIP_OFFLINE=1 scripts/app-store-screenshots.sh   # quick partial run
```

The script runs `AppStoreScreenshotsUITests` (skipped everywhere else) on the newest
"iPhone 17 Pro Max" and "iPad Pro 13-inch" simulators. It fixes the status bar at 9:41 with full
signal and battery (12-hour clock, not charging), switches the simulator to a Russian software keyboard, and turns off
"Connect Hardware Keyboard" in Simulator so the keyboard shows. PNGs land in
`screenshots/appstore/<iphone|ipad>/<light|dark>/` (gitignored):

| File | Screen |
|------|--------|
| `01-search` | Search with the і / ў / ʼ key row and the keyboard (on iOS 26 the field is at the bottom, in the search tab) |
| `02-article` | Long ТСБМ article («мова») with colours |
| `03-stress` | Stress table (націск) |
| `04-offline` | Settings with the ТСБМ dictionary downloaded |
| `05-history` | History (its own Гісторыя tab on iOS 26) |
| `06-bookmarks` | Bookmarks |

The words are constants at the top of the test. The Home Screen widget shot is not automated:
add the widget on the simulator by hand and take it with `xcrun simctl io booted screenshot`.

## Sizes

| Set | Simulator | Pixels | Covers |
|-----|-----------|--------|--------|
| iPhone 6.9" | iPhone 17 Pro Max | 1320 × 2868 | all smaller iPhones (App Store scales down) |
| iPad 13" | iPad Pro 13-inch | 2064 × 2752 | all smaller iPads, and the Mac listing ("Designed for iPad") |

## Upload

Light set in order 01–06, then the widget shot, then the dark `02-article` last to show dark mode.
The first three appear in search results, so search, article and stress go first.
Never show a third-party keyboard or app.
