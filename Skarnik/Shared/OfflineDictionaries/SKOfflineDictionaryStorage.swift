//
//  SKOfflineDictionaryStorage.swift
//  Skarnik
//

import Foundation

/// UserDefaults-backed persistence for the offline-download feature: per-dictionary resume
/// cursors, download-attempt rate-limit timestamps, and the one-time promo badge flag.
final class SKOfflineDictionaryStorage {
    static let shared = SKOfflineDictionaryStorage()

    private static let cursorsKey = "offlineDictionaryCursorsKey"
    private static let downloadAttemptsKey = "offlineDictionaryDownloadAttemptsKey"
    private static let promoSeenKey = "offlineDictionariesPromoSeenKey"

    private static let rateLimitWindow: TimeInterval = 5 * 60
    private static let rateLimitMaxAttempts = 4

    private let defaults: UserDefaults

    /// `defaults` is injectable so tests can use an isolated `UserDefaults` suite instead of
    /// `.standard` — the XCTest host app shares the real app's UserDefaults domain, so writing
    /// rate-limit attempt timestamps there during a test run would silently eat into the real
    /// app's download-attempt budget.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Cursor

    func cursor(for dictionary: ESKVocabularyType) -> Int64? {
        loadCursors()[dictionary.rawValue]
    }

    func setCursor(_ cursor: Int64, for dictionary: ESKVocabularyType) {
        var cursors = loadCursors()
        cursors[dictionary.rawValue] = cursor
        saveCursors(cursors)
    }

    func clearCursor(for dictionary: ESKVocabularyType) {
        var cursors = loadCursors()
        cursors.removeValue(forKey: dictionary.rawValue)
        saveCursors(cursors)
    }

    private func loadCursors() -> [Int: Int64] {
        guard let data = defaults.object(forKey: Self.cursorsKey) as? Data,
              let cursors = try? JSONDecoder().decode([Int: Int64].self, from: data) else {
            return [:]
        }
        return cursors
    }

    private func saveCursors(_ cursors: [Int: Int64]) {
        guard let data = try? JSONEncoder().encode(cursors) else { return }
        defaults.set(data, forKey: Self.cursorsKey)
    }

    // MARK: - Rate limiting

    /// Prunes stale attempt timestamps, then checks/records a new attempt: window 5 minutes, max
    /// 4 attempts. Always persists the pruned list, even on rejection, so stale entries don't
    /// linger. Returns whether this attempt is allowed. A rejected attempt is not itself recorded.
    func recordDownloadAttempt(now: Date = Date()) -> Bool {
        var attempts = loadAttempts().filter { now.timeIntervalSince($0) < Self.rateLimitWindow }
        guard attempts.count < Self.rateLimitMaxAttempts else {
            saveAttempts(attempts)
            return false
        }
        attempts.append(now)
        saveAttempts(attempts)
        return true
    }

    private func loadAttempts() -> [Date] {
        guard let data = defaults.object(forKey: Self.downloadAttemptsKey) as? Data,
              let attempts = try? JSONDecoder().decode([Date].self, from: data) else {
            return []
        }
        return attempts
    }

    private func saveAttempts(_ attempts: [Date]) {
        guard let data = try? JSONEncoder().encode(attempts) else { return }
        defaults.set(data, forKey: Self.downloadAttemptsKey)
    }

    // MARK: - Promo badge

    var promoSeen: Bool {
        defaults.bool(forKey: Self.promoSeenKey)
    }

    func markPromoSeen() {
        defaults.set(true, forKey: Self.promoSeenKey)
    }
}
