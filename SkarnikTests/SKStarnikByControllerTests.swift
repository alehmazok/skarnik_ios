
import XCTest
@testable import Skarnik

final class SKStarnikByControllerTests: XCTestCase {

    // MARK: - Exact lemma filtering

    func testSpellingWordSuggestions_keepsOnlyExactLemmaMatches() {
        // Regression: the API also returns unrelated fuzzy lemmas (e.g. "мухавецкі" for
        // query "муха"), which must not leak into the disambiguation picker.
        let json = """
        {
            "word_list": [
                {"lemma": "муха", "id": 1, "table_name": "Nouns", "meaning": ""},
                {"lemma": "мухалоўка", "id": 2, "table_name": "Nouns", "meaning": ""},
                {"lemma": "мухавецкі", "id": 3, "table_name": "Adjectives", "meaning": ""}
            ],
            "form_list": []
        }
        """
        let data = Data(json.utf8)

        let words = SKStarnikByController.spellingWordSuggestions(data: data, matching: "муха")

        XCTAssertEqual(words?.map { $0.wordIdStr }, ["1"])
    }

    func testSpellingWordSuggestions_isCaseInsensitive() {
        let json = """
        {
            "word_list": [{"lemma": "Муха", "id": 1, "table_name": "Nouns", "meaning": ""}],
            "form_list": []
        }
        """
        let data = Data(json.utf8)

        let words = SKStarnikByController.spellingWordSuggestions(data: data, matching: "муха")

        XCTAssertEqual(words?.count, 1)
    }

    func testSpellingWordSuggestions_returnsAllHomonymsForExactLemma() {
        // "а" resolves to several parts of speech sharing the same lemma; all must surface
        // for the user to pick from, not just the first.
        let json = """
        {
            "word_list": [
                {"lemma": "а", "id": 1, "table_name": "Nouns", "meaning": ""},
                {"lemma": "а", "id": 234065, "table_name": "Conjunctions", "meaning": ""},
                {"lemma": "а", "id": 250353, "table_name": "Prepositions", "meaning": ""}
            ],
            "form_list": []
        }
        """
        let data = Data(json.utf8)

        let words = SKStarnikByController.spellingWordSuggestions(data: data, matching: "а")

        XCTAssertEqual(words?.map { $0.wordIdStr }, ["1", "234065", "250353"])
    }

    func testSpellingWordSuggestions_fallsBackToFullListWhenNoExactMatch() {
        let json = """
        {
            "word_list": [{"lemma": "мухалоўка", "id": 2, "table_name": "Nouns", "meaning": ""}],
            "form_list": []
        }
        """
        let data = Data(json.utf8)

        let words = SKStarnikByController.spellingWordSuggestions(data: data, matching: "муха")

        XCTAssertEqual(words?.map { $0.wordIdStr }, ["2"])
    }

    func testSpellingWordSuggestions_emptyWordListReturnsNil() {
        let json = """
        {"word_list": [], "form_list": []}
        """
        let data = Data(json.utf8)

        let words = SKStarnikByController.spellingWordSuggestions(data: data, matching: "муха")

        XCTAssertNil(words)
    }

    func testSpellingWordSuggestions_malformedJsonReturnsNil() {
        let data = Data("not json".utf8)

        let words = SKStarnikByController.spellingWordSuggestions(data: data, matching: "муха")

        XCTAssertNil(words)
    }

    // MARK: - SKStarnikSpellingWord.wordTypeLabel

    func testWordTypeLabel_mapsKnownTableName() {
        let word = SKStarnikSpellingWord(word: "а", wordIdStr: "1", wordType: "Conjunctions", unknownParam1: nil)

        XCTAssertEqual(word.wordTypeLabel, "злучнік")
    }

    func testWordTypeLabel_fallsBackToRawValueWhenUnmapped() {
        let word = SKStarnikSpellingWord(word: "а", wordIdStr: "1", wordType: "Gerunds", unknownParam1: nil)

        XCTAssertEqual(word.wordTypeLabel, "Gerunds")
    }

    func testWordTypeLabel_nilWhenWordTypeMissing() {
        let word = SKStarnikSpellingWord(word: "а", wordIdStr: "1", wordType: nil, unknownParam1: nil)

        XCTAssertNil(word.wordTypeLabel)
    }
}
