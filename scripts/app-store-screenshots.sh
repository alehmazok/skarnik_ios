#!/usr/bin/env bash
# Captures the raw App Store screenshots (issue #60) on a Mac with Xcode and the internet.
#
#   scripts/app-store-screenshots.sh
#
# Runs AppStoreScreenshotsUITests on a 6.9" and a 6.3" iPhone and a 13" iPad simulator, in light and dark mode,
# with a clean status bar (9:41, full signal and battery, not charging) and the software keyboard shown.
# Output: screenshots/appstore/<iphone|iphone-medium|ipad>/<light|dark>/NN-name.png (gitignored), at the
# exact App Store Connect sizes (1320×2868, 1206×2622 and 2064×2752). Upload them as they are: no captions, no frame.
#
# Env (all optional):
#   IPHONE_SIM         simulator name, default "iPhone 17 Pro Max" (large display, 6.9")
#   IPHONE_MEDIUM_SIM  simulator name, default "iPhone 17 Pro" (medium display, 6.3")
#   IPAD_SIM           simulator name prefix, default "iPad Pro 13-inch"
#   DEVICES            "iphone iphone-medium ipad" (default), or some of them
#   APPEARANCES  "light dark" (default), or just one of them
#   SKIP_OFFLINE=1  skip the offline-download shot (the ТСБМ download takes a few minutes per run)
set -euo pipefail

cd "$(dirname "$0")/.."

iphone_sim="${IPHONE_SIM:-iPhone 17 Pro Max}"
iphone_medium_sim="${IPHONE_MEDIUM_SIM:-iPhone 17 Pro}"
ipad_sim="${IPAD_SIM:-iPad Pro 13-inch}"
devices="${DEVICES:-iphone iphone-medium ipad}"
appearances="${APPEARANCES:-light dark}"
out_root="$PWD/screenshots/appstore"
build_dir="$PWD/build/screenshots"

# Newest available runtime: the simulator named exactly $1, else the first whose name starts with $1
# (so "iPhone 17 Pro" does not pick "iPhone 17 Pro Max", and "iPad Pro 13-inch" finds the M4 or M5).
find_sim() {
  xcrun simctl list devices available -j | jq -r --arg name "$1" '
    .devices | to_entries
    | map(select(.key | test("iOS")))
    | sort_by(.key | capture("iOS-(?<v>[0-9-]+)").v | split("-") | map(tonumber))
    | reverse | map(.value[]) as $sims
    | (($sims | map(select(.name == $name))) + ($sims | map(select(.name | startswith($name)))))
    | first | .udid // empty'
}

prepare_sim() { # <udid>
  local udid="$1"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # A runner left over from an earlier build can be launched instead of the fresh one: start clean.
  xcrun simctl uninstall "$udid" by.skarnik.SkarnikUITests.xctrunner 2>/dev/null || true
  xcrun simctl uninstall "$udid" by.mazokaleh.Skarnik 2>/dev/null || true
  # Cyrillic software keyboard: the search shot shows it under the і / ў / ʼ key row.
  xcrun simctl spawn "$udid" defaults write -g AppleKeyboards -array \
    "ru_RU@sw=Russian;hw=Automatic" "en_US@sw=QWERTY;hw=Automatic"
  xcrun simctl spawn "$udid" defaults write -g AppleKeyboardsExpanded -int 1
  # 12-hour clock: the status bar shows "9:41", not "09:41" as in 24-hour regions (en_BY).
  xcrun simctl spawn "$udid" defaults write -g AppleICUForce12HourTime -bool true
  # Keyboard and clock settings apply after a reboot of the simulator.
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName "" \
    --batteryState discharging --batteryLevel 100
}

# A connected hardware keyboard hides the software keyboard in every simulator.
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false

echo "Building for testing"
mkdir -p "$build_dir"
xcodebuild build-for-testing \
  -project Skarnik.xcodeproj \
  -scheme SkarnikUITests \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$build_dir" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
xctestrun=$(find "$build_dir/Build/Products" -maxdepth 1 -name '*.xctestrun' | head -1)

failed=0
for device in $devices; do
  case "$device" in
    iphone) name="$iphone_sim" ;;
    iphone-medium) name="$iphone_medium_sim" ;;
    ipad) name="$ipad_sim" ;;
    *) echo "Unknown device «$device» (use iphone, iphone-medium or ipad)"; exit 1 ;;
  esac
  udid=$(find_sim "$name")
  if [[ -z "$udid" ]]; then
    echo "No simulator named «$name». Create one in Xcode > Window > Devices and Simulators, or set IPHONE_SIM / IPHONE_MEDIUM_SIM / IPAD_SIM."
    exit 1
  fi
  echo "== $device: $name ($udid)"
  prepare_sim "$udid"

  for appearance in $appearances; do
    out="$out_root/$device/$appearance"
    rm -rf "$out" "$build_dir/$device-$appearance.xcresult"
    mkdir -p "$out"
    xcrun simctl ui "$udid" appearance "$appearance"
    echo "-- $appearance → $out"
    # TEST_RUNNER_<NAME> reaches the UI test process as <NAME>.
    if ! TEST_RUNNER_SKARNIK_SCREENSHOTS_DIR="$out" \
      TEST_RUNNER_SKARNIK_SCREENSHOTS_SKIP_OFFLINE="${SKIP_OFFLINE:-0}" \
      xcodebuild test-without-building \
        -xctestrun "$xctestrun" \
        -destination "id=$udid" \
        -only-testing:SkarnikUITests/AppStoreScreenshotsUITests \
        -resultBundlePath "$build_dir/$device-$appearance.xcresult" \
        -quiet; then
      echo "Some shots failed on $device/$appearance; see $build_dir/$device-$appearance.xcresult"
      failed=1
    fi
    ls "$out"
  done

  xcrun simctl status_bar "$udid" clear
  xcrun simctl ui "$udid" appearance light
done

echo "Screenshots in $out_root"
exit "$failed"
