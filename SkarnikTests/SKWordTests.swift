//
//  SKWordTests.swift
//  SkarnikTests
//

import Testing
@testable import Skarnik

struct SKWordTests {

    @Test func uniqueId_differsAcrossLangIdsWithSameWordId() {
        let rusBel = SKWord(word_id: 1, word: "а", lang_id: .rus_bel)
        let belDefinition = SKWord(word_id: 1, word: "а", lang_id: .bel_definition)

        #expect(rusBel.uniqueId != belDefinition.uniqueId)
    }

    @Test func uniqueId_matchesForSameWordIdAndLangId() {
        let a = SKWord(word_id: 1, word: "а", lang_id: .rus_bel)
        let b = SKWord(word_id: 1, word: "а", lang_id: .rus_bel)

        #expect(a.uniqueId == b.uniqueId)
    }
}
