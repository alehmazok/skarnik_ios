# Crash reporting and analytics

## Crash reporting

Crashes go to Sentry (org `skarnik`, project `skarnik_ios`), the same place as the Android app. The rules match
skarnik_android's ADR 0008:

- `SKCrashReporting.start()` runs first in `didFinishLaunching`, only in Release builds whose Info.plist has a DSN
  (`SKSentryDSN = $(SENTRY_DSN)`, passed by the TestFlight pipeline from the secret). Debug builds, local builds,
  UI tests and the BrowserStack builds report nothing.
- TestFlight and App Store share one binary, so the environment is decided at run time: `internal` on a TestFlight
  install (sandbox receipt), `production` from the App Store.
- No user data: no IP or user id (`sendDefaultPii = false`), no screenshots, no view hierarchy, no breadcrumbs
  (taps, network URLs can carry the query), no failed-request events, no performance tracing, no session replay.
  Not gated by the analytics consent.
- Caught errors: `SKErrorReporting.logError(error, tag:)` sends the error type, code and tag only, never the
  message. Network, server and cancellation errors are not reported.
- The widget does not report: it runs in a tight memory budget and shares its fetch code with the app, which reports.
- The TestFlight workflow (`testflight.yml`) passes the `SENTRY_DSN` secret to the archive as a build setting and,
  after a real TestFlight upload, `ci/sentry-upload-dsyms.sh` uploads the dSYMs with a pinned `sentry-cli`
  release binary using `SENTRY_AUTH_TOKEN` (secrets table in [ci.md](ci.md)). Missing secrets only produce a warning.

## Install source

The GA4 user property `install_source` (custom dimension `customUser:install_source`) records the channel the
app came from, with the same values as skarnik_android: `app_store`, `testflight`, `ios_marketplace`, `sideload`
(web or other distributor), `debug`, `unknown` (lookup failed or took over 3 s). `SKInstallSourceDetector` asks
MarketplaceKit `AppDistributor` on iOS 17.4+, then the StoreKit 2 `AppTransaction` environment, then the receipt
name. Debug builds send `debug` without a lookup. It is set off the main thread on every launch and right after
the user grants consent, and never while analytics consent is off. MarketplaceKit is weak-linked
(`-weak_framework`) because `AppDistributor` needs iOS 17.4 and the app runs on iOS 17.0.
