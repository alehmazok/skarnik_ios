//
//  NetworkUITests.swift
//  SkarnikUITests
//
//  Journeys that need the internet: translation, share, stress tables. They run on BrowserStack
//  devices, not in the simulator CI job. Assertions check structure, never translation text.
//

import XCTest

final class NetworkUITests: SkarnikUITestCase {

    /// Nothing is downloaded, so the translation comes from Supabase (or the admin API after it).
    func testTranslationLoadsFromNetwork() {
        openWord("мова", in: .belRus)
        let source = waitForTranslation()
        XCTAssertTrue(["supabase", "api"].contains(source), "Unexpected translation source «\(source)»")
        XCTAssertFalse(element("wordDetailsError").exists)
        XCTAssertFalse(element("wordDetailsLoading").exists)
        XCTAssertTrue(element("wordDetails.share").isEnabled, "Share stays disabled after loading")
    }

    func testShareSheetOpensAndCloses() {
        openWord("добразычлівасць", in: .belRus)
        waitForTranslation()
        let share = waitFor(element("wordDetails.share"), "No share button")
        share.tap()

        let sheet = shareSheet()
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Share sheet did not open")
        closeShareSheet(sheet)
        XCTAssertTrue(waitUntilGone(sheet, timeout: 10), "Share sheet did not close")
        XCTAssertTrue(share.isHittable, "Word screen is not back after closing the share sheet")
    }

    /// The one-time word link hint: shows on the first translation with tappable Belarusian words,
    /// closes with «Зразумела» and does not come back on the next one.
    func testWordLinkHintShowsOnce() {
        app.terminate()
        launch(reset: true, extraArguments: ["-showTips"])
        openWord("вопрос", in: .rusBel)
        waitForTranslation()
        let hint = app.staticTexts["Націсніце на беларускае слова, каб адкрыць яго пераклад"]
        waitFor(hint, timeout: 10, "The word link hint did not show")
        waitFor(app.buttons["Зразумела"], "No «Зразумела» button on the hint").tap()
        XCTAssertTrue(waitUntilGone(hint, timeout: 5), "The hint did not close")

        goBack()
        openWord("время", in: .rusBel)
        waitForTranslation()
        XCTAssertFalse(hint.waitForExistence(timeout: 3), "The hint showed a second time")
    }

    /// «На́ціск» opens the stress and spelling table from starnik.by (or the admin API).
    func testStressTableOpens() {
        // A ТСБМ headword is its own stress candidate, so the button opens the lookup directly.
        openFirstDictionaryWord(.tsbm)
        waitForTranslation()
        waitFor(element("wordDetails.stress"), "No «На́ціск» button").tap()

        let stress = element("wordStress")
        let deadline = Date().addingTimeInterval(30)
        while !stress.exists && Date() < deadline {
            // Homographs: an action sheet asks which word is meant.
            let picker = app.sheets.firstMatch
            if picker.exists {
                let choice = picker.buttons.matching(NSPredicate(format: "label != %@", "Адмена")).firstMatch
                XCTAssertTrue(choice.exists, "Word picker has no choices")
                choice.tap()
                continue
            }
            let alert = app.alerts.firstMatch
            if alert.exists {
                XCTFail("Stress lookup failed: \(alert.label) \(alert.staticTexts.allElementsBoundByIndex.map(\.label))")
                return
            }
            _ = stress.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(stress.exists, "Stress table did not open")

        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count > 0"),
                                               object: stress.descendants(matching: .cell))
        let result = XCTWaiter().wait(for: [loaded], timeout: 30)
        XCTAssertFalse(element("wordStress.error").exists, "Stress table error: \(element("wordStress.error").label)")
        XCTAssertEqual(result, .completed, "Stress table has no rows")

        goBack()
        waitFor(element("wordDetails"), "Did not return to the word")
    }

    // MARK: - Share sheet

    /// The system share sheet has no stable identifier across iOS versions; any of these is it.
    private func shareSheet() -> XCUIElement {
        let candidates = [
            app.otherElements["ActivityListView"],
            app.navigationBars["UIActivityContentView"],
            app.otherElements["UIActivityContentView"]
        ]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let found = candidates.first(where: { $0.exists }) {
                return found
            }
            _ = candidates[0].waitForExistence(timeout: 1)
        }
        return candidates[0]
    }

    private func closeShareSheet(_ sheet: XCUIElement) {
        let labels = ["Close", "Закрыць", "Cancel", "Скасаваць"]
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        if close.waitForExistence(timeout: 3) {
            close.tap()
        } else {
            sheet.swipeDown(velocity: .fast)
        }
    }
}
