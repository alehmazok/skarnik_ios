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

    // Issue #94: dict_name must be the stable names Android sends, not the localized UI name.
    @Test func analyticsName_matchesAndroidDictionaryNames() {
        #expect(ESKVocabularyType.rus_bel.analyticsName == "rusBel")
        #expect(ESKVocabularyType.bel_rus.analyticsName == "belRus")
        #expect(ESKVocabularyType.bel_definition.analyticsName == "tsbm")
        #expect(ESKVocabularyType.history.analyticsName == nil)
        #expect(ESKVocabularyType.all.analyticsName == nil)
    }

    @Test func analyticsName_isNotTheLocalizedName() {
        for type in [ESKVocabularyType.rus_bel, .bel_rus, .bel_definition] {
            #expect(type.analyticsName != type.name)
        }
    }
}
