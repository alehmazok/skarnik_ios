//
//  AppStoreScreenshotsUITests.swift
//  SkarnikUITests
//
//  Captures the raw App Store screens (issue #60). Not a regression test: it is skipped unless
//  `scripts/app-store-screenshots.sh` passes an output folder, so CI and BrowserStack never run it.
//  Needs the internet (article, stress table, offline download).
//
//  The script runs this once per device (6.9" iPhone, 13" iPad) and appearance (light, dark).
//  The PNGs go to App Store Connect as they are: no captions, no frame.
//

import XCTest

final class AppStoreScreenshotsUITests: SkarnikUITestCase {

    /// Words used in the shots. Change them here to get different screens.
    private enum Words {
        /// Typed before the shot of the і / ў / ʼ key row, so the results list is full.
        static let searchPrefix = "мов"
        /// A ТСБМ article with coloured parts.
        static let article = ("удзячнасць", SkarnikUITestCase.Dictionary.tsbm)
        /// A ТСБМ headword, so «На́ціск» opens the stress table directly.
        static let stress = ("стракаты", SkarnikUITestCase.Dictionary.tsbm)
        /// Bookmarks as they appear on screen, newest first.
        static let bookmarks: [(String, SkarnikUITestCase.Dictionary)] = [
            ("прочувствовать", .rusBel), ("стракаты", .belRus), ("мохнатый", .rusBel), ("руплівы", .tsbm),
            ("верагодны", .belRus), ("колер", .belRus), ("скогат", .tsbm), ("наўмысля", .belRus),
            ("угрюмый", .rusBel), ("атаясамлівацца", .belRus), ("брызги", .rusBel)
        ]
        /// History as it appears on screen, newest first. Opened after the bookmarks, so these are on top.
        static let history: [(String, SkarnikUITestCase.Dictionary)] = [
            ("спакваля", .belRus), ("свядомасць", .tsbm), ("сознательный", .rusBel), ("сугроб", .rusBel),
            ("прочувствовать", .rusBel), ("чуждый", .rusBel), ("цурацца", .belRus), ("стракаты", .belRus),
            ("стракаты", .tsbm), ("однозначно", .rusBel)
        ]
    }

    private var outputDirectory: URL?

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SKARNIK_SCREENSHOTS_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Run scripts/app-store-screenshots.sh to capture App Store screenshots")
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory!, withIntermediateDirectories: true)
        try super.setUpWithError()
    }

    /// One journey, so history and bookmarks carry over between shots.
    func testCaptureAppStoreScreens() {
        // A missed shot should not cost the rest of the set.
        continueAfterFailure = true

        collectBookmarksAndHistory()

        // 5–6. History and bookmarks first, before the article and stress words join the history.
        waitFor(element("history.row"), "History is empty")
        snapshot("05-history")
        openTab(.bookmarks)
        waitFor(element("favorites.row"), "No bookmarks")
        snapshot("06-bookmarks")

        // 1. Search with the extra letter keys above the keyboard.
        search(Words.searchPrefix)
        waitFor(element("search.key.ў"), "Extra letter row missing")
        waitFor(element("search.result"), "No search results")
        snapshot("01-search")

        // 2. Article with colours.
        search(Words.article.0)
        searchResult(Words.article.0, in: Words.article.1).tap()
        assertWordScreen(Words.article.0, in: Words.article.1)
        waitForTranslation()
        snapshot("02-article")
        goBack()

        // 3. Stress table.
        search(Words.stress.0)
        searchResult(Words.stress.0, in: Words.stress.1).tap()
        assertWordScreen(Words.stress.0, in: Words.stress.1)
        waitForTranslation()
        openStressTable()
        snapshot("03-stress")
        goBack()
        goBack()

        // 4. Works offline: last, because the download is the slow part.
        if ProcessInfo.processInfo.environment["SKARNIK_SCREENSHOTS_SKIP_OFFLINE"] != "1" {
            // Leave search mode so the tab bar (and the gear on Гісторыя) is back.
            showHistory()
            downloadOfflineDictionary()
            snapshot("04-offline")
        }
    }

    // MARK: - Steps

    /// Opens the words oldest first, so both lists end up in the order of `Words`.
    private func collectBookmarksAndHistory() {
        for (word, dictionary) in Words.bookmarks.reversed() {
            openWord(word, in: dictionary)
            // The button stays disabled until the article loads (on iPad the word column is reused).
            waitForTranslation()
            let bookmark = waitFor(bookmarkButton, "No bookmark button")
            if bookmark.label == "Дадаць у закладкі" {
                bookmark.tap()
                XCTAssertTrue(waitForLabel(bookmark, "Выдаліць з закладак"), "«\(word)» was not bookmarked")
            }
            goBack()
        }
        for (word, dictionary) in Words.history.reversed() {
            openWord(word, in: dictionary)
            goBack()
        }
        showHistory()
    }

    private func openStressTable() {
        waitFor(element("wordDetails.stress"), "No «На́ціск» button").tap()
        let stress = element("wordStress")
        let deadline = Date().addingTimeInterval(30)
        while !stress.exists && Date() < deadline {
            // Homographs: an action sheet asks which word is meant.
            let picker = app.sheets.firstMatch
            if picker.exists {
                picker.buttons.matching(NSPredicate(format: "label != %@", "Адмена")).firstMatch.tap()
                continue
            }
            _ = stress.waitForExistence(timeout: 1)
        }
        waitFor(element("wordStress.cell"), timeout: 30, "Stress table has no rows")
    }

    private func downloadOfflineDictionary() {
        openSettings()
        let status = element("settings.offline.tsbm.status")
        waitFor(element("settings.offline.tsbm.download"), "No ТСБМ download button").tap()
        let downloaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "Спампавана"),
                                                   object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [downloaded], timeout: 600), .completed,
                       "Download did not finish: «\(status.label)»")
    }

    // MARK: - Capture

    /// Saves the full-resolution screen as `<name>.png` and attaches it to the test result.
    private func snapshot(_ name: String) {
        // Let the keyboard, toasts and image loading settle.
        Thread.sleep(forTimeInterval: 1.5)
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = outputDirectory else { return }
        do {
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("Could not save \(name).png: \(error)")
        }
    }
}
