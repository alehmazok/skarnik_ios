
import XCTest
@testable import Skarnik

final class SKOfflineDictionaryStoreTests: XCTestCase {

    private let store = SKOfflineDictionaryStore.shared
    private let testLangId = 9001
    private let otherLangId = 9002

    override func tearDown() async throws {
        await store.deleteAll(langId: testLangId)
        await store.deleteAll(langId: otherLangId)
        try await super.tearDown()
    }

    func testWord_notFound_returnsNil() async {
        let result = await store.word(langId: testLangId, externalId: 1)
        XCTAssertNil(result)
    }

    func testUpsert_thenWordIsRetrievable() async throws {
        let word = SKDownloadedWord(externalId: 1, stress: "тэ́ст", translation: "<b>ok</b>", redirectTo: nil)
        try await store.upsert([word], langId: testLangId)

        let fetched = await store.word(langId: testLangId, externalId: 1)
        XCTAssertEqual(fetched?.externalId, 1)
        XCTAssertEqual(fetched?.stress, "тэ́ст")
        XCTAssertEqual(fetched?.translation, "<b>ok</b>")
        XCTAssertNil(fetched?.redirectTo)
    }

    func testUpsert_replacesOnConflict() async throws {
        try await store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "first", redirectTo: nil)], langId: testLangId)
        try await store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "second", redirectTo: nil)], langId: testLangId)

        let count = await store.wordCount(langId: testLangId)
        let fetched = await store.word(langId: testLangId, externalId: 1)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(fetched?.translation, "second")
    }

    func testWordCount_isolatedPerLangId() async throws {
        try await store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil)], langId: testLangId)
        try await store.upsert(
            [
                SKDownloadedWord(externalId: 1, stress: nil, translation: "b", redirectTo: nil),
                SKDownloadedWord(externalId: 2, stress: nil, translation: "c", redirectTo: nil)
            ],
            langId: otherLangId
        )

        let testCount = await store.wordCount(langId: testLangId)
        let otherCount = await store.wordCount(langId: otherLangId)
        XCTAssertEqual(testCount, 1)
        XCTAssertEqual(otherCount, 2)
    }

    func testDeleteAll_removesOnlyThatLangId() async throws {
        try await store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil)], langId: testLangId)
        try await store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "b", redirectTo: nil)], langId: otherLangId)

        await store.deleteAll(langId: testLangId)

        let testCount = await store.wordCount(langId: testLangId)
        let otherCount = await store.wordCount(langId: otherLangId)
        XCTAssertEqual(testCount, 0)
        XCTAssertEqual(otherCount, 1)
    }

    func testWord_withRedirectTo_isPreserved() async throws {
        try await store.upsert([SKDownloadedWord(externalId: 1, stress: nil, translation: "", redirectTo: "/belrus/2")], langId: testLangId)
        let fetched = await store.word(langId: testLangId, externalId: 1)
        XCTAssertEqual(fetched?.redirectTo, "/belrus/2")
    }
}
