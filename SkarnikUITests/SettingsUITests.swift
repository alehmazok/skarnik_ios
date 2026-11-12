//
//  SettingsUITests.swift
//  SkarnikUITests
//
//  Налады: offline dictionary rows, article colours, analytics toggle, About. Offline-safe.
//

import XCTest

final class SettingsUITests: SkarnikUITestCase {

    func testSettingsRows() {
        openSettings()

        // Nothing is downloaded on a fresh install.
        for path in ["rusbel", "belrus", "tsbm"] {
            let status = waitFor(element("settings.offline.\(path).status"), "No offline row for \(path)")
            XCTAssertEqual(status.label, "Спампаваць для афлайн доступу", path)
        }

        // Analytics was declined on launch, so the toggle is off; it switches both ways.
        let analytics = waitFor(app.switches["settings.analytics"], "No analytics toggle")
        XCTAssertEqual(analytics.value as? String, "0")
        flip(analytics)
        XCTAssertTrue(waitForValue(analytics, "1"), "Analytics toggle did not switch on")
        flip(analytics)
        XCTAssertTrue(waitForValue(analytics, "0"), "Analytics toggle did not switch off")

        // Article colours: switch to Skarnik red, and it stays after leaving the screen.
        let colors = waitFor(element("settings.articleColors"), "No article colours picker")
        XCTAssertTrue(describe(colors).contains("Сістэмныя"), "Picker shows «\(describe(colors))»")
        colors.tap()
        waitFor(app.buttons["Чырвоныя Скарніка"], "No «Чырвоныя Скарніка» option").tap()
        XCTAssertTrue(describe(colors).contains("Чырвоныя Скарніка"), "Picker shows «\(describe(colors))»")
        closeSettings()
        openSettings()
        XCTAssertTrue(describe(element("settings.articleColors")).contains("Чырвоныя Скарніка"))

        // About opens and goes back.
        waitFor(app.staticTexts["Пра Скарнік"], "No About row").tap()
        waitFor(app.navigationBars["Пра Скарнік"], "About did not open")
        goBack()
        waitFor(element("settings.articleColors"), "Did not return to Settings")
    }

    /// iOS 26: «Радок пошуку ўнізе» switches back to one Пошук tab with the field at the top, and on again.
    func testSearchBarPlacementSwitch() throws {
        guard hasSeparateSearchTab else {
            throw XCTSkip("The bottom search tab and its switch exist only on iOS 26")
        }
        let tabBar = app.tabBars.firstMatch
        func tab(_ tab: Tab) -> XCUIElement {
            tabBar.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", tab.rawValue)).firstMatch
        }
        waitFor(tab(.history), "No Гісторыя tab by default")

        openSettings()
        let toggle = waitFor(app.switches["settings.searchBarAtBottom"], "No search bar placement switch")
        XCTAssertEqual(toggle.value as? String, "1")
        flip(toggle)
        XCTAssertTrue(waitForValue(toggle, "0"), "Switch did not turn off")
        closeSettings()

        // Old layout: Пошук is the start tab, with the field at the top and history below it.
        XCTAssertTrue(waitUntilGone(tab(.history), timeout: 5), "Гісторыя tab still shown")
        XCTAssertEqual(tabBar.buttons.count, 3)
        waitFor(searchField, "No search field on the start screen")
        waitFor(element("history.empty"), "No history on the start screen")

        // The choice survives a relaunch.
        relaunchKeepingState()
        XCTAssertFalse(tab(.history).waitForExistence(timeout: 3), "Гісторыя tab back after relaunch")

        openSettings()
        let toggleAgain = waitFor(app.switches["settings.searchBarAtBottom"], "No search bar placement switch")
        flip(toggleAgain)
        XCTAssertTrue(waitForValue(toggleAgain, "1"), "Switch did not turn on")
        closeSettings()
        waitFor(tab(.history), "Гісторыя tab did not come back")
        XCTAssertEqual(tabBar.buttons.count, allTabs.count)
    }

    /// A SwiftUI Toggle's element spans the whole row; tapping its centre hits the label, not the
    /// switch, so tap near the trailing edge where the switch is.
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [changed], timeout: 5) == .completed
    }

    private func describe(_ element: XCUIElement) -> String {
        "\(element.label) \(element.value as? String ?? "")"
    }
}
