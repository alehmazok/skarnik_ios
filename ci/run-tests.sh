#!/usr/bin/env bash
# Runs one test scheme on the newest available iPhone simulator, unsigned.
#
#   ci/run-tests.sh <scheme> <result-name>
#
# e.g. ci/run-tests.sh Skarnik TestResults  → build/TestResults.xcresult + build/xcodebuild-TestResults.log
# Used by bitrise.yml; Swift packages go to build/SourcePackages so CI can cache them.
set -euo pipefail
cd "$(dirname "$0")/.."

scheme="$1"
result="$2"

# Newest available iOS runtime, first iPhone on it. Version parts are read with scan, not split, so a
# runtime key with a trailing dash (e.g. "iOS-27-2-" before a suffix) does not yield an empty part.
udid=$(xcrun simctl list devices available -j | jq -r '
  .devices | to_entries
  | map(select(.key | test("iOS")))
  | sort_by(.key | capture("iOS-(?<v>[0-9-]+)").v | [scan("[0-9]+") | tonumber])
  | last | .value | map(select(.name | startswith("iPhone"))) | first | .udid')
[[ -n "$udid" && "$udid" != "null" ]] || { echo "No iPhone simulator found"; exit 1; }
echo "Using simulator $udid"

mkdir -p build
rm -rf "build/$result.xcresult"
set -o pipefail
xcodebuild test \
  -project Skarnik.xcodeproj \
  -scheme "$scheme" \
  -destination "id=$udid" \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -resultBundlePath "build/$result.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  | tee "build/xcodebuild-$result.log"
