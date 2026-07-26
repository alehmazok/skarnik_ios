# Word Widget — Cross-Platform Spec

Source of truth: iOS `WordWidget/` target (Skarnik iOS app). This doc describes behavior
for the Android/Flutter team to replicate, independent of iOS implementation details.

## 1. Overview

Home-screen widget showing a random Belarusian word + its Russian translation. Tapping
the widget deep-links into the app, opening that word's detail page.

- Sizes: small, medium
- Refresh: hourly (fetch one new word/translation pair per refresh)
- No user-configurable settings (see §7)

## 2. Data source

- Word is picked from the local offline word index (SQLite `vocabulary.db` on iOS),
  filtered by vocabulary/direction type.
- Direction enum (iOS `ESKVocabularyType`, raw values matter for the deep link, §5):
  - `0` = history
  - `1` = rus_bel (Russian → Belarusian)
  - `2` = bel_rus (Belarusian → Russian)
  - `3` = bel_definition
  - `4` = all
- **Widget always uses `bel_rus` (2)** — direction is hardcoded, not user-selectable.
- Random pick query (iOS):
  ```sql
  SELECT word_id, word FROM vocabulary WHERE lang_id=? ORDER BY random() LIMIT 1
  ```
- Translation text is fetched via whatever translation lookup path the platform has
  (iOS: API → Supabase → HTML-scrape fallback chain). Android should use its own
  equivalent remote/local lookup — only the resulting `(word, translation)` pair matters
  to the rest of this spec.

## 3. Selection / filtering algorithm

This is the non-obvious part — port the logic, not just "pick a random word."

**Retry loop, max 30 attempts per widget refresh:**

1. Pick a random word (§2).
2. **Recently-shown check:** skip (retry) if this word was already shown to this device
   within the **last month** — *unless* the stored copy is flagged "similar" (see step 3),
   in which case it stays skipped even past a month. In other words:
   - Shown within last month → always treated as "seen", skip.
   - Shown more than a month ago → eligible for reuse **only if** it was *not* flagged similar back when it was shown.
3. Fetch the translation, then compute a **similarity score** between the word and its
   translation:
   - Normalize both strings: lowercase, trim whitespace, then apply Russian/Belarusian
     cognate-collapsing letter substitutions (in order): `о→а`, `щ→шч`, `ъ→'`, `ў→у`,
     unify apostrophe variants (`❛ ❜ \` ‛ ’ ‘` → `'`), `ся→ца`, `ый→і`, `ы→і`, `ий→і`,
     `и→і`, `т→ц`, `ё→е`.
   - For translation (may contain multiple senses separated by newlines and/or a dash
     `­­–‑—‒`), take the first sense of each line, normalize the same way, compute
     Levenshtein distance to the word, keep the **minimum** distance across all senses.
   - `similarity = word.length / levenshteinDistance` (treat as infinite if distance is 0,
     i.e. identical strings).
   - `isSimilar = similarity > 1.8`.
   - If `isSimilar` and retries remain, **reject and retry** — this avoids showing widget
     entries where the "translation" is basically the same word (no educational value
     for a bilingual dictionary widget).
4. **Persist every fetched entry** (even rejected/similar ones) to history storage
   regardless of outcome, so future picks can compare against it.
5. If all 30 attempts are exhausted, or the translation fetch fails outright: fall back
   to a hardcoded sample word/translation pair (iOS: `"халэмус"` → `"гибель, конец"`).

## 4. History storage

- Per-device, keyed by `[vocabularyDirection: [wordId: entry]]`.
- Entry shape: `{ language, wordId, word, translation, createdAt }`.
- iOS persists this as JSON in UserDefaults, **scoped to the widget process only** — no
  App Group is configured, so the widget and the main app do **not** share this storage
  (or any other UserDefaults/preferences). Android can use an equivalent widget-local
  store (SharedPreferences/DataStore) with no expectation of sharing with the main app.

## 5. Deep link contract

- URI shape: `skarnik://word?id={wordId}&lang={directionRawValue}`
- Validation rules (mirror these — a link failing any of them is rejected/no-op):
  - Scheme must be `skarnik`
  - Host must be `word`
  - `id` param required, must parse as a number
  - `lang` param required, must parse as a number **and** map to a valid direction
    value (0–4 per §2)
- On iOS this is handled in `SceneDelegate`, both cold start (via launch options) and
  warm/background (via scene URL context callback), and logs an analytics event with
  the resolved word and app state (`coldStart` / `background`).
- Android should implement the equivalent: widget tap → deep link/intent into the word
  detail screen, using the same `id`/`lang` semantics (exact scheme/intent format is
  Android's call, but keep the id/direction semantics identical so dictionary lookup
  and analytics stay consistent across platforms).

## 6. UI content

Layout below is the current iOS presentation — a reference, not a strict visual spec
to match pixel-for-pixel:

- Word: bold, uppercase, accent color, up to 2 lines.
- Translation: regular weight, secondary/muted color, below the word. May be
  multi-line (multiple senses from the translation source).
- Whole widget body is tappable (deep link, §5).
- Widget gallery title/description strings (Belarusian):
  - Title: "Слова дня"
  - Description: "Выпадковае слова і яго пераклад."

## 7. Configuration

No user-facing configuration. iOS registers a widget configuration intent, but it only
carries the gallery title/description — zero configurable parameters. Direction is
hardcoded to `bel_rus` (§2).
