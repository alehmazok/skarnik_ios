//
//  SearchUITests.swift
//  SkarnikUITests
//
//  Search journeys against the bundled index. Offline-safe: nothing here waits for a translation.
//

import XCTest

final class SearchUITests: SkarnikUITestCase {

    func testLaunchShowsTabsAndSearchOpensWord() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertEqual(tabBar.buttons.count, 4)
        for tab in [Tab.search, .bookmarks, .dictionaries, .settings] {
            let button = tabBar.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", tab.rawValue)).firstMatch
            XCTAssertTrue(button.exists, "Missing tab «\(tab.rawValue)»")
        }
        // Search is the start tab and a fresh install has no history.
        waitFor(searchField, "Search field missing")
        waitFor(element("history.empty"), "History placeholder missing on a fresh install")

        openWord("мова", in: .belRus)
    }

    /// «кара» is in all three dictionaries; each entry shows its own subtitle.
    func testEachDictionaryOpensWithItsSubtitle() {
        for dictionary in [Dictionary.rusBel, .belRus, .tsbm] {
            search("кара")
            searchResult("кара", in: dictionary).tap()
            assertWordScreen("кара", in: dictionary)
            goBack()
        }
    }

    func testExtraLetterKeysInsertLetters() {
        search("сям")
        waitFor(element("search.key.'"), "Extra letter row missing").tap()
        searchField.typeText("я")
        XCTAssertEqual(searchField.value as? String, "сям'я")
        _ = searchResult("сям'я", in: .belRus)

        for key in ["ў", "і", "и", "щ", "ъ"] {
            search("а")
            element("search.key.\(key)").tap()
            XCTAssertEqual(searchField.value as? String, "а\(key)", "Key «\(key)»")
        }
    }

    /// Russian-layout letters still find the Belarusian word (и → і).
    func testRussianLayoutLettersFindBelarusianWord() {
        search("прывитанне")
        _ = searchResult("прывітанне", in: .belRus)
    }

    func testUnknownWordShowsSearchHint() {
        search("qzxqzxqzx")
        waitFor(element("search.noResults"), "No-results hint missing")
        XCTAssertFalse(element("search.result").exists)
    }

    /// Opened words go to the top of history, once each, and history survives a relaunch.
    func testHistoryKeepsOpenedWordsOnceAcrossLaunches() {
        openWord("мова", in: .belRus)
        goBack()
        openWord("кара", in: .tsbm)
        goBack()
        openWord("мова", in: .belRus)
        goBack()
        cancelSearch()

        waitFor(element("history.row"), "History is empty")
        assertHistory(["мова", "кара"])

        relaunchKeepingState()
        waitFor(element("history.row"), "History was lost after relaunch")
        assertHistory(["мова", "кара"])

        elements("history.row").element(boundBy: 1).tap()
        assertWordScreen("кара", in: .tsbm)
    }

    private func assertHistory(_ words: [String], file: StaticString = #filePath, line: UInt = #line) {
        let rows = elements("history.row")
        XCTAssertEqual(rows.count, words.count, "History rows", file: file, line: line)
        for (index, word) in words.enumerated() {
            let row = rows.element(boundBy: index)
            XCTAssertTrue(row.label.hasPrefix(word) || row.staticTexts[word].exists,
                          "History row \(index) is «\(row.label)», expected «\(word)»", file: file, line: line)
        }
    }
}
