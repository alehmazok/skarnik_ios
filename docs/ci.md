# CI and TestFlight

All CI, including TestFlight uploads, runs on GitHub Actions (`macos-26` runners, latest stable Xcode).
Workflows live in `.github/workflows/`:

- **CI** (`ci.yml`) runs the unit tests and the offline-safe `SkarnikUITests` on the newest iOS Simulator for every pull request and every push to `main`. Pull requests run the UI tests on an iPhone only; pushes to `main` and manual runs add the iPad (split view). A failed UI test case is retried up to twice in the same job (`-retry-tests-on-failure -test-iterations 3`), so one slow simulator wait no longer costs a 20-minute rerun; a test that fails 3 times still fails the job.
  Why: the account gets a limited number of free macOS runners at a time. With three jobs per pull request, parallel runs left jobs queued until GitHub cancelled them, and most red runs were timing flakes that passed on rerun.
- **BrowserStack** (`browserstack.yml`) runs the UI tests on real devices in BrowserStack App Automate on every push to `main`, manually, and on pull requests that change the pipeline or the UI tests (setup in [browserstack.md](browserstack.md)).
- **TestFlight** (`testflight.yml`) archives a Release build and uploads it to TestFlight. Start it from
  Actions → TestFlight → Run workflow. The build number is picked automatically: the highest build already on
  App Store Connect + 1 (never below `CURRENT_PROJECT_VERSION` in the project). Pass `build_number` to override it.
  The project file is not changed, so `MARKETING_VERSION` is still bumped by hand for a new release. Pull requests that change the pipeline run it as a dry
  run (archive and export only, nothing uploaded).

Signing is automatic through an App Store Connect API key: profiles are managed by Xcode and the App Store
export uses a cloud-managed distribution certificate. The archive step needs one Apple Development certificate,
stored once as a `.p12` secret and imported into a temporary keychain on each run. Without it, every run would
create a new development certificate (runners start with an empty keychain) until the team hits Apple's limit
("Choose a certificate to revoke"). Required repository secrets:

| Secret | Value |
|--------|-------|
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | API key issuer ID |
| `ASC_KEY_P8` | The `.p8` key, base64-encoded (raw text also works) |
| `GOOGLE_SERVICE_INFO_PLIST` | `GoogleService-Info.plist`, base64-encoded |
| `DEV_CERT_P12` | One Apple Development certificate with its private key, exported as `.p12`, base64-encoded |
| `DEV_CERT_PASSWORD` | Password of that `.p12` (empty if none) |
| `BROWSERSTACK_USERNAME` | BrowserStack username (BrowserStack workflow only) |
| `BROWSERSTACK_ACCESS_KEY` | BrowserStack access key (BrowserStack workflow only) |
| `SENTRY_DSN` | DSN of the Sentry project `skarnik_ios` (org `skarnik`). Without it the build reports no crashes |
| `SENTRY_AUTH_TOKEN` | Sentry auth token with `project:releases` scope, for the dSYM upload. Without it crashes stay unsymbolicated |

The repository variable `SENTRY_PROJECT` overrides the Sentry project slug (default `skarnik_ios`).

To set up or rotate the certificate: revoke the old development certificates created by CI at
developer.apple.com → Certificates, then on a Mac open Xcode → Settings → Accounts → Manage Certificates,
add an **Apple Development** certificate, right-click it → Export Certificate, set a password, and store
`base64 -i cert.p12 | pbcopy` as `DEV_CERT_P12` and the password as `DEV_CERT_PASSWORD`.
