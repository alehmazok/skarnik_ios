#!/usr/bin/env bash
# Uploads the device build to BrowserStack App Automate and runs the XCUITest suite on real devices.
#
#   ci/browserstack-run.sh <app.ipa> <test-suite.zip>
#
# Env: BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY (secrets), BROWSERSTACK_DEVICES (comma-separated,
# e.g. "iPhone 15-17,iPhone 13-15"), BUILD_TAG (optional label shown in the BrowserStack dashboard).
# Optional: RUN_NAME (label in the job summary), ONLY_TESTING / SKIP_TESTING (comma-separated test classes
# or Class/testMethod), NETWORK_PROFILE (e.g. "no-network").
# Exits non-zero unless the BrowserStack build ends as "passed".
set -euo pipefail

ipa="$1"
suite="$2"
api="https://api-cloud.browserstack.com/app-automate/xcuitest/v2"
auth="$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

upload() { # <endpoint> <file> <json field>
  local response
  # `|| ...` keeps set -e from exiting before BrowserStack's error body is printed.
  response=$(curl -sS --fail-with-body -u "$auth" -X POST "$api/$1" -F "file=@$2") ||
    { echo "::error::Upload to $1 failed: $response"; exit 1; }
  jq -er ".$3" <<<"$response" || { echo "::error::Upload to $1 failed: $response"; exit 1; }
}

echo "Uploading $ipa"
app_url=$(upload app "$ipa" app_url)
echo "Uploading $suite"
suite_url=$(upload test-suite "$suite" test_suite_url)

list() { jq -cn --arg d "$1" '$d | split(",") | map(gsub("^ +| +$"; "")) | map(select(length > 0))'; }
devices=$(list "$BROWSERSTACK_DEVICES")
payload=$(jq -n \
  --arg app "$app_url" --arg suite "$suite_url" --argjson devices "$devices" \
  --arg tag "${BUILD_TAG:-manual}" \
  --argjson only "$(list "${ONLY_TESTING:-}")" --argjson skip "$(list "${SKIP_TESTING:-}")" \
  --arg network "${NETWORK_PROFILE:-}" \
  '{app: $app, testSuite: $suite, devices: $devices, project: "Skarnik iOS", buildTag: $tag,
    deviceLogs: true, networkLogs: false}
   + (if ($only | length) > 0 then {"only-testing": $only} else {} end)
   + (if ($skip | length) > 0 then {"skip-testing": $skip} else {} end)
   + (if $network != "" then {networkProfile: $network} else {} end)')
echo "Build request: $(jq -c 'del(.app, .testSuite)' <<<"$payload")"

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
  session_json=$(curl -sS -u "$auth" "$api/builds/$build_id/sessions/$session")
  jq . <<<"$session_json" || echo "$session_json"
  # For failed tests, print the assertion lines from the XCTest instrumentation log.
  for log_url in $(jq -r '.. | objects | select(.status? == "failed" and has("instrumentation_log")) | .instrumentation_log' <<<"$session_json" 2>/dev/null); do
    echo "Failure details ($log_url):"
    curl -sS -u "$auth" "$log_url" | grep -v "^\s*$" | tail -60 || true
  done
done

{
  echo "### BrowserStack${RUN_NAME:+ ($RUN_NAME)}: ${status:-timed out}"
  echo "Devices: $BROWSERSTACK_DEVICES"
  echo
  echo "[Open the build in BrowserStack]($dashboard)"
} >> "$summary"

[[ "$status" == "passed" ]] || { echo "::error::BrowserStack build $build_id ended as '${status:-timed out}'"; exit 1; }
