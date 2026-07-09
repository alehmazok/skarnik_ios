
import XCTest
@testable import Skarnik

final class SKDamerauLevenshteinTests: XCTestCase {

    func testEmptyStrings() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("", ""), 0)
    }

    func testOneEmptyString() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("", "abc"), 3)
        XCTAssertEqual(SKDamerauLevenshtein.distance("abc", ""), 3)
    }

    func testIdenticalStrings() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("скарнік", "скарнік"), 0)
    }

    func testSingleSubstitution() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("кот", "кат"), 1)
    }

    func testSingleInsertion() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("кот", "корт"), 1)
    }

    func testSingleDeletion() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("корт", "кот"), 1)
    }

    func testAdjacentTransposition() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("teh", "the"), 1)
    }

    func testTranspositionScoresLowerThanPlainSubstitution() {
        XCTAssertLessThan(SKDamerauLevenshtein.distance("teh", "the"), 2)
    }

    func testRealisticBelarusianTypoPairs() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("скарнік", "скарнк"), 1) // deletion
        XCTAssertEqual(SKDamerauLevenshtein.distance("слоўнік", "слоўнык"), 1) // substitution
        XCTAssertEqual(SKDamerauLevenshtein.distance("слоўнік", "слоунік"), 1) // transposition
    }

    func testCaseSensitive() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("Кот", "кот"), 1)
    }

    func testMismatchedLengthInputs() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("ы", "слоўнік"), 7)
        XCTAssertEqual(SKDamerauLevenshtein.distance("слоўнік", "ы"), 7)
    }

    func testAccumulatesMultipleEdits() {
        XCTAssertEqual(SKDamerauLevenshtein.distance("kitten", "sitting"), 3)
    }
}
