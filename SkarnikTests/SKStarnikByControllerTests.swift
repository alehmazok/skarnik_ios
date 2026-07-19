
import XCTest
@testable import Skarnik

final class SKStarnikStressBackendTests: XCTestCase {

    // MARK: - parseWordList

    func testParseWordList_mapsAllEntriesUnfiltered() {
        // Exact-match filtering is the resolver's job (stress_spec.md §4a), not the
        // backend's — the backend must surface every entry the API returned, including
        // fuzzy/related lemmas (e.g. "мухавецкі" for query "муха").
        let json = """
        {
            "word_list": [
                {"lemma": "муха", "word": "му́ха", "id": 1, "table_name": "Nouns"},
                {"lemma": "мухалоўка", "word": "мухало́ўка", "id": 2, "table_name": "Nouns"},
                {"lemma": "мухавецкі", "word": "мухаве́цкі", "id": 3, "table_name": "Adjectives"}
            ]
        }
        """
        let data = Data(json.utf8)

        let entries = try? SKStarnikStressBackend.parseWordList(data: data)

        XCTAssertEqual(entries?.map { $0.id }, [1, 2, 3])
        XCTAssertEqual(entries?.map { $0.source }, [.api, .api, .api])
    }

    func testParseWordList_returnsAllHomonymsForSharedLemma() {
        // "а" resolves to several parts of speech sharing the same lemma; all must surface
        // for the resolver/picker to work with, not just the first.
        let json = """
        {
            "word_list": [
                {"lemma": "а", "word": "а́", "id": 1, "table_name": "Nouns"},
                {"lemma": "а", "word": "а́", "id": 234065, "table_name": "Conjunctions"},
                {"lemma": "а", "word": "а́", "id": 250353, "table_name": "Prepositions"}
            ]
        }
        """
        let data = Data(json.utf8)

        let entries = try? SKStarnikStressBackend.parseWordList(data: data)

        XCTAssertEqual(entries?.map { $0.id }, [1, 234065, 250353])
    }

    func testParseWordList_usesStressedWordNotRawLemmaForDisplay() {
        // Regression: homonyms share a lemma but differ in stress placement (e.g. "казак"
        // could stress the first or second syllable depending on sense). Using the raw
        // lemma for `word` makes such candidates look identical; the API's stressed `word`
        // field must be surfaced instead.
        let json = """
        {
            "word_list": [
                {"lemma": "казак", "word": "каза́к", "id": 1, "table_name": "Nouns"},
                {"lemma": "казак", "word": "ко́зак", "id": 2, "table_name": "Nouns"}
            ]
        }
        """
        let data = Data(json.utf8)

        let entries = try? SKStarnikStressBackend.parseWordList(data: data)

        XCTAssertEqual(entries?.map { $0.word }, ["каза́к", "ко́зак"])
    }

    func testParseWordList_emptyWordListReturnsEmptyArray() {
        let data = Data(#"{"word_list": []}"#.utf8)

        let entries = try? SKStarnikStressBackend.parseWordList(data: data)

        XCTAssertEqual(entries, [])
    }

    func testParseWordList_malformedJsonThrows() {
        let data = Data("not json".utf8)

        XCTAssertThrowsError(try SKStarnikStressBackend.parseWordList(data: data))
    }

    // MARK: - parseHtml

    func testParseHtml_extractsTwoColumnRowsFromWrapperTable() {
        let html = """
        <html><body>
        <div class="wrapper">
        <table>
        <tr><td>форма</td><td>каза́к</td></tr>
        <tr><td>множны лік</td><td>казакі́</td></tr>
        <tr><td>лішні слупок</td><td>a</td><td>b</td></tr>
        </table>
        </div>
        </body></html>
        """
        let data = Data(html.utf8)

        let rows = try? SKStarnikStressBackend.parseHtml(data: data)

        XCTAssertEqual(rows?.count, 2)
        XCTAssertEqual(rows?.first?.title, "форма")
        XCTAssertEqual(rows?.first?.content, "каза́к")
    }

    func testParseHtml_noWrapperTableReturnsEmptyArray() {
        let data = Data("<html><body>нічога</body></html>".utf8)

        let rows = try? SKStarnikStressBackend.parseHtml(data: data)

        XCTAssertEqual(rows?.count, 0)
    }

    // MARK: - SKStressWordEntry.wordTypeLabel

    func testWordTypeLabel_mapsKnownTableName() {
        let entry = SKStressWordEntry(id: 1, lemma: "а", word: "а", tableName: "Conjunctions", source: .api)

        XCTAssertEqual(entry.wordTypeLabel, "злучнік")
    }

    func testWordTypeLabel_fallsBackToRawValueWhenUnmapped() {
        let entry = SKStressWordEntry(id: 1, lemma: "а", word: "а", tableName: "Gerunds", source: .api)

        XCTAssertEqual(entry.wordTypeLabel, "Gerunds")
    }

    func testWordTypeLabel_nilWhenTableNameMissing() {
        let entry = SKStressWordEntry(id: 1, lemma: "а", word: "а", tableName: nil, source: .api)

        XCTAssertNil(entry.wordTypeLabel)
    }
}
