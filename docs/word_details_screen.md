# Word details screen

The screen that shows one dictionary entry: the word, which dictionary it is from, and its
translation or definition. It is the screen users spend most time on, so it is optimised for
reading, not for actions.

Code:

| Piece | File |
|---|---|
| Hosting controller, Націск navigation, alerts | `Skarnik/SKWordDetailsViewController.swift` |
| View | `Skarnik/SwiftUI/SKWordDetailsView.swift` |
| View model (loading, redirects, headword, favourites) | `Skarnik/SKWordDetailsViewModel.swift` |
| Translation HTML → styled text | `Skarnik/Shared/SKTranslationRenderer.swift` |
| Translation sources (local, API, Supabase, HTML) | `Skarnik/Shared/SKTranslationSource.swift` |
| Tests | `SKWordDetailsViewModelTests`, `SKWordDetailsViewControllerTests`, `SKTranslationRendererTests` |

The design decisions below come from the design review tracked in #15.

---

## Layout

```
┌────────────────────────────────────────────┐
│ ‹ Back           «headword»       На́ціск   │  nav bar (title only after scroll)
├────────────────────────────────────────────┤
│ добразы́члівасць                           │  headword, .largeTitle bold
│ ПЕРАКЛАД НА РУСКУЮ МОВУ                    │  dictionary subtitle, .footnote secondary
│                                            │
│ translation article …                      │  rendered HTML, .body
│ …                                          │
│                                            │
│                     «Перанакіравана з …»   │  toast (only after a redirect)
├────────────────────────────────────────────┤
│ [Share]                         [Bookmark] │  bottom toolbar
└────────────────────────────────────────────┘
```

Everything above the toolbar is one `ScrollView` with 15 pt side padding, on the
`BackgroundColor` asset (`Color.appBackground`).

### Header (#19)

- **Headword**: the stressed form when the translation brings one (`translation.stress`),
  otherwise the plain word. `.largeTitle` bold, primary colour, wraps to as many lines as needed
  (long phrases are never truncated), selectable, marked as a VoiceOver header.
- **Dictionary subtitle** under it: «Пераклад на беларускую мову» / «Пераклад на рускую мову» /
  «Тлумачэнне слова», uppercased, `.footnote`, secondary colour, no fixed height.
- Both come from the word itself, so they show before the translation loads. The stressed form
  only adds a combining accent, so swapping it in does not change the line height: nothing jumps.
- With no word (empty iPad detail pane) the header is hidden rather than showing placeholders.

Why: the word used to be the smallest title on the screen, an inline nav-bar title truncated
between Back and «Націск», and it jumped when the stress form arrived.

### Nav bar

- Title is empty while the large headword is visible. Once the header scrolls under the bar
  (tracked with a preference key on the header's bottom edge), the title fades in as
  `«headword»`. No stray direction marks (U+200E) inside the quotes.
- Trailing item: the «На́ціск» button (see below).

### Translation (#17, #18, #20)

- Rendered by `SKTranslationRenderer` with SwiftSoup into an `NSAttributedString` and shown in a
  non-editable, selectable `UITextView`. No WebKit: the old `NSAttributedString(.html)` importer
  was slow, main-thread only, and had crashed.
- Rendering happens off the main thread and is redone when Dynamic Type, Bold Text or the
  article colour setting changes. Colours are dynamic system colours, so dark mode and Increase
  Contrast apply without re-rendering.
- `.article` layout: extra spacing between `<br>`-separated entries and a hanging indent, so each
  entry starts at the margin and is easy to scan.
- Whitespace: a run of spaces and `&nbsp;` inside a line collapses to one gap, so
  «благожелательность — &nbsp;добразычлівасць» shows a single space after the dash.
- Links: relative links resolve against skarnik.by; tapping one is routed by
  `SKWordDetailsViewModel.handleUrl`, which opens the linked entry in place
  (`/belrus|rusbel|tsbm/<id>`). Other links do nothing.

### «На́ціск» button (#25)

Opens stress and spelling tables; full behaviour in [stress_feature_spec.md](stress_feature_spec.md).

- While the translation loads, a disabled placeholder holds the slot, so the nav bar doesn't
  shift when the real button appears.
- Hidden when the entry has no single-word Belarusian candidates.
- One candidate: plain button. Several: menu of candidates. In be→ru that menu is the headword
  plus synonyms from the article (kept as is, decided by Aleh 2026-11-05).

### Bottom toolbar (#16)

- **Share** on the left, **Bookmark** on the right, with a `Spacer` between them. This is
  balanced on the iOS 26 glass toolbar and on older bars. (Before, a leftover spacer from the
  removed report button pushed both into the bottom-left corner.)
- Belarusian VoiceOver labels: «Падзяліцца»; «Дадаць у закладкі» / «Выдаліць з закладак»
  depending on the state, instead of the SF Symbol name in the system language.
- Bookmark toggling plays a light impact haptic.
- Share is disabled until the translation loads; Bookmark until there is a word.
- Share sends the link `https://skarnik.app/r/<dict>/<id>` (`sharingUrl`) together with the word
  (stressed form when known, `shareTitle`) as the message text and subject, so a plain-text chat
  reads «добразычлівасць — https://skarnik.app/r/belrus/27890» (`shareText`) and the link still
  gets its preview. It logs the Firebase `share` event (`logShareClicked`). (#23)
- iOS 16+ uses `ShareLink`; iOS 15 presents `UIActivityViewController` itself with the popover
  anchored to the Share button, so on iPad it is a popover from the button instead of a full sheet.
- The report button is hidden until it is ready (TODO in the view).

### Redirect toast (#18)

When an entry's `redirect_to` points to another entry, the view model follows it (at most 5
hops, to break cycles) and shows «Перанакіравана з «…»» for 2 seconds at the bottom. The toast
uses `tertiarySystemBackground` with a hairline `separator` border and a shadow, so it stands out
from the screen background in dark mode too.

### Loading and error states

Both states fill the space under the header and sit centred in it (#22). The scroll content is
at least as tall as the screen, so this works without a second scroll view; a long translation
scrolls as before.

- Loading: a centred spinner.
- Error: a centred message («Слова не знойдзена.», «Памылка сеткі. Праверце злучэнне з
  інтэрнэтам.», or the error's description) with a «Паспрабаваць яшчэ» button. The button calls
  `retry()`, which reloads the current word only from `.error`. iOS 17+ uses
  `ContentUnavailableView`; iOS 15–16 a look-alike stack (icon, message, bordered button).

---

## Colour rules (#17)

**The accent colour (Skarnik red) is only for things you can tap.** Red text reads as a link, and
on iOS also as an error, so non-interactive text never uses it.

| Element | Colour |
|---|---|
| «На́ціск» button, links in the article, toolbar icons | accent |
| Headword heading | primary label |
| Translated words / headwords in the article (legacy `831b03`, `0000a0`, `4863a0`) | **bold** primary label |
| Grammar labels (legacy `008000`, `a52a2a`, `cc33ff`) | `systemIndigo` |
| Examples and authors (legacy `5f5f5f`, `151b54`) | secondary label |
| Plain text (`000000`, unknown colours) | primary label |
| Spacers drawn in page colour (`ffffff`) | clear |
| Dictionary subtitle | secondary label |

Settings → «Колеры артыкула» lets users switch the article's highlighted words back to
«Чырвоныя Скарніка» (the red used on skarnik.by and in older versions). The default is
«Сістэмныя» (bold primary). This choice only affects article text; buttons keep the accent.

Never hard-code hex colours in the view: use system colours or the renderer's roles.

---

## Decisions from the design review (#15)

| Issue | Decision |
|---|---|
| #16 | Share left, Bookmark right; Belarusian VoiceOver labels with bookmark state; light haptic on bookmark. |
| #17 | Translated words are bold primary text, not red; accent only for interactive elements (Aleh, 2026-11-05). |
| #18 | Toast on `tertiarySystemBackground` so it is visible in dark mode; space + `&nbsp;` collapse to one space. |
| #19 | Large headword heading with stress form and dictionary subtitle; nav-bar title only after scrolling. |
| #20 | SwiftSoup renderer instead of the WebKit HTML importer; semantic colours; Dynamic Type live. |
| #24 | The `skarnik.app/r/...` URL line under the subtitle is removed entirely (Aleh, 2026-11-05): it duplicated Share, was below the minimum font size, and could route back into the app. Attribution to skarnik.by stays on the About screen. |
| #25 | «На́ціск» slot reserved while loading; be→ru menu of headword + synonyms kept (Aleh, 2026-11-05). |
| #22 | Loading and error states centred; error has a «Паспрабаваць яшчэ» retry; nested error `ScrollView` removed; network error text no longer says «try later». |

Still open at the time of writing:

- #23: Share as a popover on iPad, and the word included in the shared text
  («добразычлівасць — https://skarnik.app/r/belrus/27890»).

Update this doc when those land.
