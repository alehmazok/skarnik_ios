#!/usr/bin/env bash
# Runs the offline-safe SkarnikUITests on one simulator (CI). Usage: ci/run-ui-tests.sh <udid> <label>
# Network, offline-download and no-network suites and the App Store screenshots run only on BrowserStack.
set -euo pipefail
udid="$1"
label="$2"
mkdir -p build
xcodebuild test \
  -project Skarnik.xcodeproj \
  -scheme SkarnikUITests \
  -destination "id=$udid" \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -resultBundlePath "build/UITestResults-$label.xcresult" \
  -skip-testing:SkarnikUITests/NetworkUITests \
  -skip-testing:SkarnikUITests/OfflineDictionaryUITests \
  -skip-testing:SkarnikUITests/NoNetworkUITests \
  -skip-testing:SkarnikUITests/AppStoreScreenshotsUITests \
  -retry-tests-on-failure \
  -test-iterations 3 \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "build/xcodebuild-ui-test-$label.log"
