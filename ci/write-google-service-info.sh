#!/usr/bin/env bash
# Writes GoogleService-Info.plist (gitignored) from the base64 secret GOOGLE_SERVICE_INFO_PLIST.
# With ALLOW_PLACEHOLDER_PLIST=1 and no secret (Bitrise pull request builds get no secrets), it copies
# ci/GoogleService-Info.placeholder.plist instead, which is enough to build and run the tests.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${GOOGLE_SERVICE_INFO_PLIST:-}" ]]; then
  if [[ "${ALLOW_PLACEHOLDER_PLIST:-}" == "1" ]]; then
    echo "GOOGLE_SERVICE_INFO_PLIST is not set: using the placeholder Firebase config (test builds only)"
    cp ci/GoogleService-Info.placeholder.plist GoogleService-Info.plist
    exit 0
  fi
  echo "::error::Secret GOOGLE_SERVICE_INFO_PLIST is not set"
  exit 1
fi
echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > GoogleService-Info.plist
plutil -lint GoogleService-Info.plist
