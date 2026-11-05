# Bitrise CI

Skarnik's iOS builds move from GitHub-hosted macOS runners (jobs kept queuing and getting cancelled) to
Bitrise, as a free public open-source app. `bitrise.yml` in the repo root is the pipeline; the build logic
is in shell scripts that run the same anywhere:

| Script | Does |
| --- | --- |
| `ci/run-tests.sh <scheme> <name>` | Unit or UI tests on the newest iPhone simulator, unsigned |
| `ci/browserstack-build.sh` | Unsigned device build + `Skarnik.ipa` / `SkarnikUITests.zip` for BrowserStack |
| `scripts/browserstack-run.sh` | Upload to BrowserStack App Automate, run, wait for the result |
| `ci/testflight.sh` | Archive, export, optional upload to TestFlight |
| `ci/write-google-service-info.sh` | Firebase config from the secret, or the placeholder on PR builds |

## What runs when

| Trigger | Runs |
| --- | --- |
| Pull request | `unit-tests`, `ui-tests` (pipeline `pr`) |
| Push to `main` | `unit-tests`, `ui-tests`, `browserstack` (pipeline `main`) |
| Manual: Start/Schedule a Build → Workflow `testflight` | Archive and upload to TestFlight |
| Manual: Workflow `testflight-dry-run` | Archive and export only, after changing signing or `ci/testflight.sh` |
| Manual: Workflow `browserstack`, env `BROWSERSTACK_DEVICES` | Device tests on other devices |

Manual builds take optional env vars: `BUILD_NUMBER` for `testflight` (empty = next free number on App
Store Connect) and `BROWSERSTACK_DEVICES` for `browserstack`.

Public Bitrise apps never expose secrets to pull request builds. So PR builds use
`ci/GoogleService-Info.placeholder.plist` (valid format, no real Firebase project) via
`ALLOW_PLACEHOLDER_PLIST=1`; builds on `main` and TestFlight use the real plist secret.

## Signing

Same rule as on GitHub: one stored Apple Development certificate, never a new one per build (Apple caps
development certificates per team). `certificate-and-profile-installer` imports the `.p12` from the
Code Signing tab into the build keychain, and `ci/testflight.sh` stops if no Apple Development identity is
there. Distribution signing for the export stays cloud-managed through the App Store Connect API key,
which must have the **Admin** role.

## One-time setup (Aleh)

1. Sign in to [bitrise.io](https://bitrise.io) with GitHub (account skarnikapp@gmail.com), then
   **Add new app** → `alehmazok/skarnik_ios` → choose **Public**. Let it install the Bitrise GitHub app on
   the repo so PRs get status checks. When it asks for a config, choose the `bitrise.yml` stored in the
   repository.
2. **Settings → Stack & Machine**: pick the newest stable Xcode 26 stack. If it is newer than the `stack` in
   `bitrise.yml`, tell Claude so the file matches.
3. **Code Signing → Code signing certificates**: upload the same development `.p12` as the GitHub secret
   `DEV_CERT_P12` (decoded from base64), with its password.
4. **Secrets** (all **protected**, none exposed to pull requests):
   - `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the `.p8` text or base64, same as on GitHub)
   - `GOOGLE_SERVICE_INFO_PLIST` (base64, same as on GitHub)
   - `BROWSERSTACK_USERNAME`, `BROWSERSTACK_ACCESS_KEY`
5. Run the `testflight-dry-run` workflow on `main` once, then `testflight`. Check the build appears in
   TestFlight and no new certificate appears at developer.apple.com → Certificates.

## Cutover

GitHub Actions keeps running beside Bitrise until Bitrise has passed on two PRs and one TestFlight upload.
Then the Bitrise checks become required on `main`, the three GitHub workflows are deleted in one PR, and the
GitHub secrets stay for a month as a rollback.
