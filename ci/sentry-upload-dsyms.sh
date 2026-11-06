#!/usr/bin/env bash
# Uploads the archive's dSYMs to Sentry so crash reports get symbolicated stack traces (issue #28).
# Used by ci/testflight.sh (Bitrise) and .github/workflows/testflight.yml after an upload to TestFlight.
# Without SENTRY_AUTH_TOKEN it only warns: the dSYMs stay in the build artifacts.
#
# Env: SENTRY_AUTH_TOKEN (optional), SENTRY_PROJECT (optional, default skarnik_ios).
#   ci/sentry-upload-dsyms.sh [dsym-dir]   (default build/Skarnik.xcarchive/dSYMs)
set -euo pipefail
cd "$(dirname "$0")/.."

SENTRY_CLI_VERSION=3.8.2
dsyms="${1:-build/Skarnik.xcarchive/dSYMs}"

warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::warning::$1"; else echo "WARNING: $1"; fi
}

if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  warn "dSYMs not sent to Sentry: add the SENTRY_AUTH_TOKEN secret (README). Crashes of this build stay unsymbolicated."
  exit 0
fi
[[ -d "$dsyms" ]] || { echo "No dSYMs at $dsyms"; exit 1; }

export SENTRY_ORG=skarnik
export SENTRY_PROJECT="${SENTRY_PROJECT:-skarnik_ios}"
echo "Uploading dSYMs from $dsyms to Sentry $SENTRY_ORG/$SENTRY_PROJECT"
npx --yes "@sentry/cli@$SENTRY_CLI_VERSION" debug-files upload "$dsyms"
