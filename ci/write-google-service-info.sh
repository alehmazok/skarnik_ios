#!/usr/bin/env bash
# Writes GoogleService-Info.plist (gitignored) from the base64 secret GOOGLE_SERVICE_INFO_PLIST.
set -euo pipefail
if [[ -z "${GOOGLE_SERVICE_INFO_PLIST:-}" ]]; then
  echo "::error::Secret GOOGLE_SERVICE_INFO_PLIST is not set"
  exit 1
fi
echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > GoogleService-Info.plist
plutil -lint GoogleService-Info.plist
