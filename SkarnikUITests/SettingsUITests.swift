//
//  SettingsUITests.swift
//  SkarnikUITests
//
//  Налады: offline dictionary rows, article colours, analytics toggle, About. Offline-safe.
//

import XCTest

final class SettingsUITests: SkarnikUITestCase {

    func testSettingsRows() {
        openTab(.settings)

        // Nothing is downloaded on a fresh install.
        for path in ["rusbel", "belrus", "tsbm"] {
            let status = waitFor(element("settings.offline.\(path).status"), "No offline row for \(path)")
            XCTAssertEqual(status.label, "Спампаваць для афлайн доступу", path)
        }

        // Analytics was declined on launch, so the toggle is off; it switches both ways.
        let analytics = waitFor(app.switches["settings.analytics"], "No analytics toggle")
        XCTAssertEqual(analytics.value as? String, "0")
        flip(analytics)
        XCTAssertEqual(analytics.value as? String, "1")
        flip(analytics)
        XCTAssertEqual(analytics.value as? String, "0")

        // Article colours: switch to Skarnik red, and it stays after leaving the screen.
        let colors = waitFor(element("settings.articleColors"), "No article colours picker")
        XCTAssertTrue(describe(colors).contains("Сістэмныя"), "Picker shows «\(describe(colors))»")
        colors.tap()
        waitFor(app.buttons["Чырвоныя Скарніка"], "No «Чырвоныя Скарніка» option").tap()
        XCTAssertTrue(describe(colors).contains("Чырвоныя Скарніка"), "Picker shows «\(describe(colors))»")
        openTab(.bookmarks)
        openTab(.settings)
        XCTAssertTrue(describe(element("settings.articleColors")).contains("Чырвоныя Скарніка"))

        // About opens and goes back.
        waitFor(app.staticTexts["Пра Скарнік"], "No About row").tap()
        waitFor(app.navigationBars["Пра Скарнік"], "About did not open")
        goBack()
        waitFor(element("settings.articleColors"), "Did not return to Settings")
    }

    /// SwiftUI Toggle: tapping the row's centre may miss the switch, so tap the switch itself.
    private func flip(_ toggle: XCUIElement) {
        let inner = toggle.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
    }

    private func describe(_ element: XCUIElement) -> String {
        "\(element.label) \(element.value as? String ?? "")"
    }
}
