# App Store screenshots

Raw screens come from a UI test; captions and the frame are added in Figma (issue #60).

## Capture

On a Mac with Xcode and the internet:

```bash
scripts/app-store-screenshots.sh                     # iPhone + iPad, light + dark
DEVICES=iphone APPEARANCES=dark SKIP_OFFLINE=1 scripts/app-store-screenshots.sh   # quick partial run
```

The script runs `AppStoreScreenshotsUITests` (skipped everywhere else) on the newest
"iPhone 17 Pro Max" and "iPad Pro 13-inch" simulators. It fixes the status bar at 9:41 with full
signal and battery, switches the simulator to a Russian software keyboard, and turns off
"Connect Hardware Keyboard" in Simulator so the keyboard shows. PNGs land in
`screenshots/appstore/<iphone|ipad>/<light|dark>/` (gitignored):

| File | Screen |
|------|--------|
| `01-search` | Search with the і / ў / ʼ key row and the keyboard |
| `02-article` | Article with colours |
| `03-stress` | Stress table (націск) |
| `04-offline` | Settings with the ТСБМ dictionary downloaded |
| `05-fuzzy-search` | «слоунік» still finds «слоўнік» |
| `06-history` | History |
| `07-bookmarks` | Bookmarks |

The words are constants at the top of the test. The Home Screen widget shot is not automated:
add the widget on the simulator by hand and take it with `xcrun simctl io booted screenshot`.

## Sizes

| Set | Simulator | Pixels | Covers |
|-----|-----------|--------|--------|
| iPhone 6.9" | iPhone 17 Pro Max | 1320 × 2868 | all smaller iPhones (App Store scales down) |
| iPad 13" | iPad Pro 13-inch | 2064 × 2752 | all smaller iPads, and the Mac listing ("Designed for iPad") |

## Figma frame

Device-agnostic, no real bezel, so the shots do not date and also fit the Mac listing:
one frame per set at the pixel size above, light and dark variants. The screen is an image fill in a
rounded rectangle (about 55 px radius on iPhone, 40 px on iPad) with a soft shadow, a short Belarusian
caption above it, brand colour background (white + red `#E1251B`; dark `#0F0F10` + `#FF4438`).
Never show a third-party keyboard or app.
