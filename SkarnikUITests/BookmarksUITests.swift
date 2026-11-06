//
//  BookmarksUITests.swift
//  SkarnikUITests
//
//  Bookmark a word, find it in Закладкі after a relaunch, remove it again. Offline-safe.
//

import XCTest

final class BookmarksUITests: SkarnikUITestCase {

    private let addLabel = "Дадаць у закладкі"
    private let removeLabel = "Выдаліць з закладак"

    func testBookmarkAddAndRemove() {
        openWord("мова", in: .belRus)
        let bookmark = waitFor(element("wordDetails.bookmark"), "No bookmark button")
        XCTAssertEqual(bookmark.label, addLabel)
        bookmark.tap()
        XCTAssertTrue(waitForLabel(bookmark, removeLabel), "Bookmark label did not change to «\(removeLabel)»")

        // Bookmarks are stored, not just in memory.
        relaunchKeepingState()
        openTab(.bookmarks)
        let row = waitFor(element("favorites.row"), "Bookmarked word missing")
        XCTAssertEqual(elements("favorites.row").count, 1)
        XCTAssertTrue(row.label.hasPrefix("мова") || row.staticTexts["мова"].exists, "Row is «\(row.label)»")

        row.tap()
        assertWordScreen("мова", in: .belRus)
        let remove = waitFor(element("wordDetails.bookmark"), "No bookmark button")
        XCTAssertEqual(remove.label, removeLabel)
        remove.tap()
        XCTAssertTrue(waitForLabel(remove, addLabel), "Bookmark label did not change back to «\(addLabel)»")
        goBack()
        waitFor(element("favorites.empty"), "Bookmark was not removed")
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String) -> Bool {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [changed], timeout: 5) == .completed
    }
}
