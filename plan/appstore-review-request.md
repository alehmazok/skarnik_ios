# App Store Review Request — Issues & Plan

## Current Behavior (`SKAppstoreReviewController`)

- Triggered on every successful word load (`SKWordDetailsViewModel`)
- Counter increments each load; prompt fires at count ≥ 5
- After prompt: counter resets to 0, current version saved to `lastVersionPrompted`
- Guard: skip if `lastVersionPrompted == currentVersion`

## Problems

1. **Prompts every new version** — user who already left 5 stars on v51 gets prompted again on v52. No reason to ask again.
2. **Counter carries across versions** — 3 words in v51 + 2 in v52 = prompt fires on v52 immediately. Feels jarring.
3. **Threshold too low** — 5 word loads can happen in first 2 minutes of use.
4. **No sentiment signal** — fires after any successful load, not after a positive experience.
5. `UserDefaults.synchronize()` is deprecated no-op since iOS 12.

## Proposed Fix

**Core idea:** prompt once ever (or once per long time gap), not once per version.

### Option A — Prompt once, never again
- Replace `lastVersionPrompted` with `hasEverPrompted: Bool`
- Once prompt fires → set flag → never prompt again
- Simple, zero annoyance

### Option B — Prompt with time gap (recommended)
- Replace `lastVersionPrompted` with `lastPromptedDate: Date`
- Only prompt if `lastPromptedDate` is nil OR > 180 days ago
- Raise threshold from 5 to ~15–20 word loads
- Reset counter to 0 on each fresh 180-day window

### Option C — Prompt on positive signal only
- Don't count every word load
- Count only sessions where user viewed 3+ words (engaged session)
- Prompt after 5 such sessions with time gap

## Minimal Code Change (Option B sketch)

```swift
class SKAppstoreReviewController {

    static let wordsCompletedCountKey = "SKAppstoreReviewController.wordsCompletedCount"
    static let lastPromptedDateKey    = "SKAppstoreReviewController.lastPromptedDate"
    static let minDaysBetweenPrompts  = 180
    static let threshold              = 15

    class func requestReview() {
        let count = 1 + UserDefaults.standard.integer(forKey: wordsCompletedCountKey)
        UserDefaults.standard.set(count, forKey: wordsCompletedCountKey)

        guard count >= threshold else { return }

        if let last = UserDefaults.standard.object(forKey: lastPromptedDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
            guard daysSince >= minDaysBetweenPrompts else { return }
        }

        Task {
            try? await Task.sleep(seconds: 5.0)
            guard await UIApplication.shared.applicationState == .active else { return }
            guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            await SKStoreReviewController.requestReview(in: scene)
            UserDefaults.standard.set(0, forKey: wordsCompletedCountKey)
            UserDefaults.standard.set(Date.now, forKey: lastPromptedDateKey)
        }
    }
}
```

## Notes
- Apple system cap: 3 prompts per 365 days regardless — but self-limit more aggressively
- App Store Guidelines §5.6.1: no excessive or ill-timed prompts
- Remove all `UserDefaults.synchronize()` calls (deprecated)
