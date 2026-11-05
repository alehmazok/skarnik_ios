# Націск (Word Stress / Spelling) Feature Spec

## Overview

From the word details screen the user taps «На́ціск» to see the stress marks and the
declension/conjugation table of a Belarusian word.

Data comes from two sources, tried in order:

1. **starnik.by** (primary, `api` source): live JSON lookup plus an HTML scrape.
2. **skarnik_admin** (fallback, `cloud` source): Skarnik's own Django/MariaDB API, with tables
   imported once from GrammarDB. Used when starnik.by has no exact match or is unreachable.

This mirrors the Flutter app; the shared reference is `shared/stress_spec.md` in
skarnik-flutter. If the two disagree, the code wins and both docs should be fixed.

Code:

| Piece | File |
|---|---|
| Candidate words | `SKSkarnikTranslation.belWords` in `Skarnik/Shared/SKTranslationSource.swift` |
| Toolbar control | `spellingControl` in `Skarnik/SwiftUI/SKWordDetailsView.swift` |
| Tap → resolve → picker / alert / push | `openSpellingWord` in `Skarnik/SKWordDetailsViewController.swift` |
| Two-source orchestration | `SKStressResolver` in `Skarnik/Shared/SKStressResolver.swift` |
| starnik.by backend | `SKStarnikStressBackend` in `Skarnik/SKStarnikByController.swift` |
| skarnik_admin backend | `SKCloudStressBackend` in `Skarnik/Shared/SKStressResolver.swift` |
| Table screen | `Skarnik/SwiftUI/WordStress/SKWordStressView(Model).swift` |
| Tests | `SKStressResolverTests`, `SKStarnikByControllerTests`, `SKWordDetailsViewControllerTests` |

---

## User flow

1. The word details screen loads a translation.
2. While it loads, a disabled «На́ціск» placeholder holds the button's slot in the nav bar, so
   nothing shifts when the translation arrives (#25).
3. After load, the button is shown **only** if there are candidate words (Step 1). With no
   candidates it is hidden, not disabled.
4. One candidate: the button acts directly. Two or more: the button is a `Menu` listing the
   candidates; the user picks one. In be→ru this menu holds the headword plus the Belarusian
   synonyms from the article (kept on purpose, decided by Aleh 2026-11-05).
5. On tap: log `stress_clicked` with the chosen word (before any network call).
6. Resolve the word to stress entries (Step 2):
   - **one entry** → push the stress table screen;
   - **several entries** (homonyms) → action sheet to pick one, then push;
   - **not found** → alert «Інфармацыя аб націску для гэтага слова не знойдзена.»;
   - **error** (both sources failed) → alert «Адбылася памылка падчас загрузкі інфармацыі аб націску.»
7. The table screen fetches the table from the source the entry came from (Step 3).

---

## Step 1: Candidate Belarusian words (`belWords`)

Multi-word phrases (anything containing a space) are never candidates. The result is
de-duplicated and sorted case-insensitively.

### bel→rus
- The headword itself.
- Plus Belarusian synonyms in the article: text of `font`/`span` elements coloured `#831b03`
  (via the `color` attribute or inline `style`), split on `,`, trimmed, and kept only if the word
  exists in the local vocabulary index (ТСБМ or bel→rus).

### ТСБМ (bel_definition)
- The headword itself.

### rus→bel
- If the HTML has `data-word` attributes (added by skarnik_admin's `find_inner_stress` /
  `fix_inner_stress`): their values, kept only if present in the local index (ТСБМ or bel→rus).
- Otherwise: the `#831b03`-coloured words, same rule as bel→rus.

---

## Step 2: Resolve the word (`SKStressResolver.resolveWordList`)

Each backend returns entries in one domain shape:

```swift
struct SKStressWordEntry {
    let id: Int              // unique only within its source
    let lemma: String        // unstressed, used for exact matching
    let word: String         // stressed, used for display
    let tableName: String?   // part of speech, e.g. "Nouns"
    let source: SKStressSource // .api (starnik.by) or .cloud (skarnik_admin)
}
```

Cascade (results of the two sources are never merged):

1. Ask the primary. Keep entries whose `lemma == word` (exact, case-sensitive).
   If any remain → **success** with those entries.
2. If the primary had no exact match, or threw (network/decoding) → ask the fallback with the
   same exact-match filter. Entries left → **success**; none → **notFound**.
3. Fallback threw → **error**.

### Primary: starnik.by

```
GET https://starnik.by/api/wordList?lemma={percent-encoded word}
```

```json
{ "word_list": [ { "lemma": "слова", "word": "сло́ва", "id": 12345, "table_name": "Nouns" } ],
  "form_list": [ ... ] }
```

`word_list[]` maps 1:1 (`lemma` unstressed, `word` stressed). `form_list` is ignored.

### Fallback: skarnik_admin

```
GET https://skarnik.play.of.by/api/stress_words/?word={percent-encoded lowercased word}
```

```json
[ { "id": 456, "word": "слова", "lemma": "сло́ва", "table_name": null } ]
```

Field names are **inverted** compared with starnik.by: here `word` is unstressed and `lemma` is
stressed. The backend swaps them when mapping, so the domain model means the same thing for both
sources. Getting this wrong makes cloud exact matches silently never match.

### Homonym picker

Homonyms (e.g. «а» as noun, conjunction, preposition…) share a lemma but have different ids and
tables, so the app never guesses. With more than one entry an action sheet is shown:

- title «Націск і арфаграфія», message «для прагляду, калі ласка, абярыце слова»;
- one action per entry: `"{stressed word} — {part of speech}"`, or just the word when there is
  no `table_name`. Parts of speech come from `SKLocalization.wordType` (`Nouns` → «назоўнік»,
  etc.; unknown values are shown raw);
- «Адмена» cancels. On iPad the sheet is a centred popover with no arrow.

---

## Step 3: Stress table (`SKStressResolver.stressTable`)

The table is fetched from the entry's own `source`; ids mean nothing in the other source, so
there is no cross-source retry. Empty rows → **notFound**; a thrown error → **error**.

### Primary: starnik.by

```
GET https://starnik.by/pravapis/{id}
```

HTML, parsed with SwiftSoup:

1. First `<table>` inside an element with class `wrapper`.
2. Each `<tr>` with exactly two `<td>`: `td[0]` inner HTML = title (grammatical label),
   `td[1]` inner HTML = content (forms with stress marks). Other rows are skipped.

### Fallback: skarnik_admin

```
GET https://skarnik.play.of.by/api/stress_words/{id}/
```

```json
{ "id": 456, "rows": [ { "title": "<html>", "content": "<html>" } ] }
```

---

## UI: stress table screen (`SKWordStressView`)

- Title «Націск».
- Spinner while loading.
- On **notFound**: «Інфармацыя аб націску для гэтага слова не знойдзена.»; on **error**:
  «Адбылася памылка падчас загрузкі інфармацыі аб націску.» (centred, max 300 pt wide).
- On success: plain list, two equal-width columns (title, content), on
  `secondarySystemBackground`.
- Cells are rendered with `SKTranslationRenderer` in `.compact` layout (SwiftSoup, no WebKit),
  following Dynamic Type and Bold Text, so stress marks and bold forms display correctly.

---

## Notes

- No caching of word lists or tables.
- Analytics: only `stress_clicked` with parameter `word` (the candidate tapped), sent on tap.
- `id` is an integer path segment and is only valid against its own source.
