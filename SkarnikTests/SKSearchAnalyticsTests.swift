//
//  SKSearchAnalyticsTests.swift
//  SkarnikTests
//

import XCTest
@testable import Skarnik

@MainActor
final class SKSearchAnalyticsTests: XCTestCase {

    // MARK: - Settle debounce (§3 of search_analytics_spec.md)

    func testSettle_firesSearchPerformed_afterDebounceElapses_whenResultsNonEmpty() {
        var performed: [(query: String, count: Int)] = []
        var noResults: [String] = []
        let viewModel = SKHistoryViewModel(
            onSearchPerformed: { query, count in performed.append((query, count)) },
            onSearchNoResults: { query in noResults.append(query) },
            onSearchResultTapped: { _, _, _ in }
        )

        viewModel.recordSearchSettle(query: "мова", resultCount: 5)

        wait(seconds: 0.7)

        XCTAssertEqual(performed.count, 1)
        XCTAssertEqual(performed.first?.query, "мова")
        XCTAssertEqual(performed.first?.count, 5)
        XCTAssertTrue(noResults.isEmpty)
    }

    func testSettle_firesSearchNoResults_whenResultCountIsZero() {
        var performed: [(query: String, count: Int)] = []
        var noResults: [String] = []
        let viewModel = SKHistoryViewModel(
            onSearchPerformed: { query, count in performed.append((query, count)) },
            onSearchNoResults: { query in noResults.append(query) },
            onSearchResultTapped: { _, _, _ in }
        )

        viewModel.recordSearchSettle(query: "zzzqqq", resultCount: 0)

        wait(seconds: 0.7)

        XCTAssertTrue(performed.isEmpty)
        XCTAssertEqual(noResults, ["zzzqqq"])
    }

    func testSettle_onlyLastSettleInTypingBurstFires() {
        var performed: [(query: String, count: Int)] = []
        let viewModel = SKHistoryViewModel(
            onSearchPerformed: { query, count in performed.append((query, count)) },
            onSearchNoResults: { _ in },
            onSearchResultTapped: { _, _, _ in }
        )

        // Three settles under 500ms apart, simulating "м" -> "мо" -> "мова" while typing.
        viewModel.recordSearchSettle(query: "м", resultCount: 100)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.recordSearchSettle(query: "мо", resultCount: 20)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.recordSearchSettle(query: "мова", resultCount: 3)
        }

        wait(seconds: 0.9)

        XCTAssertEqual(performed.count, 1, "only the last settle in the burst should fire an event")
        XCTAssertEqual(performed.first?.query, "мова")
        XCTAssertEqual(performed.first?.count, 3)
    }

    func testClearingSearchText_firesNoSettleEvent() {
        var performed = 0
        var noResults = 0
        let viewModel = SKHistoryViewModel(
            onSearchPerformed: { _, _ in performed += 1 },
            onSearchNoResults: { _ in noResults += 1 },
            onSearchResultTapped: { _, _, _ in }
        )

        // Empty query short-circuits in updateSearch before ever reaching the settle subject.
        viewModel.updateSearch("")

        wait(seconds: 0.7)

        XCTAssertEqual(performed, 0)
        XCTAssertEqual(noResults, 0)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    func testViewModelDeinit_cancelsPendingSettleTimer() {
        var performed = 0
        var viewModel: SKHistoryViewModel? = SKHistoryViewModel(
            onSearchPerformed: { _, _ in performed += 1 },
            onSearchNoResults: { _ in },
            onSearchResultTapped: { _, _, _ in }
        )

        viewModel?.recordSearchSettle(query: "мова", resultCount: 3)
        viewModel = nil // simulates the screen being dismissed before the 500ms timer fires

        wait(seconds: 0.7)

        XCTAssertEqual(performed, 0, "no event should fire after the view model is torn down")
    }

    // MARK: - Tap event (§3, no debounce, immediate)

    func testResultTapped_firesImmediately_withPositionAndActiveQuery() {
        var tapped: (word: SKWord, position: Int, query: String)?
        let viewModel = SKHistoryViewModel(
            onSearchPerformed: { _, _ in },
            onSearchNoResults: { _ in },
            onSearchResultTapped: { word, position, query in tapped = (word, position, query) }
        )
        viewModel.searchText = "мова"
        let word = SKWord(word_id: 42, word: "мова", lang_id: .bel_rus)

        viewModel.resultTapped(word, position: 2)

        XCTAssertEqual(tapped?.word.word_id, 42)
        XCTAssertEqual(tapped?.word.lang_id, .bel_rus)
        XCTAssertEqual(tapped?.position, 2)
        XCTAssertEqual(tapped?.query, "мова")
    }

    // MARK: - Helpers

    private func wait(seconds: TimeInterval) {
        let expectation = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: seconds + 2)
    }
}
