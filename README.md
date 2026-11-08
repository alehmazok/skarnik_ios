<div align="center">
  <img src="Skarnik/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" alt="Skarnik logo" width="120" />

  # Skarnik (Скарнік) for iOS

  Belarusian dictionary app — Рус-Бел, Бел-Рус, and Тлумачальны (TSBM) dictionaries in one place.

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  ![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
  ![Swift](https://img.shields.io/badge/Swift-UIKit%20%7C%20SwiftUI-orange?logo=swift)

  <a href="https://apps.apple.com/be/app/id988334682">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us" alt="Download on the App Store" width="160" />
  </a>

</div>

## About

Skarnik is a comprehensive Russian-Belarusian, Belarusian-Russian, and Belarusian explanatory (TSBM) dictionary app for iOS, based on the [skarnik.by](https://skarnik.by) service. It provides quick offline search plus detailed word entries, including word stress and spelling info.

## Features

- Fast offline word search via local SQLite index, with fuzzy fallback for misspelled queries
- Word translation and detail lookup: downloaded offline dictionary first, then Supabase, then the Skarnik admin API
- Word stress (nacisk) lookup: starnik.by first, the Skarnik admin API as fallback
- Spelling suggestions for rus-bel vocabulary
- Offline dictionary download from Supabase, per vocabulary
- Search history, with delete support
- Закладкі (Favorites/Bookmarks): save words from the details screen, sort by date added or alphabetically
- Belarusian keyboard row with haptic/sound feedback on extra letters
- "Word of the Day" home screen widget, deep-linking into the word details screen
- Universal Links support for skarnik.app sharing URLs
- Word sharing via share sheet
- Report issue flow for word translation feedback
- Firebase Analytics (after consent) and Sentry crash reporting

## Tech Stack

- Swift — UIKit (main app structure) + SwiftUI (widget, word stress view)
- **Reactive:** Combine (MVVM for word details / word stress)
- **Local storage:** [SQLite.swift](https://github.com/stephencelis/SQLite.swift)
- **HTML parsing:** [SwiftSoup](https://github.com/scinfu/SwiftSoup)
- **Backend:** Supabase `main_word` and the Skarnik admin API for translations (after the offline dictionary), starnik.by and the admin API for stress
- **Analytics:** Firebase Analytics, only after the user's consent
- **Crash reporting:** [Sentry](https://sentry.io) (`sentry-cocoa`), release builds only
- **Dependency management:** Swift Package Manager

## Architecture

Hybrid UIKit + SwiftUI, MVVM + Combine for the reactive pieces.

```
Skarnik/
├── Analytics/                         # Firebase Analytics (after consent) + debug logger
├── Shared/                            # Code shared with the widget
│   ├── SKVocabularyIndex.swift        # Local SQLite search queries
│   ├── SKTranslationSource.swift      # Translation fetching (offline DB → Supabase → admin API)
│   ├── SKTranslationRenderer.swift    # Translation HTML → attributed text (SwiftSoup)
│   ├── SKStressResolver.swift         # Stress lookup (starnik.by → admin API)
│   ├── SKErrorReporting.swift         # Non-fatal error hook (Sentry in the app)
│   ├── OfflineDictionaries/           # Offline dictionary download and storage
│   └── WordFetch/                     # Word of the Day fetching
├── SwiftUI/                           # SwiftUI screens (settings, history, about, word stress, …)
├── SKCrashReporting.swift                   # Sentry setup (Release builds with a DSN only)
├── SKSearchWordsTableViewController.swift   # Search UI (UIKit)
├── SKWordDetailsViewController.swift        # Word entry display (MVVM + Combine)
├── SKFavoritesController.swift              # Favorites persistence (UserDefaults)
├── SKFavoritesViewController.swift          # Закладкі tab (SwiftUI)
├── SKSplitViewController.swift
├── SKVocabulariesTableViewController.swift
└── vocabulary.db                      # Core search index

WordWidget/                            # "Word of the Day" widget (SwiftUI + WidgetKit)
SkarnikTests/                          # Unit tests (search, translation sources and rendering, stress, …)
SkarnikUITests/                        # XCUITest smoke tests (simulator CI + BrowserStack devices)
```

## Getting Started

### Prerequisites

- The latest stable Xcode (CI uses the same). The app and widget target iOS 17.0.
- Swift Package Manager resolves dependencies automatically on first build.
- A `GoogleService-Info.plist` in the project root. It is gitignored; the build needs the file, so use your
  own Firebase project's config (CI writes it from the `GOOGLE_SERVICE_INFO_PLIST` secret).

### Setup

```bash
git clone git@github.com:alehmazok/skarnik_ios.git
cd skarnik_ios
open Skarnik.xcodeproj
```

### Run

Build and run the `Skarnik` scheme from Xcode on a simulator or device.

### Tests

Unit tests run with the `Skarnik` scheme (Product → Test in Xcode), UI tests with the `SkarnikUITests` scheme.
From the command line, with any installed iPhone simulator:

```bash
xcodebuild test -project Skarnik.xcodeproj -scheme Skarnik -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -project Skarnik.xcodeproj -scheme SkarnikUITests -destination 'platform=iOS Simulator,name=iPhone 17'
```

`NetworkUITests`, `OfflineDictionaryUITests` and `NoNetworkUITests` need the network (or its absence) and are
meant for BrowserStack; the simulator CI job skips them.

## CI / TestFlight

All CI, including TestFlight uploads, runs on GitHub Actions (`macos-26` runners, latest stable Xcode).
Workflows live in `.github/workflows/`:

- **CI** (`ci.yml`) runs the unit tests and the offline-safe `SkarnikUITests` on the newest iOS Simulator for every pull request and every push to `main`.
- **BrowserStack** (`browserstack.yml`) runs the UI tests on real devices in BrowserStack App Automate on every push to `main`, manually, and on pull requests that change the pipeline or the UI tests (setup in [docs/browserstack.md](docs/browserstack.md)).
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
  release binary using `SENTRY_AUTH_TOKEN` (secrets table above). Missing secrets only produce a warning.

## Install source

The GA4 user property `install_source` (custom dimension `customUser:install_source`) records the channel the
app came from, with the same values as skarnik_android: `app_store`, `testflight`, `ios_marketplace`, `sideload`
(web or other distributor), `debug`, `unknown` (lookup failed or took over 3 s). `SKInstallSourceDetector` asks
MarketplaceKit `AppDistributor` on iOS 17.4+, then the StoreKit 2 `AppTransaction` environment, then the receipt
name. Debug builds send `debug` without a lookup. It is set off the main thread on every launch and right after
the user grants consent, and never while analytics consent is off. MarketplaceKit is weak-linked
(`-weak_framework`) because `AppDistributor` needs iOS 17.4 and the app runs on iOS 17.0.


Translations are looked up in this order, the same in every Skarnik app: the downloaded offline dictionary,
then Supabase, then the Skarnik admin API.

- **[skarnik.by](https://skarnik.by)** — origin of the dictionary content (Рус-Бел, Бел-Рус, Тлумачальны). The app no longer scrapes it; each entry still links to its skarnik.by page.
- **Supabase** (`main_word` table) — online translation source and the source of the offline dictionary downloads
- **Skarnik admin** (`skarnik.play.of.by`) — Django backend; last translation fallback and the fallback for word-stress lookup
- **[starnik.by](https://starnik.by)** — primary source for word stress (nacisk) and spelling info
- **[GrammarDB](https://github.com/Belarus/GrammarDB)** — word stress data behind the admin API fallback, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

## Contributing

This is a personal project. Issues and pull requests are welcome — please open an issue to discuss significant changes before submitting a PR.
For anything else, write to skarnikapp@gmail.com. The privacy policy is at [skarnik.app/privacy](https://skarnik.app/privacy).

## Acknowledgements

This project is tested with BrowserStack.

[BrowserStack](https://www.browserstack.com) supports the project through its open source sponsorship program.

[Sentry](https://sentry.io) provides crash reporting through its open source sponsorship program.

## License

Source code licensed under the [MIT License](LICENSE). Dictionary content is © its respective rights holders and is not covered by this license.
