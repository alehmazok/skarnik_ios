//
//  DeepLinkUITests.swift
//  SkarnikUITests
//
//  The widget's skarnik://word link opens the word. Offline-safe. Universal Links
//  (skarnik.app/r/...) are not testable on BrowserStack: re-signing strips associated domains,
//  so their parsing is covered by SKDeepLinkTests instead.
//

import XCTest

final class DeepLinkUITests: SkarnikUITestCase {

    func testCustomSchemeLinkOpensWord() throws {
        // lang is ESKVocabularyType: 2 = Бел-Рус. 27890 is «добразычлівасць».
        app.open(try XCTUnwrap(URL(string: "skarnik://word?id=27890&lang=2")))
        assertWordScreen("добразычлівасць", in: .belRus)
    }
}
