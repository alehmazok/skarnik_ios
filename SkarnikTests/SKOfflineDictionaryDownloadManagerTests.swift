
import XCTest
import Combine
@testable import Skarnik

@MainActor
final class SKOfflineDictionaryDownloadManagerTests: XCTestCase {

    private let dictionary: ESKVocabularyType = .bel_definition
    private var cancellables: Set<AnyCancellable> = []
    private var storage: SKOfflineDictionaryStorage!

    override func setUp() async throws {
        try await super.setUp()
        // Isolated UserDefaults suite, NOT `.shared`/`.standard` — the XCTest host app shares the
        // real app's UserDefaults domain, so writing rate-limit attempt timestamps to `.standard`
        // here would silently eat into the real app's download-attempt budget on this simulator.
        let suiteName = "SKOfflineDictionaryDownloadManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        storage = SKOfflineDictionaryStorage(defaults: defaults)

        // Defensive: `store` is the real, shared SQLite file (there's no isolated-store DI), so
        // clear this test's langId here too, not just in tearDown — guards against any leftover
        // rows from outside this test run (e.g. manual app usage on the same simulator).
        await SKOfflineDictionaryStore.shared.deleteAll(langId: dictionary.rawValue)
    }

    override func tearDown() async throws {
        await SKOfflineDictionaryStore.shared.deleteAll(langId: dictionary.rawValue)
        storage = nil
        cancellables = []
        try await super.tearDown()
    }

    private func makeManager(cloud: MockCloudSource) -> SKOfflineDictionaryDownloadManager {
        SKOfflineDictionaryDownloadManager(cloudSource: cloud, store: .shared, storage: storage)
    }

    private func waitForTerminalState(_ manager: SKOfflineDictionaryDownloadManager, timeout: TimeInterval = 5.0) async {
        if case .downloaded = manager.states[dictionary] { return }
        if case .failed = manager.states[dictionary] { return }

        let exp = expectation(description: "terminal state")
        manager.$states
            .sink { states in
                switch states[self.dictionary] {
                case .downloaded, .failed: exp.fulfill()
                default: break
                }
            }
            .store(in: &cancellables)
        await fulfillment(of: [exp], timeout: timeout)
    }

    // MARK: - Resume algorithm

    func testFreshDownload_startsDoneAtZeroDespiteStaleLocalData() async throws {
        // Stale local rows from before the cursor feature existed, with no persisted cursor.
        try await SKOfflineDictionaryStore.shared.upsert(
            [SKDownloadedWord(externalId: 1, stress: nil, translation: "stale", redirectTo: nil)],
            langId: dictionary.rawValue
        )
        XCTAssertNil(storage.cursor(for: dictionary))

        let cloud = MockCloudSource()
        cloud.totalCount = 2
        cloud.pages = [
            [SKCloudWordRow(id: 10, external_id: 2, stress: nil, translation: "a", redirect_to: nil)],
            []
        ]
        let manager = makeManager(cloud: cloud)

        var observedFirstDone: Int?
        manager.$states
            .sink { states in
                if case .downloading(let done, _) = states[self.dictionary], observedFirstDone == nil {
                    observedFirstDone = done
                }
            }
            .store(in: &cancellables)

        manager.startDownload(dictionary)
        await waitForTerminalState(manager)

        XCTAssertEqual(observedFirstDone, 0, "Fresh start must begin at done=0, not localCount")
        guard case .downloaded(let count) = manager.states[dictionary] else {
            XCTFail("Expected downloaded state"); return
        }
        XCTAssertEqual(count, 2)
    }

    func testResume_seedsDoneFromLocalCountAndFetchesFromPersistedCursor() async throws {
        try await SKOfflineDictionaryStore.shared.upsert(
            [
                SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil),
                SKDownloadedWord(externalId: 2, stress: nil, translation: "b", redirectTo: nil)
            ],
            langId: dictionary.rawValue
        )
        storage.setCursor(100, for: dictionary)

        let cloud = MockCloudSource()
        cloud.totalCount = 3
        cloud.pages = [
            [SKCloudWordRow(id: 200, external_id: 3, stress: nil, translation: "c", redirect_to: nil)],
            []
        ]
        let manager = makeManager(cloud: cloud)

        var observedFirstDone: Int?
        manager.$states
            .sink { states in
                if case .downloading(let done, _) = states[self.dictionary], observedFirstDone == nil {
                    observedFirstDone = done
                }
            }
            .store(in: &cancellables)

        manager.startDownload(dictionary)
        await waitForTerminalState(manager)

        XCTAssertEqual(observedFirstDone, 2, "Resume must seed done from localCount")
        XCTAssertEqual(cloud.requestedCursors.first, 100, "Resume must fetch starting from the persisted cursor")
        XCTAssertNil(storage.cursor(for: dictionary), "Cursor is cleared once the stream is exhausted")
    }

    func testStaleCursorGuard_resetsToFreshStartWhenNoLocalData() async {
        storage.setCursor(500, for: dictionary)
        // No local rows for this dictionary — the persisted cursor is stale.

        let cloud = MockCloudSource()
        cloud.totalCount = 1
        cloud.pages = [
            [SKCloudWordRow(id: 5, external_id: 1, stress: nil, translation: "a", redirect_to: nil)],
            []
        ]
        let manager = makeManager(cloud: cloud)

        manager.startDownload(dictionary)
        await waitForTerminalState(manager)

        XCTAssertEqual(cloud.requestedCursors.first, 0, "A stale cursor with no local data must be discarded")
    }

    func testRefreshDownloadedCounts_interruptedDownloadShowsAsNotDownloaded() async throws {
        // Simulates the app being killed mid-download: partial rows made it to disk, but the
        // cursor was never cleared because the fetch loop never reached the exhausting empty page.
        try await SKOfflineDictionaryStore.shared.upsert(
            [SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil)],
            langId: dictionary.rawValue
        )
        storage.setCursor(50, for: dictionary)

        let manager = makeManager(cloud: MockCloudSource())
        await manager.refreshDownloadedCounts()

        guard case .notDownloaded = manager.states[dictionary] else {
            XCTFail("An interrupted download (cursor still persisted) must not show as .downloaded — there'd be no way to resume it"); return
        }
    }

    func testRefreshDownloadedCounts_completedDownloadShowsAsDownloaded() async throws {
        try await SKOfflineDictionaryStore.shared.upsert(
            [SKDownloadedWord(externalId: 1, stress: nil, translation: "a", redirectTo: nil)],
            langId: dictionary.rawValue
        )
        // No cursor persisted — the stream was fully exhausted (see runDownload's completion path).

        let manager = makeManager(cloud: MockCloudSource())
        await manager.refreshDownloadedCounts()

        guard case .downloaded(let count) = manager.states[dictionary] else {
            XCTFail("A completed download (no persisted cursor) must show as .downloaded"); return
        }
        XCTAssertEqual(count, 1)
    }

    // MARK: - Retry policy

    func testPageFetchRetry_succeedsAfterTransientFailure() async {
        let cloud = MockCloudSource()
        cloud.totalCount = 1
        cloud.pages = [
            [SKCloudWordRow(id: 1, external_id: 1, stress: nil, translation: "a", redirect_to: nil)],
            []
        ]
        cloud.errorForAttempt = [1: URLError(.timedOut)]
        let manager = makeManager(cloud: cloud)

        manager.startDownload(dictionary)
        await waitForTerminalState(manager)

        guard case .downloaded = manager.states[dictionary] else {
            XCTFail("Expected downloaded state after retrying past a transient failure"); return
        }
        XCTAssertEqual(cloud.fetchCallCount, 3, "1 failed attempt + 1 successful page + 1 exhausting empty page")
    }

    func testPageFetchRetry_decodingErrorFailsImmediatelyWithoutRetrying() async {
        let cloud = MockCloudSource()
        cloud.totalCount = 1
        cloud.errorForAttempt = [1: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))]
        let manager = makeManager(cloud: cloud)

        manager.startDownload(dictionary)
        await waitForTerminalState(manager)

        guard case .failed = manager.states[dictionary] else {
            XCTFail("Expected failed state"); return
        }
        XCTAssertEqual(cloud.fetchCallCount, 1, "A DecodingError is a programming-error class of failure — no retry")
    }

    // MARK: - Rate limiting

    func testStartDownload_rateLimited_emitsEffectAndSkipsNetwork() async {
        var allowed = true
        var guardCount = 0
        while allowed && guardCount < 10 {
            allowed = storage.recordDownloadAttempt()
            guardCount += 1
        }
        XCTAssertFalse(allowed, "Rate limit should eventually reject after repeated attempts")

        let cloud = MockCloudSource()
        let manager = makeManager(cloud: cloud)

        let exp = expectation(description: "rate limited effect")
        manager.effectSubject
            .sink { effect in
                if case .rateLimited = effect { exp.fulfill() }
            }
            .store(in: &cancellables)

        manager.startDownload(dictionary)
        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertEqual(cloud.fetchCallCount, 0, "A rate-limited attempt must not touch the network")
        if case .downloading = manager.states[dictionary] {
            XCTFail("A rate-limited attempt must not transition into downloading state")
        }
    }
}

// MARK: - Mock

private final class MockCloudSource: SKOfflineDictionaryCloudFetching {
    var totalCount = 0
    var pages: [[SKCloudWordRow]] = []
    var errorForAttempt: [Int: Error] = [:]
    private(set) var fetchCallCount = 0
    private(set) var requestedCursors: [Int64] = []

    func count(for dictionary: ESKVocabularyType) async throws -> Int {
        totalCount
    }

    func fetchPage(for dictionary: ESKVocabularyType, cursor: Int64, pageSize: Int) async throws -> [SKCloudWordRow] {
        fetchCallCount += 1
        requestedCursors.append(cursor)
        if let error = errorForAttempt[fetchCallCount] {
            throw error
        }
        guard !pages.isEmpty else { return [] }
        return pages.removeFirst()
    }
}
