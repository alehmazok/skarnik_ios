#!/usr/bin/env bash
# Uploads an archive's dSYMs to Sentry so crash reports get symbolicated stack traces (issue #28).
# Used by .github/workflows/testflight.yml after a TestFlight upload.
# Without SENTRY_AUTH_TOKEN it only warns: the dSYMs stay in the build artifacts.
#
# Env: SENTRY_AUTH_TOKEN (optional), SENTRY_PROJECT (optional, default skarnik_ios).
#   ci/sentry-upload-dsyms.sh [dsym-dir]   (default build/Skarnik.xcarchive/dSYMs)
set -euo pipefail

SENTRY_CLI_VERSION=3.8.2
dsyms="${1:-build/Skarnik.xcarchive/dSYMs}"

warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::warning::$1"; else echo "warning: $1"; fi
}

if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  warn "dSYMs not sent to Sentry: add the SENTRY_AUTH_TOKEN secret (README). Crashes of this build stay unsymbolicated."
  exit 0
fi
[[ -d "$dsyms" ]] || { echo "No dSYMs at $dsyms"; exit 1; }

# The pinned macOS release binary, so the upload needs no Node on the runner.
cli_dir=$(mktemp -d)
trap 'rm -rf "$cli_dir"' EXIT
curl -fsSL --retry 3 -o "$cli_dir/sentry-cli" \
  "https://github.com/getsentry/sentry-cli/releases/download/$SENTRY_CLI_VERSION/sentry-cli-Darwin-universal"
chmod +x "$cli_dir/sentry-cli"

export SENTRY_ORG=skarnik
export SENTRY_PROJECT="${SENTRY_PROJECT:-skarnik_ios}"
echo "Uploading dSYMs from $dsyms to Sentry $SENTRY_ORG/$SENTRY_PROJECT (sentry-cli $SENTRY_CLI_VERSION)"
"$cli_dir/sentry-cli" debug-files upload "$dsyms"
