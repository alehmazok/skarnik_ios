//
//  BrowseUITests.swift
//  SkarnikUITests
//
//  Слоўнікі tab: each dictionary lists its words and opens them. Offline-safe.
//

import XCTest

final class BrowseUITests: SkarnikUITestCase {

    func testEachDictionaryListsAndOpensWords() {
        for dictionary in [Dictionary.rusBel, .belRus, .tsbm] {
            openFirstDictionaryWord(dictionary)
            goBack()
        }
    }
}
