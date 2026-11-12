//
//  SKHistoryViewModelTests.swift
//  SkarnikTests
//

import XCTest
@testable import Skarnik

@MainActor
final class SKHistoryViewModelTests: XCTestCase {

    private func makeViewModel() -> SKHistoryViewModel {
        SKHistoryViewModel(
            onSearchPerformed: { _, _ in },
            onSearchNoResults: { _ in },
            onSearchResultTapped: { _, _, _ in }
        )
    }

    func testSearchIsNotPresentedInitially() {
        XCTAssertFalse(makeViewModel().isSearchPresented)
    }

    func testActivateSearch_presentsSearch() {
        let viewModel = makeViewModel()

        viewModel.activateSearch()

        XCTAssertTrue(viewModel.isSearchPresented)
    }

    func testActivateSearch_isIdempotent() {
        let viewModel = makeViewModel()

        viewModel.activateSearch()
        viewModel.activateSearch()

        XCTAssertTrue(viewModel.isSearchPresented)
    }

    func testActivateSearch_afterCancel_presentsAgain() {
        let viewModel = makeViewModel()
        viewModel.activateSearch()
        // SwiftUI writes `false` through the binding when the user taps Cancel.
        viewModel.isSearchPresented = false

        viewModel.activateSearch()

        XCTAssertTrue(viewModel.isSearchPresented)
    }

    func testActivateSearch_keepsSearchText() {
        let viewModel = makeViewModel()
        viewModel.searchText = ""

        viewModel.activateSearch()

        XCTAssertEqual(viewModel.searchText, "")
    }

    func testInsertCharacter_appendsToQuery() {
        let viewModel = makeViewModel()
        viewModel.searchText = "сло"

        viewModel.insertCharacter("ў")

        XCTAssertEqual(viewModel.searchText, "слоў")
    }

    func testInsertCharacter_intoEmptyQuery() {
        let viewModel = makeViewModel()

        viewModel.insertCharacter("і")

        XCTAssertEqual(viewModel.searchText, "і")
    }
}
