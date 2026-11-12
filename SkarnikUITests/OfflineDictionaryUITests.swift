//
//  OfflineDictionaryUITests.swift
//  SkarnikUITests
//
//  Download the explanatory dictionary, read a word from the offline copy, delete it.
//  Needs the internet (BrowserStack only); the full download is the slow part.
//

import XCTest

final class OfflineDictionaryUITests: SkarnikUITestCase {

    func testDownloadReadOfflineCopyAndDelete() {
        openSettings()
        let name = waitFor(element("settings.offline.tsbm.name"), "No ТСБМ offline row")
        let status = element("settings.offline.tsbm.status")
        XCTAssertEqual(status.label, "Спампаваць для афлайн доступу")

        name.tap()
        let downloaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "Спампавана"), object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [downloaded], timeout: 600), .completed,
                       "Download did not finish: «\(status.label)»")

        closeSettings()
        // The offline copy is the first source in the chain (offline db → Supabase → admin API).
        openFirstDictionaryWord(.tsbm)
        XCTAssertEqual(waitForTranslation(), "local", "The word was not read from the offline copy")
        goBack()

        openSettings()
        waitFor(element("settings.offline.tsbm.delete"), "No delete button").tap()
        let alert = waitFor(app.alerts.firstMatch, "No delete confirmation")
        alert.buttons["Так"].tap()
        let deleted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Спампаваць для афлайн доступу"),
                                                object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [deleted], timeout: 30), .completed,
                       "Offline copy was not deleted: «\(status.label)»")
    }
}
