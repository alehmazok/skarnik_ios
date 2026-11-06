#!/bin/sh
# Xcode Cloud runs this after each xcodebuild action. After a successful archive it uploads the dSYMs to
# Sentry (issue #28) when the workflow has the secret environment variable SENTRY_AUTH_TOKEN; otherwise
# ci/sentry-upload-dsyms.sh only warns. Setup: README → Crash reporting.
set -eu
[ "${CI_XCODEBUILD_ACTION:-}" = "archive" ] || exit 0
[ "${CI_XCODEBUILD_EXIT_CODE:-0}" = "0" ] || exit 0
[ -n "${CI_ARCHIVE_PATH:-}" ] && [ -d "$CI_ARCHIVE_PATH/dSYMs" ] || { echo "No archive dSYMs to upload"; exit 0; }
# A failed upload must not stop the build from reaching TestFlight; the warning shows in the build log.
"$CI_PRIMARY_REPOSITORY_PATH/ci/sentry-upload-dsyms.sh" "$CI_ARCHIVE_PATH/dSYMs" \
  || echo "warning: dSYM upload to Sentry failed: crashes of this build stay unsymbolicated."
