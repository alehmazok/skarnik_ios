#!/usr/bin/env bash
# Builds Skarnik + the SkarnikUITests runner for real devices, unsigned (BrowserStack re-signs uploads),
# and packages build/Skarnik.ipa and build/SkarnikUITests.zip for scripts/browserstack-run.sh.
# Used by bitrise.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(pwd)

mkdir -p build
set -o pipefail
xcodebuild build-for-testing \
  -project Skarnik.xcodeproj \
  -scheme SkarnikUITests \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO \
  | tee build/xcodebuild-device.log

products=build/DerivedData/Build/Products/Debug-iphoneos
staging=$(mktemp -d)
mkdir -p "$staging/Payload"
cp -R "$products/Skarnik.app" "$staging/Payload/"
(cd "$staging" && zip -qry "$root/build/Skarnik.ipa" Payload)
(cd "$products" && zip -qry "$root/build/SkarnikUITests.zip" SkarnikUITests-Runner.app)
rm -rf "$staging"
ls -lh build/Skarnik.ipa build/SkarnikUITests.zip
