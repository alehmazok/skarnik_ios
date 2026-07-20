//
//  SKOfflineDictionaryCloudSource.swift
//  Skarnik
//

import Foundation

struct SKCloudWordRow: Decodable {
    let id: Int64
    let external_id: Int64
    let stress: String?
    let translation: String
    let redirect_to: String?
}

enum SKOfflineDictionaryCloudError: Error {
    case invalidURL
    case invalidResponse
}

/// Abstracts the cloud reads the download manager needs, so tests can inject a mock instead of
/// hitting the network.
protocol SKOfflineDictionaryCloudFetching {
    func count(for dictionary: ESKVocabularyType) async throws -> Int
    func fetchPage(for dictionary: ESKVocabularyType, cursor: Int64, pageSize: Int) async throws -> [SKCloudWordRow]
}

/// Cloud-side reads used by the download flow: exact row count (progress denominator) and
/// cursor-paginated page fetch, both against the same Supabase `main_word` table
/// `SKSupabaseTranslationSource` uses for single-word lookups.
struct SKOfflineDictionaryCloudSource: SKOfflineDictionaryCloudFetching {
    static let defaultPageSize = 5000

    func count(for dictionary: ESKVocabularyType) async throws -> Int {
        guard let path = dictionary.skarnikId,
              let url = URL(string: "\(SKSupabaseConfig.projectURL)/rest/v1/main_word?select=id&direction=eq.\(path)&limit=1") else {
            throw SKOfflineDictionaryCloudError.invalidURL
        }

        var request = URLRequest(url: url)
        SKSupabaseConfig.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("count=exact", forHTTPHeaderField: "Prefer")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SKOfflineDictionaryCloudError.invalidResponse
        }
        // PostgREST returns the exact count in `Content-Range: 0-0/316000` when `Prefer: count=exact`
        // is set, not as response body — the body for this query is just the (irrelevant) single row.
        guard let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
              let totalString = contentRange.split(separator: "/").last,
              let total = Int(totalString) else {
            throw SKOfflineDictionaryCloudError.invalidResponse
        }
        return total
    }

    func fetchPage(for dictionary: ESKVocabularyType, cursor: Int64, pageSize: Int = SKOfflineDictionaryCloudSource.defaultPageSize) async throws -> [SKCloudWordRow] {
        guard let path = dictionary.skarnikId,
              let url = URL(string: "\(SKSupabaseConfig.projectURL)/rest/v1/main_word?select=id,external_id,stress,translation,redirect_to&direction=eq.\(path)&id=gt.\(cursor)&order=id.asc&limit=\(pageSize)") else {
            throw SKOfflineDictionaryCloudError.invalidURL
        }

        var request = URLRequest(url: url)
        SKSupabaseConfig.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SKOfflineDictionaryCloudError.invalidResponse
        }
        return try JSONDecoder().decode([SKCloudWordRow].self, from: data)
    }
}
