import XCTest
@testable import Skarnik

/// The link to the same headword in the other dictionary (Бел-Рус ⇄ ТСБМ) and its A/B placement.
/// Same rules as skarnik_android's `FindDictionaryLinkUseCase`.
final class SKDictionaryLinkTests: XCTestCase {

    func testPlacementFromRemoteConfigValue() {
        XCTAssertEqual(SKDictionaryLinkPlacement(configValue: "header"), .header)
        XCTAssertEqual(SKDictionaryLinkPlacement(configValue: "footer"), .footer)
        XCTAssertEqual(SKDictionaryLinkPlacement(configValue: "none"), .hidden)
        XCTAssertEqual(SKDictionaryLinkPlacement(configValue: " Footer\n"), .footer)
        // Empty (no experiment) or unknown values fall back to the header.
        XCTAssertEqual(SKDictionaryLinkPlacement(configValue: ""), .header)
        XCTAssertEqual(SKDictionaryLinkPlacement(configValue: "bottom"), .header)
    }

    func testBelRusLinksToTsbmAndBack() {
        var asked: [ESKVocabularyType] = []
        let index: (SKWord, ESKVocabularyType) -> SKWord? = { word, type in
            asked.append(type)
            return SKWord(word_id: 7, word: word.word, lang_id: type)
        }
        let belRus = SKWord(word_id: 1, word: "бурштын", lang_id: .bel_rus)
        let tsbm = SKWord(word_id: 2, word: "бурштын", lang_id: .bel_definition)

        XCTAssertEqual(SKDictionaryLink.find(for: belRus, placement: .footer, index: index),
                       SKDictionaryLink(target: SKWord(word_id: 7, word: "бурштын", lang_id: .bel_definition),
                                        placement: .footer))
        XCTAssertEqual(SKDictionaryLink.find(for: tsbm, placement: .header, index: index)?.target.lang_id, .bel_rus)
        XCTAssertEqual(asked, [.bel_definition, .bel_rus])
    }

    func testRusBelAndTheControlGroupGetNoLinkAndNoLookup() {
        var lookups = 0
        let index: (SKWord, ESKVocabularyType) -> SKWord? = { word, type in
            lookups += 1
            return SKWord(word_id: 7, word: word.word, lang_id: type)
        }
        XCTAssertNil(SKDictionaryLink.find(for: SKWord(word_id: 1, word: "привет", lang_id: .rus_bel),
                                           placement: .header, index: index))
        XCTAssertNil(SKDictionaryLink.find(for: SKWord(word_id: 1, word: "бурштын", lang_id: .bel_rus),
                                           placement: .hidden, index: index))
        XCTAssertEqual(lookups, 0)
    }

    func testBundledIndexFindsTheSameWordInTheOtherDictionary() {
        let index = SKVocabularyIndex.shared
        // «прывітанне»: belrus/76967, tsbm/65172.
        let belRus = SKWord(word_id: 76967, word: "прывітанне", lang_id: .bel_rus)
        let tsbm = index.sameWord(belRus, vocabularyType: .bel_definition)
        XCTAssertEqual(tsbm?.word_id, 65172)
        XCTAssertEqual(tsbm?.lang_id, .bel_definition)
        XCTAssertEqual(index.sameWord(tsbm!, vocabularyType: .bel_rus)?.word_id, 76967)

        // «рваць» has two ТСБМ entries (30087, 72388): the lowest id wins.
        let rvac = SKWord(word_id: 84467, word: "Рваць", lang_id: .bel_rus)
        XCTAssertEqual(index.sameWord(rvac, vocabularyType: .bel_definition)?.word_id, 30087)

        XCTAssertNil(index.sameWord(SKWord(word_id: 1, word: "привет", lang_id: .rus_bel), vocabularyType: .bel_definition))
    }

    @MainActor
    func testViewModelFindsTheLinkWhenTheWordIsSet() {
        let viewModel = SKWordDetailsViewModel(translationSource: SKNeverTranslationSource(),
                                               dictionaryLinkPlacement: { .footer })
        viewModel.updateWord(SKWord(word_id: 76967, word: "прывітанне", lang_id: .bel_rus))
        XCTAssertEqual(viewModel.dictionaryLink?.target.word_id, 65172)
        XCTAssertEqual(viewModel.dictionaryLink?.placement, .footer)

        viewModel.updateWord(nil)
        XCTAssertNil(viewModel.dictionaryLink)
    }
}

/// A translation source that never answers, so the view model stays loading.
private struct SKNeverTranslationSource: SKTranslationSource {
    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        return nil
    }
}
