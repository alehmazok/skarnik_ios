
import XCTest
@testable import Skarnik

// Integration tests for the fuzzy search fallback in SKVocabularyIndex.word(index:query:vocabularyType:limit:).
// Ported from the Flutter app's fuzzy_search_spec.md: fuzzy matching only kicks in when the exact
// prefix search (on lword/word_mask) finds nothing at all, and the query is >= 3 characters.
final class SKFuzzySearchTests: XCTestCase {

    private let index = SKVocabularyIndex.shared

    func testFuzzyMatchOnSingleSubstitutionTypo() {
        // "мовп" (typo for "мова") has zero exact prefix matches in the db.
        XCTAssertEqual(index.wordsCount(query: "мовп", vocabularyType: .bel_rus), 0)

        let results = index.word(index: 0, query: "мовп", vocabularyType: .all, limit: 15)
        XCTAssertTrue(results.contains { $0.word.lowercased() == "мова" },
                      "Expected fuzzy fallback to surface 'мова' for a 1-edit-distance typo")
    }

    func testFuzzyMatchOnAdjacentTransposition() {
        // "слоунік" is "слоўнік" with the ў/у transposed - zero exact prefix matches.
        let results = index.word(index: 0, query: "слоунік", vocabularyType: .all, limit: 15)
        XCTAssertTrue(results.contains { $0.word.lowercased() == "слоўнік" },
                      "Expected fuzzy fallback to surface 'слоўнік' for a transposition typo")
    }

    func testFuzzyDoesNotTriggerBelowMinQueryLength() {
        // "ыъ" is 2 chars (below fuzzySearchMinQueryLength) and matches nothing exactly,
        // so it must stay empty rather than fall back to fuzzy matching.
        let results = index.word(index: 0, query: "ыъ", vocabularyType: .all, limit: 15)
        XCTAssertEqual(results.count, 0)
    }

    func testFuzzyDoesNotTriggerWhenExactMatchesExist() {
        // "мова" has exact prefix matches (мова, мовазнаўства, ...), so fuzzy must not run;
        // every result must still be an exact prefix match, not a fuzzy (edit-distance) one.
        let results = index.word(index: 0, query: "мова", vocabularyType: .all, limit: 15)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.word.lowercased().hasPrefix("мова") })
    }

    func testFuzzyResultsCappedAtWordsSearchLimit() {
        let results = index.word(index: 0, query: "мовп", vocabularyType: .all, limit: 100)
        XCTAssertLessThanOrEqual(results.count, SKVocabularyIndex.wordsSearchLimit)
    }
}
