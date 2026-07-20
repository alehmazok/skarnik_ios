
import XCTest
@testable import Skarnik

final class SKOfflineDictionaryStoreTests: XCTestCase {

    private let store = SKOfflineDictionaryStore.shared
    private let testLangId = 9001
    private let otherLangId = 9002

    override func tearDown() {
        store.deleteAll(langId: testLangId)
        store.deleteAll(langId: otherLangId)
        super.tearDown()
    }

    func testWord_notFound_returnsNil() {
        XCTAssertNil(store.word(langId: testLangId, externalId: 1))
    }

    func testUpsert_thenWordIsRetrievable() throws {
        let word = SKDownloadedWord(externalId: 1, stress: "тэ́ст", translation: "<b>ok</b>", redirectTo: nil)
        try store.upsert([word], langId: testLangId)

        let fetched = store.word(langId: testLangId, externalId: 1)
        XCTAssertEqual(fetched?.externalId, 1)
        XCTAssertEqual(fetched?.stress, "тэ́ст")
        XCTAssertEqual(fetched?.translation, "<b>ok</b>")
        XCTAssertNil(fetched?.redirectTo)
    }

    func testUpsert_replacesOnConflict() throws {
        try store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "first", redirectTo: nil)], langId: testLangId)
        try store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "second", redirectTo: nil)], langId: testLangId)

        XCTAssertEqual(store.wordCount(langId: testLangId), 1)
        XCTAssertEqual(store.word(langId: testLangId, externalId: 1)?.translation, "second")
    }

    func testWordCount_isolatedPerLangId() throws {
        try store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil)], langId: testLangId)
        try store.upsert(
            [
                SKDownloadedWord(externalId: 1, stress: nil, translation: "b", redirectTo: nil),
                SKDownloadedWord(externalId: 2, stress: nil, translation: "c", redirectTo: nil)
            ],
            langId: otherLangId
        )

        XCTAssertEqual(store.wordCount(langId: testLangId), 1)
        XCTAssertEqual(store.wordCount(langId: otherLangId), 2)
    }

    func testDeleteAll_removesOnlyThatLangId() throws {
        try store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil)], langId: testLangId)
        try store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "b", redirectTo: nil)], langId: otherLangId)

        store.deleteAll(langId: testLangId)

        XCTAssertEqual(store.wordCount(langId: testLangId), 0)
        XCTAssertEqual(store.wordCount(langId: otherLangId), 1)
    }

    func testWord_withRedirectTo_isPreserved() throws {
        try store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "", redirectTo: "/belrus/2")], langId: testLangId)
        XCTAssertEqual(store.word(langId: testLangId, externalId: 1)?.redirectTo, "/belrus/2")
    }
}
