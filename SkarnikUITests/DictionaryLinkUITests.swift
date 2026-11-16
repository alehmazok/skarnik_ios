//
//  DictionaryLinkUITests.swift
//  SkarnikUITests
//
//  The link to the same headword in the other dictionary (Бел-Рус ⇄ ТСБМ). UI tests skip the Remote
//  Config fetch, so the link is the default header button. It comes from the bundled index, so the
//  test needs no network.
//

import XCTest

final class DictionaryLinkUITests: SkarnikUITestCase {

    func testHeaderButtonOpensTheSameWordInTsbmAndBack() {
        openWord("прывітанне", in: .belRus)
        waitFor(element("wordDetails.dictionaryLink.header"), "No «Тлумачэнне» button").tap()
        assertWordScreen("прывітанне", in: .tsbm)

        // The ТСБМ entry links back to Бел-Рус.
        waitFor(element("wordDetails.dictionaryLink.header"), "No «Пераклад» button").tap()
        assertWordScreen("прывітанне", in: .belRus)
    }
}
