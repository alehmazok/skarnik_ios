#!/usr/bin/env bash
# Uploads the device build to BrowserStack App Automate and runs the XCUITest suite on real devices.
#
#   ci/browserstack-run.sh <app.ipa> <test-suite.zip>
#
# Env: BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY (secrets), BROWSERSTACK_DEVICES (comma-separated,
# e.g. "iPhone 15-17,iPhone 13-15"), BUILD_TAG (optional label shown in the BrowserStack dashboard).
# Exits non-zero unless the BrowserStack build ends as "passed".
set -euo pipefail

ipa="$1"
suite="$2"
api="https://api-cloud.browserstack.com/app-automate/xcuitest/v2"
auth="$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

upload() { # <endpoint> <file> <json field>
  local response
  response=$(curl -sS --fail-with-body -u "$auth" -X POST "$api/$1" -F "file=@$2")
  jq -er ".$3" <<<"$response" || { echo "::error::Upload to $1 failed: $response"; exit 1; }
}

echo "Uploading $ipa"
app_url=$(upload app "$ipa" app_url)
echo "Uploading $suite"
suite_url=$(upload test-suite "$suite" test_suite_url)

devices=$(jq -cn --arg d "$BROWSERSTACK_DEVICES" '$d | split(",") | map(gsub("^ +| +$"; ""))')
payload=$(jq -n \
  --arg app "$app_url" --arg suite "$suite_url" --argjson devices "$devices" \
  --arg tag "${BUILD_TAG:-manual}" \
  '{app: $app, testSuite: $suite, devices: $devices, project: "Skarnik iOS", buildTag: $tag,
    deviceLogs: true, networkLogs: false}')

response=$(curl -sS --fail-with-body -u "$auth" -X POST "$api/build" \
  -H "Content-Type: application/json" -d "$payload")
build_id=$(jq -er '.build_id' <<<"$response") || { echo "::error::Could not start build: $response"; exit 1; }
dashboard="https://app-automate.browserstack.com/dashboard/v2/builds/$build_id"
echo "Started BrowserStack build $build_id: $dashboard"

# Poll until the build leaves queued/running. Device runs take a few minutes each; 5 parallel slots.
status=""
for _ in $(seq 1 120); do
  sleep 30
  status=$(curl -sS -u "$auth" "$api/builds/$build_id" | jq -r '.status // empty')
  echo "Build status: ${status:-unknown}"
  case "$status" in
    queued|running|"") continue ;;
    *) break ;;
  esac
done

# Per-device results, so a failure is readable from the job log without opening the dashboard.
build_json=$(curl -sS -u "$auth" "$api/builds/$build_id")
echo "Final build response:"
jq . <<<"$build_json" || echo "$build_json"
for session in $(jq -r '[.. | objects | select(has("sessions")) | .sessions[]? | (.id // .session_id // empty)] | unique | .[]' <<<"$build_json" 2>/dev/null); do
  echo "Session $session:"
  curl -sS -u "$auth" "$api/builds/$build_id/sessions/$session" | jq . || true
done

{
  echo "### BrowserStack: ${status:-timed out}"
  echo "Devices: $BROWSERSTACK_DEVICES"
  echo
  echo "[Open the build in BrowserStack]($dashboard)"
} >> "$summary"

[[ "$status" == "passed" ]] || { echo "::error::BrowserStack build $build_id ended as '${status:-timed out}'"; exit 1; }
