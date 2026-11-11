//
//  SkarnikUITestCase.swift
//  SkarnikUITests
//
//  Shared launch and navigation helpers. Every test starts from a fresh install state
//  (`-uiTesting -uiTestingReset`, handled by `SKUITesting` in the app): no history, bookmarks,
//  settings or offline dictionaries, and the analytics consent sheet shows and is declined.
//
//  Suites (see docs/browserstack.md):
//  - Offline-safe journeys (Search, Bookmarks, Browse, DeepLink, Settings) run on the CI simulator
//    and on BrowserStack. They read the bundled SQLite index only.
//  - NetworkUITests and OfflineDictionaryUITests need the internet; BrowserStack only.
//  - NoNetworkUITests runs only in the BrowserStack build with `networkProfile: no-network`.
//

import XCTest

class SkarnikUITestCase: XCTestCase {

    var app: XCUIApplication!

    enum Tab: String {
        /// iOS 26 only: history has its own start tab (see `hasSeparateSearchTab`).
        case history = "Гісторыя"
        case search = "Пошук"
        case bookmarks = "Закладкі"
        case dictionaries = "Слоўнікі"
        case settings = "Налады"
    }

    /// Dictionary names as the app shows them: the search row caption and the word screen subtitle.
    enum Dictionary {
        case rusBel, belRus, tsbm

        var rowCaption: String {
            switch self {
            case .rusBel: return "Руска-Беларускі"
            case .belRus: return "Беларуска-Рускі"
            case .tsbm: return "Тлумачальны"
            }
        }

        var subtitle: String {
            switch self {
            case .rusBel: return "Пераклад на беларускую мову"
            case .belRus: return "Пераклад на рускую мову"
            case .tsbm: return "Тлумачэнне слова"
            }
        }

        var segment: String {
            switch self {
            case .rusBel: return "Рус-Бел"
            case .belRus: return "Бел-Рус"
            case .tsbm: return "Тлумачальны"
            }
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        launch(reset: true)
    }

    // MARK: - Launch

    /// `reset: false` keeps what the previous launch stored (history, bookmarks, settings).
    func launch(reset: Bool) {
        app.launchArguments = ["-uiTesting"] + (reset ? ["-uiTestingReset"] : [])
        app.launch()
        if reset {
            dismissAnalyticsConsent()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "Tab bar did not appear")
    }

    func relaunchKeepingState() {
        app.terminate()
        launch(reset: false)
    }

    /// A reset launch always shows the consent sheet. Declining keeps analytics off on test devices.
    private func dismissAnalyticsConsent() {
        let decline = app.buttons["analyticsConsent.decline"]
        if decline.waitForExistence(timeout: 10) {
            decline.tap()
        }
    }

    // MARK: - Queries

    /// Any element type: SwiftUI exposes the same view as a button, cell or other element
    /// depending on the iOS version.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func elements(_ identifier: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10, _ message: String,
                 file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message, file: file, line: line)
        return element
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// Accessibility label without the combining stress accent (U+0301), so «мо́ва» reads as «мова».
    func plain(_ label: String) -> String {
        label.replacingOccurrences(of: "\u{301}", with: "")
    }

    // MARK: - Navigation

    func openTab(_ tab: Tab) {
        // BEGINSWITH: a tab badge, if any, extends the label.
        let button = app.tabBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", tab.rawValue)).firstMatch
        waitFor(button, "Missing tab «\(tab.rawValue)»").tap()
    }

    func goBack() {
        let back = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
        waitFor(back, "No back button").tap()
    }

    // MARK: - Search

    /// iOS 26: Гісторыя is the start tab and search is a separate tab with the field at the bottom.
    /// iOS 17–25: one Пошук tab shows history and the search field at the top.
    var hasSeparateSearchTab: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// The tabs in tab bar order.
    var allTabs: [Tab] {
        hasSeparateSearchTab ? [.history, .bookmarks, .dictionaries, .settings, .search]
                             : [.search, .bookmarks, .dictionaries, .settings]
    }

    var searchField: XCUIElement { app.searchFields.firstMatch }

    /// The search screen always shows either results or the search hint.
    private var isOnSearchScreen: Bool {
        element("search.result").exists || element("search.noResults").exists
    }

    /// Replaces whatever is in the search field with `text`.
    func search(_ text: String) {
        if hasSeparateSearchTab && !isOnSearchScreen {
            openTab(.search)
        }
        waitFor(searchField, "Search field missing")
        searchField.tap()
        if let current = searchField.value as? String, !current.isEmpty,
           current != searchField.placeholderValue {
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        searchField.typeText(text)
    }

    /// The search result row for `word` from `dictionary`.
    func searchResult(_ word: String, in dictionary: Dictionary, timeout: TimeInterval = 10) -> XCUIElement {
        waitFor(element("search.result"), timeout: timeout, "No search results")
        // The row's label combines the word and the dictionary caption.
        let byLabel = elements("search.result").matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS[c] %@", word, dictionary.rowCaption
        )).firstMatch
        if byLabel.waitForExistence(timeout: 2) {
            return byLabel
        }
        // Fallback for systems that expose the row's texts as children instead.
        let rows = elements("search.result").allElementsBoundByIndex
        for row in rows where row.staticTexts[word].exists
            && row.staticTexts.matching(NSPredicate(format: "label ==[c] %@", dictionary.rowCaption)).count > 0 {
            return row
        }
        XCTFail("No result «\(word)» in \(dictionary.rowCaption)")
        return byLabel
    }

    /// Leaves search and shows the history list (on iOS 26 that is the Гісторыя tab).
    func showHistory() {
        cancelSearch()
        if hasSeparateSearchTab {
            openTab(.history)
        }
    }

    /// Cancels search mode so the history list shows again.
    func cancelSearch() {
        let labels = ["Cancel", "Скасаваць", "Адмена", "Отмена", "Close"]
        let cancel = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        if cancel.waitForExistence(timeout: 3) {
            cancel.tap()
        } else {
            let anywhere = app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
            waitFor(anywhere, timeout: 2, "No Cancel button for search").tap()
        }
    }

    // MARK: - Word screen

    /// Waits for the word screen and checks its header.
    func assertWordScreen(_ word: String, in dictionary: Dictionary,
                          file: StaticString = #filePath, line: UInt = #line) {
        waitFor(element("wordDetails"), "Word screen did not open", file: file, line: line)
        let headword = waitFor(element("wordDetails.headword"), "No headword", file: file, line: line)
        // Homographs carry every stressed form: «ка́ра | кара́».
        let forms = plain(headword.label).components(separatedBy: " | ")
        XCTAssertTrue(forms.allSatisfy { $0 == word }, "Headword is «\(headword.label)», expected «\(word)»",
                      file: file, line: line)
        let subtitle = waitFor(element("wordDetails.subtitle"), "No dictionary subtitle", file: file, line: line)
        XCTAssertEqual(subtitle.label.lowercased(), dictionary.subtitle.lowercased(), "Subtitle", file: file, line: line)
    }

    /// Searches `word` and opens its entry in `dictionary`.
    func openWord(_ word: String, in dictionary: Dictionary) {
        search(word)
        searchResult(word, in: dictionary).tap()
        assertWordScreen(word, in: dictionary)
    }

    /// Waits until the translation text is shown (network or offline copy). Returns the source name.
    @discardableResult
    func waitForTranslation(timeout: TimeInterval = 45,
                            file: StaticString = #filePath, line: UInt = #line) -> String {
        let text = element("wordDetails.translation")
        let error = element("wordDetailsError")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if text.exists { break }
            if error.exists {
                XCTFail("Translation failed: \(error.label)", file: file, line: line)
                return ""
            }
            _ = text.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(text.exists, "Translation did not load", file: file, line: line)
        let source = element("wordDetails.source")
        return source.waitForExistence(timeout: 2) ? source.label : ""
    }

    // MARK: - Dictionaries tab

    /// Opens the first word of `dictionary` in the Слоўнікі tab and returns its text.
    @discardableResult
    func openFirstDictionaryWord(_ dictionary: Dictionary) -> String {
        openTab(.dictionaries)
        let segment = app.segmentedControls.buttons[dictionary.segment]
        waitFor(segment, "No «\(dictionary.segment)» segment").tap()
        let first = waitFor(element("vocabulary.word"), timeout: 20, "Dictionary list is empty")
        let label = first.label
        first.tap()
        waitFor(element("wordDetails"), "Word screen did not open")
        let subtitle = waitFor(element("wordDetails.subtitle"), "No dictionary subtitle")
        XCTAssertEqual(subtitle.label.lowercased(), dictionary.subtitle.lowercased())
        return label
    }
}
