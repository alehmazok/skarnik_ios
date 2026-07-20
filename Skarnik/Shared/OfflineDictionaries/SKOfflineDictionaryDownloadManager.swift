//
//  SKOfflineDictionaryDownloadManager.swift
//  Skarnik
//

import Foundation
import Combine

enum SKOfflineDictionaryState {
    case notDownloaded
    case downloading(done: Int, total: Int)
    case downloaded(count: Int)
    case failed(String)
}

enum SKOfflineDictionaryEffect {
    case rateLimited
}

/// App-scoped download orchestrator — a download keeps running (and `states` keeps updating) even
/// if the user navigates away from the Settings tab, since this is a singleton `ObservableObject`
/// rather than screen-owned state.
@MainActor
final class SKOfflineDictionaryDownloadManager: ObservableObject {
    static let shared = SKOfflineDictionaryDownloadManager()

    static let downloadableDictionaries: [ESKVocabularyType] = [.rus_bel, .bel_rus, .bel_definition]

    private static let pageSize = SKOfflineDictionaryCloudSource.defaultPageSize
    private static let maxPageAttempts = 5

    @Published private(set) var states: [ESKVocabularyType: SKOfflineDictionaryState] = [:]
    let effectSubject = PassthroughSubject<SKOfflineDictionaryEffect, Never>()

    private let cloudSource: any SKOfflineDictionaryCloudFetching
    private let store: SKOfflineDictionaryStore
    private let storage: SKOfflineDictionaryStorage
    private var runningTasks: [ESKVocabularyType: Task<Void, Never>] = [:]

    init(
        cloudSource: any SKOfflineDictionaryCloudFetching = SKOfflineDictionaryCloudSource(),
        store: SKOfflineDictionaryStore = .shared,
        storage: SKOfflineDictionaryStorage = .shared
    ) {
        self.cloudSource = cloudSource
        self.store = store
        self.storage = storage
    }

    /// Counts local rows per dictionary and seeds `.downloaded` state for any with data. Existing
    /// `.failed`/`.notDownloaded` state is left as-is (not reset) for a dictionary with no local
    /// data, and an in-progress download is never clobbered.
    ///
    /// A dictionary with local rows but a still-persisted cursor was interrupted mid-download
    /// (e.g. the app was killed) rather than completed — the cursor is only cleared once the fetch
    /// loop is fully exhausted (see `runDownload`). Such a dictionary must not show as `.downloaded`
    /// — that would render a checkmark for a partial word count with no way to resume, since a
    /// "Downloaded" row only offers delete. Falling back to `.notDownloaded` keeps it tappable,
    /// and `startDownload` already resumes correctly from the persisted cursor.
    func refreshDownloadedCounts() async {
        for dictionary in Self.downloadableDictionaries {
            guard runningTasks[dictionary] == nil else { continue }
            let count = await store.wordCount(langId: dictionary.rawValue)
            let isInterrupted = storage.cursor(for: dictionary) != nil
            if count > 0 && !isInterrupted {
                states[dictionary] = .downloaded(count: count)
            } else if states[dictionary] == nil {
                states[dictionary] = .notDownloaded
            }
        }
    }

    func startDownload(_ dictionary: ESKVocabularyType) {
        // Logged unconditionally, before the rate-limit check, so it fires even for rejected attempts.
        SKAnalyticsManager.logOfflineDictionaryDownloadClick(
            dictName: dictionary.name ?? "",
            dictPath: dictionary.skarnikId ?? ""
        )

        guard runningTasks[dictionary] == nil else { return }

        guard storage.recordDownloadAttempt() else {
            effectSubject.send(.rateLimited)
            return
        }

        runningTasks[dictionary] = Task { [weak self] in
            await self?.runDownload(dictionary)
        }
    }

    func delete(_ dictionary: ESKVocabularyType) async {
        runningTasks[dictionary]?.cancel()
        runningTasks[dictionary] = nil
        await store.deleteAll(langId: dictionary.rawValue)
        storage.clearCursor(for: dictionary)
        states[dictionary] = .notDownloaded
    }

    // MARK: - Private

    private func runDownload(_ dictionary: ESKVocabularyType) async {
        let langId = dictionary.rawValue
        do {
            let total = try await cloudSource.count(for: dictionary)
            let localCount = await store.wordCount(langId: langId)
            var startCursor = storage.cursor(for: dictionary) ?? 0

            // Stale-cursor guard: a persisted cursor with no local data means local storage was
            // wiped outside the app's own delete flow — resuming from it would silently skip words.
            if startCursor > 0 && localCount == 0 {
                storage.clearCursor(for: dictionary)
                startCursor = 0
            }

            // Fresh start always begins `done` at 0, even with stale pre-existing local rows —
            // a fresh download re-fetches from page 1 and upserts over everything, so counting
            // pre-existing rows here would double-count against `total`. Only a genuine resume
            // (persisted cursor > 0) seeds `done` from `localCount`.
            var done = startCursor > 0 ? localCount : 0
            states[dictionary] = .downloading(done: done, total: total)

            var cursor = startCursor
            while true {
                guard !Task.isCancelled else { return }
                let rows = try await fetchPageWithRetry(dictionary: dictionary, cursor: cursor)
                if rows.isEmpty { break }

                let words = rows.map {
                    SKDownloadedWord(externalId: $0.external_id, stress: $0.stress, translation: $0.translation, redirectTo: $0.redirect_to)
                }
                try await store.upsert(words, langId: langId)

                done += rows.count
                cursor = rows.last!.id
                storage.setCursor(cursor, for: dictionary)
                states[dictionary] = .downloading(done: done, total: total)
            }

            storage.clearCursor(for: dictionary)
            states[dictionary] = .downloaded(count: await store.wordCount(langId: langId))
        } catch {
            states[dictionary] = .failed(error.localizedDescription)
        }
        runningTasks[dictionary] = nil
    }

    /// Retries a transient page-fetch failure up to 5 attempts with linear backoff
    /// (500ms * attemptNumber between attempts). A `DecodingError` is treated as a programming-error
    /// class of failure and fails immediately, without retrying.
    private func fetchPageWithRetry(dictionary: ESKVocabularyType, cursor: Int64) async throws -> [SKCloudWordRow] {
        var lastError: Error?
        for attempt in 1...Self.maxPageAttempts {
            do {
                return try await cloudSource.fetchPage(for: dictionary, cursor: cursor, pageSize: Self.pageSize)
            } catch let decodingError as DecodingError {
                throw decodingError
            } catch {
                lastError = error
                if attempt < Self.maxPageAttempts {
                    let backoffNanoseconds = UInt64(500) * UInt64(attempt) * 1_000_000
                    try? await Task.sleep(nanoseconds: backoffNanoseconds)
                }
            }
        }
        throw lastError ?? SKOfflineDictionaryCloudError.invalidResponse
    }
}
