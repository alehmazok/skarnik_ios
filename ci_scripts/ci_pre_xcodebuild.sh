#!/bin/sh
# Xcode Cloud runs this before each xcodebuild action. For the archive it writes the Sentry DSN from the
# workflow's secret environment variable SENTRY_DSN into the app's Info.plist (SKSentryDSN), which turns
# crash reporting on in that build (issue #28). Xcode Cloud passes no custom build settings to xcodebuild,
# so the project's $(SENTRY_DSN) placeholder is replaced here instead. Setup: README → Crash reporting.
set -eu
[ "${CI_XCODEBUILD_ACTION:-}" = "archive" ] || exit 0
if [ -z "${SENTRY_DSN:-}" ]; then
  echo "warning: SENTRY_DSN is not set in the Xcode Cloud workflow environment: this build reports no crashes."
  exit 0
fi
/usr/libexec/PlistBuddy -c "Set :SKSentryDSN $SENTRY_DSN" "$CI_PRIMARY_REPOSITORY_PATH/Skarnik/Info.plist"
echo "Sentry DSN written to Skarnik/Info.plist"
