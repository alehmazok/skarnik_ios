//
//  SKStressResolver.swift
//  Skarnik
//
//  Word stress ("На́ціск") dual-source cascade: try starnik.by first, and only fall back
//  to the skarnik_admin cloud API if the primary has no exact match or is unreachable.
//  See skarnik_flutter/shared/stress_spec.md for the reference behavior this mirrors.
//

import Foundation
import os.log

private let stressLog = OSLog(subsystem: "by.skarnik", category: "Stress")

private func skStressLog(_ message: @autoclosure () -> String, type: OSLogType = .debug) {
    #if DEBUG
    os_log("%{public}@", log: stressLog, type: type, "🪲 " + message())
    #endif
}

// MARK: - Domain

enum SKStressSource: String {
    case api
    case cloud
}

// `id` is only unique within its own source — never compare/reuse ids across sources.
struct SKStressWordEntry: Equatable {
    let id: Int
    let lemma: String   // unstressed form, used for exact-match comparison
    let word: String    // stressed form, used for display
    let tableName: String?
    let source: SKStressSource

    var wordTypeLabel: String? {
        guard let tableName else { return nil }
        return SKLocalization.wordType(tableName)
    }
}

struct SKStressRow: Identifiable {
    let id = UUID()
    let title: String   // HTML
    let content: String // HTML
}

enum SKStressError: Error {
    case networkError
}

// MARK: - Backend protocol

protocol SKStressBackend {
    var source: SKStressSource { get }
    func resolveWordList(_ word: String) async throws -> [SKStressWordEntry]
    func stressTable(_ wordId: Int) async throws -> [SKStressRow]
}

// MARK: - Cloud fallback: skarnik_admin (Django/MariaDB), not Supabase — see stress_spec.md §2

struct SKCloudStressBackend: SKStressBackend {
    let source: SKStressSource = .cloud

    private static let baseUrl = "https://skarnik.play.of.by"

    private struct WordListEntry: Decodable {
        let id: Int
        let word: String   // unstressed — field names are inverted vs the primary source
        let lemma: String  // stressed
        let table_name: String?
    }

    private struct StressTableResponse: Decodable {
        struct Row: Decodable {
            let title: String
            let content: String
        }
        let rows: [Row]
    }

    func resolveWordList(_ word: String) async throws -> [SKStressWordEntry] {
        guard let escapedWord = word.lowercased().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return []
        }
        let urlStr = "\(Self.baseUrl)/api/stress_words/?word=\(escapedWord)"
        skStressLog("[Cloud] Resolving word list: \(urlStr)")
        guard let data = await URLSession.skarnikDownload(urlStr: urlStr) else {
            skStressLog("[Cloud] Network error for url: \(urlStr)", type: .error)
            throw SKStressError.networkError
        }
        let entries = try JSONDecoder().decode([WordListEntry].self, from: data)
        // Swap word/lemma here so the shared domain model stays consistent across both
        // sources: lemma = unstressed, word = stressed. Get this wrong and cloud-sourced
        // exact matches silently never match.
        return entries.map {
            SKStressWordEntry(id: $0.id, lemma: $0.word, word: $0.lemma, tableName: $0.table_name, source: .cloud)
        }
    }

    func stressTable(_ wordId: Int) async throws -> [SKStressRow] {
        let urlStr = "\(Self.baseUrl)/api/stress_words/\(wordId)/"
        skStressLog("[Cloud] Fetching stress table: \(urlStr)")
        guard let data = await URLSession.skarnikDownload(urlStr: urlStr) else {
            skStressLog("[Cloud] Network error for url: \(urlStr)", type: .error)
            throw SKStressError.networkError
        }
        let response = try JSONDecoder().decode(StressTableResponse.self, from: data)
        return response.rows.map { SKStressRow(title: $0.title, content: $0.content) }
    }
}

// MARK: - Orchestration (stress_spec.md §4a word resolution / §4b table fetch)

enum SKStressListResult {
    case success([SKStressWordEntry])
    case notFound
    case error(Error)
}

enum SKStressTableResult {
    case success([SKStressRow])
    case notFound
    case error(Error)
}

struct SKStressResolver {
    let primary: SKStressBackend
    let fallback: SKStressBackend

    static let shared = SKStressResolver(primary: SKStarnikStressBackend(), fallback: SKCloudStressBackend())

    // Never merges primary/fallback results: primary's exact matches win outright; the
    // fallback is only consulted when primary errored or had no exact match at all.
    func resolveWordList(_ word: String) async -> SKStressListResult {
        do {
            let entries = try await primary.resolveWordList(word)
            let exact = entries.filter { $0.lemma == word }
            if !exact.isEmpty {
                skStressLog("[Resolver] Primary exact match for \"\(word)\"")
                return .success(exact)
            }
            skStressLog("[Resolver] Primary had no exact match for \"\(word)\", trying fallback")
        } catch {
            skStressLog("[Resolver] Primary failed for \"\(word)\": \(error), trying fallback", type: .error)
        }

        do {
            let entries = try await fallback.resolveWordList(word)
            let exact = entries.filter { $0.lemma == word }
            if exact.isEmpty {
                skStressLog("[Resolver] Fallback had no exact match for \"\(word)\"")
                return .notFound
            }
            skStressLog("[Resolver] Fallback exact match for \"\(word)\"")
            return .success(exact)
        } catch {
            skStressLog("[Resolver] Fallback failed for \"\(word)\": \(error)", type: .error)
            return .error(error)
        }
    }

    // Routes strictly by the entry's source — an id is meaningless against the other
    // source's numbering scheme, so there is no cross-source retry on failure.
    func stressTable(_ entry: SKStressWordEntry) async -> SKStressTableResult {
        let backend: SKStressBackend = entry.source == .api ? primary : fallback
        do {
            let rows = try await backend.stressTable(entry.id)
            return rows.isEmpty ? .notFound : .success(rows)
        } catch {
            skStressLog("[Resolver] Table fetch failed for id \(entry.id) (\(entry.source)): \(error)", type: .error)
            return .error(error)
        }
    }
}
