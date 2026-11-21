import XCTest
import SwiftUI
@testable import Skarnik

final class SKStressWordPickerTests: XCTestCase {

    private func entry(_ id: Int, _ word: String, _ tableName: String? = "Nouns",
                       source: SKStressSource = .api, meaning: String? = nil) -> SKStressWordEntry {
        SKStressWordEntry(id: id, lemma: word.replacingOccurrences(of: "\u{0301}", with: ""), word: word,
                          tableName: tableName, source: source, meaning: meaning)
    }

    // MARK: - sections

    func testSections_groupByStressedFormKeepingApiOrder() {
        let entries = [
            entry(52855, "па́ра", meaning: "два аднолькавыя прадметы"),
            entry(52857, "пара́"),
            entry(52856, "па́ра", meaning: "стан вадкасці")
        ]

        let sections = SKStressWordPicker.sections(for: entries)

        XCTAssertEqual(sections.map(\.word), ["па́ра", "пара́"])
        XCTAssertEqual(sections[0].rows.map(\.entry.id), [52855, 52856])
        XCTAssertEqual(sections[1].rows.map(\.entry.id), [52857])
    }

    func testSections_sameStressEverywhereGivesSingleSection() {
        let entries = [entry(1, "а́"), entry(234065, "а́", "Conjunctions"), entry(250353, "а́", "Prepositions")]

        let sections = SKStressWordPicker.sections(for: entries)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].rows.map(\.title), ["назоўнік", "злучнік", "прыназоўнік"])
    }

    // MARK: - rows

    func testRow_meaningIsTitleWithPartOfSpeechChip() {
        let row = SKStressWordPicker.sections(for: [entry(52856, "па́ра", meaning: "стан вадкасці")])[0].rows[0]

        XCTAssertEqual(row.title, "стан вадкасці")
        XCTAssertEqual(row.chip, "назоўнік")
        XCTAssertNil(row.ordinal)
    }

    func testRow_withoutMeaningShowsPartOfSpeechAloneThenWord() {
        let rows = SKStressWordPicker.sections(for: [entry(1, "пара́"), entry(2, "па́ра", nil)]).flatMap(\.rows)

        XCTAssertEqual(rows.map(\.title), ["назоўнік", "па́ра"])
        XCTAssertEqual(rows.map(\.chip), [nil, nil])
    }

    // Cloud fallback has no meanings: two па́ра nouns would read the same, so they get numbers.
    func testRows_identicalRowsInSectionAreNumbered() {
        let entries = [
            entry(476123, "па́ра", source: .cloud),
            entry(476124, "па́ра", source: .cloud),
            entry(49142, "пара́", source: .cloud)
        ]

        let sections = SKStressWordPicker.sections(for: entries)

        XCTAssertEqual(sections[0].rows.map(\.ordinal), [1, 2])
        XCTAssertEqual(sections[1].rows.map(\.ordinal), [nil])
    }

    func testRows_distinctMeaningsAreNotNumbered() {
        let entries = [entry(1, "па́ра", meaning: "адно"), entry(2, "па́ра", meaning: "іншае")]

        let rows = SKStressWordPicker.sections(for: entries)[0].rows

        XCTAssertEqual(rows.map(\.ordinal), [nil, nil])
    }

    // MARK: - highlightedWord

    func testHighlightedWord_colorsOnlyTheStressedVowel() {
        let highlighted = SKStressWordPicker.highlightedWord("пара́")

        let colored = highlighted.runs.filter { $0.attributes[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] != nil }.map { String(highlighted[$0.range].characters) }
        XCTAssertEqual(colored, ["а́"])
        XCTAssertEqual(String(highlighted.characters), "пара́")
    }

    func testHighlightedWord_noStressMarkLeavesTextUncolored() {
        let highlighted = SKStressWordPicker.highlightedWord("пара")

        XCTAssertTrue(highlighted.runs.allSatisfy { $0.attributes[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] == nil })
    }

    // MARK: - meaning count

    func testMeaningCount_belarusianPlurals() {
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(1), "1 значэнне")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(2), "2 значэнні")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(4), "4 значэнні")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(5), "5 значэнняў")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(11), "11 значэнняў")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(12), "12 значэнняў")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(21), "21 значэнне")
        XCTAssertEqual(SKLocalization.stressPickerMeaningCount(22), "22 значэнні")
    }
}
