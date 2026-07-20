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

/// Local on-device cache of fully-downloaded dictionaries. Keyed by a composite
/// `(langId, externalId)` — `externalId` alone is not unique across dictionaries, since each
/// direction has its own id sequence in the cloud `main_word` table.
final class SKOfflineDictionaryStore {
    static let shared = SKOfflineDictionaryStore()

    private let db: Connection
    // SQLite.swift's `Connection` isn't safe under concurrent access from multiple threads — this
    // is a `static let shared` singleton, so anything reaching it from outside the MainActor
    // (background lookups, tests) must be serialized against it. Mirrors the `cacheLock` pattern
    // `SKVocabularyIndex` uses for its own thread-safety concern.
    private let queue = DispatchQueue(label: "by.skarnik.SKOfflineDictionaryStore")

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbUrl = directory.appendingPathComponent("offline_dictionary.db")
        self.db = try! Connection(dbUrl.path)

        try! db.run("""
            CREATE TABLE IF NOT EXISTS downloaded_word (
                lang_id INTEGER NOT NULL,
                external_id INTEGER NOT NULL,
                stress TEXT,
                translation TEXT NOT NULL,
                redirect_to TEXT,
                PRIMARY KEY (lang_id, external_id)
            )
        """)

        // Re-downloadable cache data — excluded from iCloud/iTunes backup per Apple's guidance.
        var excludedUrl = dbUrl
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? excludedUrl.setResourceValues(resourceValues)
    }

    func wordCount(langId: Int) -> Int {
        queue.sync {
            guard let count = try? db.scalar("SELECT COUNT(*) FROM downloaded_word WHERE lang_id=?", langId) as? Int64 else {
                return 0
            }
            return Int(count)
        }
    }

    func word(langId: Int, externalId: Int64) -> SKDownloadedWord? {
        queue.sync {
            guard let rows = try? db.prepare(
                "SELECT external_id, stress, translation, redirect_to FROM downloaded_word WHERE lang_id=? AND external_id=? LIMIT 1",
                langId, externalId
            ), let row = rows.next() else {
                return nil
            }

            return SKDownloadedWord(
                externalId: row[0] as! Int64,
                stress: row[1] as? String,
                translation: row[2] as! String,
                redirectTo: row[3] as? String
            )
        }
    }

    /// Upsert-replaces on `(langId, externalId)` conflict — safe to call for a re-download or for
    /// a word already present from a prior partial download.
    func upsert(_ words: [SKDownloadedWord], langId: Int) throws {
        guard !words.isEmpty else { return }
        try queue.sync {
            try db.transaction {
                for word in words {
                    try db.run(
                        "INSERT OR REPLACE INTO downloaded_word (lang_id, external_id, stress, translation, redirect_to) VALUES (?, ?, ?, ?, ?)",
                        langId, word.externalId, word.stress, word.translation, word.redirectTo
                    )
                }
            }
        }
    }

    func deleteAll(langId: Int) {
        queue.sync {
            try? db.run("DELETE FROM downloaded_word WHERE lang_id=?", langId)
        }
    }
}
