#!/bin/sh
# Xcode Cloud runs this after cloning (it must live in ci_scripts/ next to Skarnik.xcodeproj).
# Writes the gitignored GoogleService-Info.plist from the workflow's secret environment variable
# GOOGLE_SERVICE_INFO_PLIST (base64), the same value as the GitHub secret. Setup: docs/xcode-cloud.md.
set -eu
if [ -z "${GOOGLE_SERVICE_INFO_PLIST:-}" ]; then
  echo "error: secret GOOGLE_SERVICE_INFO_PLIST is not set in the Xcode Cloud workflow environment"
  exit 1
fi
plist="$CI_PRIMARY_REPOSITORY_PATH/GoogleService-Info.plist"
echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > "$plist"
plutil -lint "$plist"
