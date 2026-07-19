//
//  SKStarnikByController.swift
//  Skarnik
//
//  Created by Logout on 16.10.22.
//  Copyright © 2022 Skarnik. All rights reserved.
//

import Foundation
import SwiftSoup

// MARK: - Primary source: starnik.by (live HTML scrape) — stress_spec.md §2

struct SKStarnikStressBackend: SKStressBackend {
    let source: SKStressSource = .api

    private static let baseUrl = "https://starnik.by"

    private struct WordList: Codable {
        struct WordListBody: Codable {
            let lemma: String
            let word: String
            let id: Int
            let table_name: String?
        }
        let word_list: [WordListBody]
    }

    func resolveWordList(_ word: String) async throws -> [SKStressWordEntry] {
        guard let urlStr = Self.wordListUrl(word: word) else {
            return []
        }
        guard let data = await URLSession.skarnikDownload(urlStr: urlStr) else {
            throw SKStressError.networkError
        }
        return try Self.parseWordList(data: data)
    }

    func stressTable(_ wordId: Int) async throws -> [SKStressRow] {
        let urlStr = "\(Self.baseUrl)/pravapis/\(wordId)"
        guard let data = await URLSession.skarnikDownload(urlStr: urlStr) else {
            throw SKStressError.networkError
        }
        return try Self.parseHtml(data: data)
    }

    static func wordListUrl(word: String) -> String? {
        guard let escapedWord = word.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return nil
        }
        return "\(Self.baseUrl)/api/wordList?lemma=\(escapedWord)"
    }

    static func parseWordList(data: Data) throws -> [SKStressWordEntry] {
        let wordList = try JSONDecoder().decode(WordList.self, from: data)
        return wordList.word_list.map {
            SKStressWordEntry(id: $0.id, lemma: $0.lemma, word: $0.word, tableName: $0.table_name, source: .api)
        }
    }

    static func parseHtml(data: Data) throws -> [SKStressRow] {
        var rows: [SKStressRow] = []

        let html = String(data: data, encoding: .utf8) ?? ""
        let doc = try SwiftSoup.parse(html)
        let elementDivWrappers = try doc.getElementsByClass("wrapper")
        let elementTable = (try elementDivWrappers.compactMap { try $0.getElementsByTag("table").first }).first
        let elementRows = try elementTable?.getElementsByTag("tr")
        for elementRow in elementRows?.array() ?? [] {
            let elementColumns = try elementRow.getElementsByTag("td")
            if elementColumns.count != 2 {
                continue
            }
            guard let titleHtml = try elementColumns.first()?.html(),
                  let contentHtml = try elementColumns.last()?.html() else {
                continue
            }
            rows.append(SKStressRow(title: titleHtml, content: contentHtml))
        }
        return rows
    }
}
