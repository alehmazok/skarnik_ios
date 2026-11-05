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
- Word translation and detail lookup, fetched on-demand from skarnik.by and parsed with SwiftSoup
- Word stress (nacisk) lookup from starnik.by, with dual-source fallback (aligned with the Flutter app)
- Spelling suggestions for rus-bel vocabulary
- Offline dictionary download, per vocabulary
- Search history, with delete support
- Закладкі (Favorites/Bookmarks): save words from the details screen, sort by date added or alphabetically
- Belarusian keyboard row with haptic/sound feedback on extra letters
- "Word of the Day" home screen widget, deep-linking into the word details screen
- Universal Links support for skarnik.app sharing URLs
- Word sharing via share sheet
- Report issue flow for word translation feedback
- Firebase Analytics & Crashlytics integration

## Tech Stack

- Swift — UIKit (main app structure) + SwiftUI (widget, word stress view)
- **Reactive:** Combine (MVVM for word details / word stress)
- **Local storage:** [SQLite.swift](https://github.com/stephencelis/SQLite.swift)
- **HTML parsing:** [SwiftSoup](https://github.com/scinfu/SwiftSoup)
- **Backend:** skarnik.by (HTML) / starnik.by, with API and Supabase sources stubbed behind a fallback chain
- **Analytics:** Firebase
- **Dependency management:** Swift Package Manager

## Architecture

Hybrid UIKit + SwiftUI, MVVM + Combine for the reactive pieces.

```
Skarnik/
├── Shared/
│   ├── SKVocabularyIndex.swift        # Local SQLite queries
│   └── SKTranslationSource.swift      # Translation fetching (API → Supabase → HTML fallback chain)
├── SKSearchWordsTableViewController.swift   # Search UI (UIKit)
├── SKWordDetailsViewController.swift        # Word entry display (MVVM + Combine)
├── SKFavoritesController.swift              # Favorites persistence (UserDefaults)
├── SKFavoritesViewController.swift          # Закладкі tab (SwiftUI)
├── SKSplitViewController.swift
├── SKVocabulariesTableViewController.swift
└── vocabulary.db                      # Core search index

WordWidget/                            # "Word of the Day" widget (SwiftUI + WidgetKit)
SkarnikTests/                          # Unit tests (translation parsing, etc.)
```

## Getting Started

### Prerequisites

- Xcode (see `Skarnik.xcodeproj` for the target Swift/iOS versions)
- Swift Package Manager resolves dependencies automatically on first build

### Setup

```bash
git clone git@github.com:belanghelp/skarnik.by-ios.git
cd skarnik.by-ios
open Skarnik.xcodeproj
```

### Run

Build and run the `Skarnik` scheme from Xcode on a simulator or device.

### Tests

Run the `SkarnikTests` scheme in Xcode, or:

```bash
xcodebuild test -project Skarnik.xcodeproj -scheme Skarnik -destination 'platform=iOS Simulator,name=iPhone 16'
```

## CI / TestFlight

GitHub Actions workflows live in `.github/workflows/`:

- **CI** (`ci.yml`) runs the unit tests on an iOS Simulator for every pull request and every push to `main`.
- **TestFlight** (`testflight.yml`) archives a Release build and uploads it to TestFlight. Start it from
  Actions → TestFlight → Run workflow. The build number is picked automatically: the highest build already on
  App Store Connect + 1 (never below `CURRENT_PROJECT_VERSION` in the project). Pass `build_number` to override it.
  The project file is not changed, so `MARKETING_VERSION` is still bumped by hand for a new release. Pull requests that change the pipeline run it as a dry
  run (archive and export only, nothing uploaded).

Signing is automatic (cloud-managed) through an App Store Connect API key, so no certificates or profiles are
stored in the repo or in secrets. Required repository secrets:

| Secret | Value |
|--------|-------|
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | API key issuer ID |
| `ASC_KEY_P8` | The `.p8` key, base64-encoded (raw text also works) |
| `GOOGLE_SERVICE_INFO_PLIST` | `GoogleService-Info.plist`, base64-encoded |

## Data Sources

- **[skarnik.by](https://skarnik.by)** — dictionary content (Рус-Бел, Бел-Рус, Тлумачальны), scraped as HTML via SwiftSoup; primary source in the translation fallback chain (skarnik_admin API → Supabase → HTML)
- **skarnik_admin** (`skarnik.play.of.by`) — Django/MariaDB backend used both as a translation API fallback and as the cloud fallback for word-stress lookup
- **[starnik.by](https://starnik.by)** — primary source for word stress (nacisk) and spelling suggestions
- **[GrammarDB](https://github.com/Belarus/GrammarDB)** — fallback source for word stress data, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

## Contributing

This is a personal project. Issues and pull requests are welcome — please open an issue to discuss significant changes before submitting a PR.

## License

Source code licensed under the [MIT License](LICENSE). Dictionary content is © its respective rights holders and is not covered by this license.
