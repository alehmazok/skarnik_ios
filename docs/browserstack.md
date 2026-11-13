# BrowserStack real-device testing

Skarnik is in BrowserStack's open source sponsorship program (valid until
2027-11-05, 5 parallel tests, unlimited users). The sponsorship requires the line "This project is tested
with BrowserStack" to stay in `README.md` on `main`.

## What runs

- **`SkarnikUITests`** is an XCUITest target with one class per journey. Every test launches the app
  with `-uiTesting -uiTestingReset` (`SKUITesting` in `AppDelegate.swift`): a fresh-install state with no
  history, bookmarks, settings or offline dictionaries, animations off and no App Store review prompt. The
  analytics consent sheet shows and is declined. Tests find elements by accessibility identifiers
  (`wordDetails.*`, `search.*`, `history.row`, `favorites.*`, `vocabulary.word`, `settings.*`, `wordStress`)
  and never assert on translation text.

  | Class | What it covers | Where it runs |
  |---|---|---|
  | `SearchUITests` | tabs, search in all three dictionaries, extra letter keys, Russian-layout letters, no-results hint, history (order, no duplicates, survives relaunch) | simulator + devices |
  | `BookmarksUITests` | bookmark a word, find it after relaunch, remove it | simulator + devices |
  | `BrowseUITests` | Слоўнікі tab opens a word from each dictionary | simulator + devices |
  | `DeepLinkUITests` | `skarnik://word?id=&lang=` opens the word | simulator + devices |
  | `SettingsUITests` | offline rows, analytics toggle, article colours persist, About | simulator + devices |
  | `NetworkUITests` | translation loads from Supabase/API, share sheet, «На́ціск» stress table | devices |
  | `OfflineDictionaryUITests` | download ТСБМ, read a word from the offline copy (`local` source), delete | devices |
  | `NoNetworkUITests` | network error and retry with the network off | devices, no-network build only |

  The word screen shows which source answered as a hidden `wordDetails.source` label, only under
  `-uiTesting`, so tests can check the fetch order (offline db → Supabase → admin API).
  It has its own `SkarnikUITests` scheme, so the unit-test scheme and its CI job are unchanged.
- **CI → UI tests** and **UI tests (iPad)** (`ci.yml`) run the offline-safe classes on an iPhone and an iPad
  simulator for every pull request and push to `main` (they skip `NetworkUITests`, `OfflineDictionaryUITests` and `NoNetworkUITests`).
- **BrowserStack** (`browserstack.yml`) builds the app and the test runner for real devices, unsigned,
  packages `Skarnik.ipa` and
  `SkarnikUITests.zip`, uploads both to App Automate and runs the suite on the device list, then waits for
  the result. It runs on every push to `main` and from Actions → BrowserStack → Run workflow (with an
  optional `devices` input, e.g. `iPhone 16-18,iPhone 13-15`). Pull requests that change the pipeline or
  `SkarnikUITests` run it as well. Each run starts two BrowserStack builds in parallel: everything except
  `NoNetworkUITests` on the device list, and `NoNetworkUITests` alone on one device with
  `networkProfile: no-network`.

The upload, run and polling logic is in `scripts/browserstack-run.sh` (BrowserStack REST API,
`api-cloud.browserstack.com/app-automate/xcuitest/v2`). The job summary links to the build in the
BrowserStack dashboard, where each device has a video, device logs and per-test results.

## One-time setup (Aleh)

1. In the BrowserStack dashboard, check that **App Automate** is part of the sponsored plan (the approval
   email says "Automate Mobile"). If only browser Automate is enabled, ask BrowserStack support to add App
   Automate for the open source plan.
2. Copy the username and access key from *Account → Settings → Access key* (or the App Automate dashboard)
   into the repository secrets `BROWSERSTACK_USERNAME` and `BROWSERSTACK_ACCESS_KEY`.
3. Run Actions → BrowserStack → Run workflow on `main` once and open the dashboard link from the summary.

Until the two secrets exist, the workflow still builds and packages, and skips the device run with a warning.

## iOS versions

The test runner is built with the latest Xcode (26.x). On BrowserStack's iOS 16 and 17 devices it crashes
before any test starts: `Symbol not found: _OBJC_CLASS_$_XCTCommandLineToolHelper` (iOS 17) and
`Library not loaded: @rpath/lib_TestingInterop.dylib` (iOS 16). That is the Xcode 26 test runtime missing
on those systems, not an app bug. The default device list is therefore iOS 18+ only. Covering iOS 17
would need a second build of the runner with an older Xcode (e.g. Xcode 16 on a `macos-15` runner).

## Signing notes

The device build is unsigned (`CODE_SIGNING_ALLOWED=NO`). BrowserStack re-signs every uploaded iOS app
with its own provisioning profile, and that strips entitlements anyway (the widget's App Group is not
available on BrowserStack devices). Signing on CI would also create a new Apple Development certificate
on every run, since GitHub runners start with an empty keychain, and the team's certificate limit is
small. If BrowserStack ever rejects the unsigned build, the fallback is a development certificate stored
once as a `.p12` secret and imported into the runner keychain, never a certificate created per run.

## Next steps

- Add a journey to `SkarnikUITests` with every new user-visible feature, the way the Android app adds
  Maestro flows.
- Not covered yet: links inside an article and the redirect toast (they need a known entry with a link or
  `redirect_to`), iPad split view, rotation and large text. The widget and Universal Links cannot run on
  BrowserStack: re-signing strips the App Group and associated domains.
- Tune the device list: oldest supported iOS (deployment target 17.0), current iOS, and an iPad.
