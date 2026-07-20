//
//  SKOfflineDictionaryStore.swift
//  Skarnik
//

import Foundation
import SQLite

struct SKDownloadedWord {
    let externalId: Int64
    let stress: String?
    let translation: String
    let redirectTo: String?
}

enum SKOfflineDictionaryStoreError: Error {
    /// The local database could not be opened/provisioned (disk full, permissions, corruption).
    /// Offline download is a nice-to-have on top of network lookups, not a hard dependency, so
    /// callers degrade to "no local cache" rather than the app crashing.
    case unavailable
}

/// Local on-device cache of fully-downloaded dictionaries. Keyed by a composite
/// `(langId, externalId)` — `externalId` alone is not unique across dictionaries, since each
/// direction has its own id sequence in the cloud `main_word` table.
final class SKOfflineDictionaryStore {
    static let shared = SKOfflineDictionaryStore()

    private let db: Connection?
    // SQLite.swift's `Connection` isn't safe under concurrent access from multiple threads — this
    // is a `static let shared` singleton, so anything reaching it from outside the MainActor
    // (background lookups, tests) must be serialized against it. All work also runs off whatever
    // thread/actor called in, so this never blocks the calling `@MainActor` download manager.
    private let queue = DispatchQueue(label: "by.skarnik.SKOfflineDictionaryStore")

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbUrl = directory.appendingPathComponent("offline_dictionary.db")

        var connection: Connection?
        do {
            let opened = try Connection(dbUrl.path)
            try opened.run("""
                CREATE TABLE IF NOT EXISTS downloaded_word (
                    lang_id INTEGER NOT NULL,
                    external_id INTEGER NOT NULL,
                    stress TEXT,
                    translation TEXT NOT NULL,
                    redirect_to TEXT,
                    PRIMARY KEY (lang_id, external_id)
                )
            """)
            connection = opened
        } catch {
            connection = nil
        }
        self.db = connection

        guard connection != nil else { return }
        // Re-downloadable cache data — excluded from iCloud/iTunes backup per Apple's guidance.
        var excludedUrl = dbUrl
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? excludedUrl.setResourceValues(resourceValues)
    }

    func wordCount(langId: Int) async -> Int {
        await runOnQueue { db in
            guard let count = try? db.scalar("SELECT COUNT(*) FROM downloaded_word WHERE lang_id=?", langId) as? Int64 else {
                return 0
            }
            return Int(count)
        } ?? 0
    }

    func word(langId: Int, externalId: Int64) async -> SKDownloadedWord? {
        await runOnQueue { db -> SKDownloadedWord? in
            guard let rows = try? db.prepare(
                "SELECT external_id, stress, translation, redirect_to FROM downloaded_word WHERE lang_id=? AND external_id=? LIMIT 1",
                langId, externalId
            ), let row = rows.next() else {
                return nil
            }
            guard let externalId = row[0] as? Int64, let translation = row[2] as? String else {
                return nil
            }
            return SKDownloadedWord(
                externalId: externalId,
                stress: row[1] as? String,
                translation: translation,
                redirectTo: row[3] as? String
            )
        } ?? nil
    }

    /// Upsert-replaces on `(langId, externalId)` conflict — safe to call for a re-download or for
    /// a word already present from a prior partial download.
    func upsert(_ words: [SKDownloadedWord], langId: Int) async throws {
        guard !words.isEmpty else { return }
        guard let db else { throw SKOfflineDictionaryStoreError.unavailable }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try db.transaction {
                        for word in words {
                            try db.run(
                                "INSERT OR REPLACE INTO downloaded_word (lang_id, external_id, stress, translation, redirect_to) VALUES (?, ?, ?, ?, ?)",
                                langId, word.externalId, word.stress, word.translation, word.redirectTo
                            )
                        }
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteAll(langId: Int) async {
        _ = await runOnQueue { db -> Void in
            try? db.run("DELETE FROM downloaded_word WHERE lang_id=?", langId)
        }
    }

    /// Runs `work` against the connection on the private serial queue — off whatever thread/actor
    /// called in, so this never blocks the caller. Returns `nil` if the database is unavailable.
    private func runOnQueue<T>(_ work: @escaping (Connection) -> T) async -> T? {
        guard let db else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: work(db))
            }
        }
    }
}
