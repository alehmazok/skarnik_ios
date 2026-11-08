#!/usr/bin/env bash
# Archives a Release build of the Skarnik scheme with automatic signing (used by testflight.yml).
#   ci/archive.sh <ios|mac> <archive-path>
# mac = Mac Catalyst. Both platforms are signed with the stored Apple Development identity;
# export re-signs with cloud-managed distribution signing.
# Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, TEAM_ID, BUILD_NUMBER, SENTRY_DSN (optional).
set -euo pipefail

platform="${1:?usage: archive.sh <ios|mac> <archive-path>}"
archive="${2:?usage: archive.sh <ios|mac> <archive-path>}"

case "$platform" in
  ios) destination='generic/platform=iOS' ;;
  mac) destination='generic/platform=macOS,variant=Mac Catalyst' ;;
  *) echo "::error::Unknown platform $platform (expected ios or mac)"; exit 1 ;;
esac

mkdir -p build
xcodebuild archive \
  -project Skarnik.xcodeproj \
  -scheme Skarnik \
  -configuration Release \
  -destination "$destination" \
  -archivePath "$archive" \
  -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="Apple Development" \
  PROVISIONING_PROFILE_SPECIFIER= \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  SENTRY_DSN="${SENTRY_DSN:-}" \
  | tee "build/xcodebuild-archive-$platform.log"
