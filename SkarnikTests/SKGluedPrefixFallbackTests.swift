
import XCTest
@testable import Skarnik

// Ported from the Flutter app's glued_preposition_fallback_spec.md: retries once with
// the leading letter stripped when a glued preposition/conjunction ("всмысле") produces
// zero primary results, since fuzzy matching buckets by first letter and can't recover
// from a wrong bucket on its own.
final class SKGluedPrefixFallbackTests: XCTestCase {

    private let index = SKVocabularyIndex.shared

    func testStripsGluedPrefixLetterAndFindsWord() {
        let result = index.search(query: "всмысле", vocabularyType: .all, limit: 15)
        XCTAssertTrue(result.usedFallback)
        XCTAssertTrue(result.words.contains { $0.word.lowercased().hasPrefix("смысл") },
                      "Expected 'всмысле' to fall back to 'смысле' and fuzzy-match 'смысл'")
    }

    func testStripsGluedPrefixLetter_beExample() {
        // "усціш" ("у сціш[ыцца]") has zero exact/fuzzy matches in the "у" bucket;
        // stripping to "сціш" finds the "сцішы-" family via exact prefix match.
        let result = index.search(query: "усціш", vocabularyType: .all, limit: 15)
        XCTAssertTrue(result.usedFallback)
        XCTAssertTrue(result.words.contains { $0.word.lowercased().hasPrefix("сціш") })
    }

    func testDoesNotFallBackWhenPrimaryFindsResults() {
        // "мова" already has exact matches, so the fallback must never fire.
        let result = index.search(query: "мова", vocabularyType: .all, limit: 15)
        XCTAssertFalse(result.usedFallback)
        XCTAssertFalse(result.words.isEmpty)
    }

    func testDoesNotFallBackOnNonGluedLetter() {
        // "ф" is not in the glued-prefix letter set.
        let result = index.search(query: "фыфыфы", vocabularyType: .all, limit: 15)
        XCTAssertFalse(result.usedFallback)
    }

    func testDoesNotFallBackOnSingleCharQuery() {
        // length < 2 guard: stripping "в" down to "" would match everything.
        let result = index.search(query: "в", vocabularyType: .all, limit: 15)
        XCTAssertFalse(result.usedFallback)
    }

    func testDoubleMissStaysEmpty() {
        // Both the primary and the stripped retry find nothing; usedFallback is still
        // true (per spec: reflects that a retry was attempted), but words stays empty.
        let result = index.search(query: "вжжжжж", vocabularyType: .all, limit: 15)
        XCTAssertTrue(result.usedFallback)
        XCTAssertTrue(result.words.isEmpty)
    }

    func testStripGluedPrefixLetter_helper() {
        XCTAssertEqual(SKVocabularyIndex.stripGluedPrefixLetter("всмысле"), "смысле")
        XCTAssertNil(SKVocabularyIndex.stripGluedPrefixLetter("в"))
        XCTAssertNil(SKVocabularyIndex.stripGluedPrefixLetter("фыфыфы"))
        XCTAssertNil(SKVocabularyIndex.stripGluedPrefixLetter(""))
    }
}
