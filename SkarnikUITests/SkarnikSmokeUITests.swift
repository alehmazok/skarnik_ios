//
//  SkarnikSmokeUITests.swift
//  SkarnikUITests
//
//  End-to-end smoke tests. They run on the CI simulator and on BrowserStack real devices
//  (see docs/browserstack.md), so they must stay offline-safe: search hits the bundled
//  SQLite index, and nothing asserts on translation text fetched from the network.
//

import XCTest

final class SkarnikSmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        dismissAnalyticsConsentIfShown()
    }

    func testTabBarShowsAllTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertEqual(tabBar.buttons.count, 4)

        tabBar.buttons["Слоўнікі"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))

        tabBar.buttons["Пошук"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }

    func testSearchAndOpenWord() {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("мова")

        let firstResult = app.buttons.matching(identifier: "search.result").firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 10), "No search results for «мова»")
        firstResult.tap()

        let details = app.descendants(matching: .any)["wordDetails"]
        XCTAssertTrue(details.waitForExistence(timeout: 10), "Word screen did not open")
    }

    // MARK: - Helpers

    /// The consent sheet shows on first launch only. Declining keeps analytics off on test devices.
    private func dismissAnalyticsConsentIfShown() {
        let decline = app.buttons["analyticsConsent.decline"]
        if decline.waitForExistence(timeout: 5) {
            decline.tap()
        }
    }
}
