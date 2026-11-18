<div align="center">
  <img src="Skarnik/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" alt="Skarnik logo" width="120" />

  # Skarnik (Скарнік) for iOS

  Belarusian dictionary app — Рус-Бел, Бел-Рус, and Тлумачальны (TSBM) dictionaries in one place.

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  ![Platforms](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20iPadOS%20%7C%20macOS-lightgrey)
  ![Swift](https://img.shields.io/badge/Swift-UIKit%20%7C%20SwiftUI-orange?logo=swift)

  <a href="https://apps.apple.com/app/id988334682">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us" alt="Download on the App Store" width="160" />
  </a>

</div>

## About

Skarnik is a Russian-Belarusian, Belarusian-Russian and Belarusian explanatory (TSBM) dictionary for iPhone,
iPad and Mac. Search works offline, and each entry shows the translation, word stress and spelling info. The
interface is in Belarusian.

It runs on iOS and iPadOS 17.0 or later, and on Macs with Apple silicon as "Designed for iPad".

## Features

**Search and browse**
- Fast offline search over a bundled SQLite index, with fuzzy matching for misspelled queries
- Belarusian keyboard row with the extra letters, with haptic and sound feedback
- iOS 26: search lives in its own tab at the bottom, next to a separate Гісторыя tab
- iPad and Mac: the list and the entry side by side in a split view
- Browse each dictionary alphabetically

**Word entries**
- Translations for all three dictionaries, also offline once a dictionary is downloaded
- Tap an underlined Belarusian word in a translation to open its own entry
- Tap an abbreviation («разг.», «жен.», «Колас.») to see its full text
- Link between the same headword in Бел-Рус and ТСБМ
- Word stress (націск) and spelling suggestions
- Share an entry as a skarnik.app link, or report a problem with a translation

**Your words**
- Search history, with delete support
- Закладкі (bookmarks), sorted by date added or alphabetically
- Offline dictionary download, per dictionary

**Around the app**
- "Word of the Day" home screen widget that opens the entry
- Universal Links: skarnik.app links open in the app
- «Што новага» sheet after an update, and the full list in Налады
- Firebase Analytics only after the user's consent; Sentry crash reporting

## Tech Stack

- **UI:** UIKit for the main structure, SwiftUI for most screens and the widget (WidgetKit)
- **Reactive:** Combine (MVVM for word details and word stress)
- **Local storage:** [SQLite.swift](https://github.com/stephencelis/SQLite.swift)
- **HTML parsing:** [SwiftSoup](https://github.com/scinfu/SwiftSoup)
- **Firebase:** Analytics (after consent) and Remote Config (A/B test of the Бел-Рус ⇄ ТСБМ link placement)
- **Crash reporting:** [Sentry](https://sentry.io) (`sentry-cocoa`), release builds only
- **Dependencies:** Swift Package Manager

## Architecture

Hybrid UIKit + SwiftUI, MVVM + Combine for the reactive pieces. More detail in [docs/context.md](docs/context.md).

```
Skarnik/
├── Analytics/                 # Firebase Analytics (after consent) + debug logger
├── Shared/                    # Code shared with the widget
│   ├── SKVocabularyIndex.swift      # Offline search over vocabulary.db
│   ├── SKTranslationSource.swift    # Translation sources (offline DB → Supabase → admin API)
│   ├── SKTranslationRenderer.swift  # Translation HTML → attributed text
│   ├── SKStressResolver.swift       # Word stress (starnik.by → admin API)
│   ├── OfflineDictionaries/         # Offline dictionary download and storage
│   └── WordFetch/                   # Word of the Day fetching
├── SwiftUI/                   # SwiftUI screens (word details, history, bookmarks, settings, …)
├── SK*ViewController.swift    # UIKit screens: tab bar, split view, search, dictionaries, word details
└── vocabulary.db              # Bundled search index

WordWidget/                    # "Word of the Day" widget
SkarnikTests/                  # Unit tests
SkarnikUITests/                # XCUITest suite (simulator CI + BrowserStack devices)
docs/                          # Specs and maintainer docs
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

## CI and maintenance

All CI, including TestFlight uploads, runs on GitHub Actions:

- **CI** (`ci.yml`): unit tests and offline-safe UI tests on every pull request (iPhone simulator) and push to `main` (iPhone and iPad)
- **BrowserStack** (`browserstack.yml`): UI tests on real devices
- **TestFlight** (`testflight.yml`): manual Release archive and upload

Details, signing and the required secrets are in [docs/ci.md](docs/ci.md). Crash reporting rules and the
`install_source` analytics property are in [docs/crash-reporting-and-analytics.md](docs/crash-reporting-and-analytics.md).
BrowserStack setup is in [docs/browserstack.md](docs/browserstack.md).

## Data sources

Translations are looked up in this order, the same in every Skarnik app: the downloaded offline dictionary,
then Supabase, then the Skarnik admin API.

- **Supabase** (`main_word` table): online translation source and the source of the offline dictionary downloads
- **Skarnik admin** (`skarnik.play.of.by`): Django backend; last translation fallback and the fallback for word stress
- **[starnik.by](https://starnik.by)**: primary source for word stress (націск) and spelling info
- **[GrammarDB](https://github.com/Belarus/GrammarDB)**: word stress data behind the admin API fallback, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

## Related projects

- **[skarnik.app](https://skarnik.app)** ([repo](https://github.com/alehmazok/skarnik.app)): the Skarnik website and installable web app; shared links (`skarnik.app/r/<dict>/<id>`) open the entry in the app
- **[skarnik_android](https://github.com/alehmazok/skarnik_android)**: the native Android app
- **[skarnik_admin](https://github.com/alehmazok/skarnik_admin)**: the dictionary admin and API

## Contributing

This is a personal project. Issues and pull requests are welcome — please open an issue to discuss significant changes before submitting a PR.
For anything else, write to skarnikapp@gmail.com. The privacy policy is at [skarnik.app/privacy](https://skarnik.app/privacy).

## Acknowledgements

This project is tested with BrowserStack.

[BrowserStack](https://www.browserstack.com) supports the project through its open source sponsorship program.

[Sentry](https://sentry.io) provides crash reporting through its open source sponsorship program.

## License

Source code licensed under the [MIT License](LICENSE). Dictionary content is © its respective rights holders and is not covered by this license.
