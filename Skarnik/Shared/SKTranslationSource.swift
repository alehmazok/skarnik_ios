//
//  SKTranslationSource.swift
//  Skarnik
//
//  Created by Logout on 11.10.22.
//

import SwiftSoup
import UIKit
import os.log

private let translationLog = OSLog(subsystem: "by.skarnik", category: "TranslationSource")

private func skLog(_ message: @autoclosure () -> String, type: OSLogType = .debug) {
    #if DEBUG
    os_log("%{public}@", log: translationLog, type: type, "🪲 " + message())
    #endif
}

// MARK: - Article colours

/// How headwords and translated words are highlighted in a translation article (Settings).
/// Same choice as the Android app: system colours, or the Skarnik red.
enum SKArticleColorTheme: String, CaseIterable {
    /// Bold text in the primary label colour; red stays for interactive elements only (default).
    case system
    /// The Skarnik red accent, as in earlier app versions.
    case skarnikRed

    static let userDefaultsKey = "articleColorTheme"

    static var current: SKArticleColorTheme {
        UserDefaults.standard.string(forKey: userDefaultsKey).flatMap(SKArticleColorTheme.init(rawValue:)) ?? .system
    }
}

// MARK: - Domain Types

struct SKSkarnikTranslation {
    let word: SKWord
    let url: String
    let html: String
    var stress: String? = nil
    var sourceName: String = ""

    var sharingUrl: String {
        Self.pageUrl(vocabularyType: word.lang_id, wordId: word.word_id) ?? url
    }

    /// The entry's page on skarnik.app (`https://skarnik.app/r/belrus/27890`): the address shared,
    /// logged and shown for an entry.
    static func pageUrl(vocabularyType: ESKVocabularyType, wordId: Int64) -> String? {
        guard let path = vocabularyType.skarnikId else { return nil }
        return "https://skarnik.app/r/\(path)/\(wordId)"
    }

    /// The word as it goes into a share: the stressed form when known, else the plain word.
    var shareTitle: String {
        if let stress = stress, !stress.isEmpty { return stress }
        return word.word
    }

    /// Plain-text form of a share, «добразычлівасць — https://skarnik.app/r/belrus/27890», for
    /// targets that only take one string (and as the reference payload in docs/tests).
    var shareText: String {
        "\(shareTitle) — \(sharingUrl)"
    }

    /// The translation as styled text (SwiftSoup, no WebKit), built off the main thread.
    /// Pass `traits` from the view so the text follows Dynamic Type and Bold Text; colours are
    /// dynamic and follow dark mode and Increase Contrast on their own.
    /// The Belarusian words are linked to their entries (`wordLinks`), looked up on the same background task.
    func renderedText(theme: SKArticleColorTheme = .current,
                      traits: UITraitCollection? = nil) async -> NSAttributedString {
        let html = self.html
        let abbreviations = SKAbbreviationScheme(word.lang_id)
        let translation = self
        return await Task.detached(priority: .userInitiated) {
            let links = translation.wordLinks.compactMapValues(Self.url(of:))
            return SKTranslationRenderer.render(html: html, theme: theme, traits: traits,
                                                abbreviations: abbreviations, wordLinks: links)
        }.value
    }

    /// How a word is looked up in the index: lowercase, without the stress mark admin-edited entries show («я́нтар»).
    static func wordKey(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{0301}", with: "").lowercased()
    }

    /// The link a tapped word opens; `SKWordDetailsViewModel.handleUrl` routes it.
    static func url(of word: SKWord) -> URL? {
        pageUrl(vocabularyType: word.lang_id, wordId: word.word_id).flatMap { URL(string: $0) }
    }

    /// The Belarusian words of a Бел-Рус or Рус-Бел translation that open their own entry, by `wordKey`:
    /// the same words as the stress candidates (`#831b03` runs; Рус-Бел `data-word` when present), found as
    /// Бел-Рус (else ТСБМ) headwords in one index query. The entry itself is left out. Same rules as
    /// skarnik_android (`FindWordLinksUseCase`).
    var wordLinks: [String: SKWord] {
        let texts: [String]
        switch word.lang_id {
        case .bel_rus: texts = Self.headwordColouredWords(inHtml: html)
        case .rus_bel:
            let dataWords = Self.dataWords(inHtml: html)
            texts = dataWords.isEmpty ? Self.headwordColouredWords(inHtml: html) : dataWords
        default: return [:]
        }
        let keys = Set(texts.map(Self.wordKey))
        guard !keys.isEmpty else { return [:] }
        let me = word
        return SKVocabularyIndex.shared.belarusianWords(keys)
            .filter { !($0.value.word_id == me.word_id && $0.value.lang_id == me.lang_id) }
    }

    /// The single words of the `#831b03` `font`/`span` runs, split at commas, before any index check.
    static func headwordColouredWords(inHtml html: String) -> [String] {
        guard let doc = try? SwiftSoup.parse(html), let elements = try? doc.select("font, span") else { return [] }
        var words: [String] = []
        for element in elements where SKTranslationRenderer.isHeadwordColoured(element) {
            let text = (try? element.text()) ?? ""
            for part in text.components(separatedBy: ",") {
                let word = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty, word.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
                      !words.contains(word) else { continue }
                words.append(word)
            }
        }
        return words
    }

    /// The single-word `data-word` attributes (set by skarnik_admin's `find_inner_stress`).
    static func dataWords(inHtml html: String) -> [String] {
        guard let doc = try? SwiftSoup.parse(html), let elements = try? doc.select("[data-word]") else { return [] }
        var words: [String] = []
        for element in elements {
            let word = ((try? element.attr("data-word")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, word.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
                  !words.contains(word) else { continue }
            words.append(word)
        }
        return words
    }

    var attributedString: NSAttributedString? {
        get async { await renderedText() }
    }

    /// Scans `html` for `#831b03`-colored `font`/`span` elements, which mark Belarusian
    /// word forms in the legacy dictionary markup, and returns the ones present in the local
    /// vocabulary index (deduped against `existing`).
    private static func colorMarkedBelWords(inHtml html: String, excluding existing: [String] = []) -> [String] {
        guard let doc = try? SwiftSoup.parse(html) else { return [] }
        var found: [String] = []
        let fonts: Elements = (try? doc.select("font, span")) ?? Elements()
        for fontContent in fonts {
            let colorAttr = (try? fontContent.attr("color"))?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")) ?? ""
            let styleAttr = (try? fontContent.attr("style")) ?? ""
            let styleColorMatch = styleAttr.range(of: "color:\\s*#?831b03", options: [.regularExpression, .caseInsensitive]) != nil
            guard colorAttr == "831b03" || styleColorMatch,
                  let text = try? fontContent.text().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else { continue }

            for candidate in text.components(separatedBy: ",") {
                let candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !candidate.isEmpty, !candidate.contains(" "),
                      !existing.contains(candidate), !found.contains(candidate) else { continue }
                if SKVocabularyIndex.shared.word(candidate, vocabularyType: .bel_definition) != nil ||
                   SKVocabularyIndex.shared.word(candidate, vocabularyType: .bel_rus) != nil {
                    found.append(candidate)
                }
            }
        }
        return found
    }

    var belWords: [String] {
        get {
            let word = self.word

            var words: [String] = []

            if word.lang_id == .bel_rus || word.lang_id == .bel_definition {
                if !word.word.contains(" ") {
                    words = [word.word]
                }
                // bel_rus translations list additional Belarusian synonyms in the same
                // #831b03 markup rus_bel entries use — surface those as stress candidates too.
                if word.lang_id == .bel_rus {
                    words += Self.colorMarkedBelWords(inHtml: self.html, excluding: words)
                }
            } else if word.lang_id == .rus_bel {
                let html = self.html
                if let doc = try? SwiftSoup.parse(html),
                   let dataWordElements = try? doc.select("[data-word]"),
                   !dataWordElements.isEmpty {
                    var foundWords: [String] = []
                    for element in dataWordElements {
                        let candidate = (try? element.attr("data-word").trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                        guard !candidate.isEmpty, !candidate.contains(" "),
                              !foundWords.contains(candidate) else { continue }
                        if SKVocabularyIndex.shared.word(candidate, vocabularyType: .bel_definition) != nil ||
                           SKVocabularyIndex.shared.word(candidate, vocabularyType: .bel_rus) != nil {
                            foundWords.append(candidate)
                        }
                    }
                    words = foundWords
                } else {
                    words = Self.colorMarkedBelWords(inHtml: html)
                }
            }
            words = words.sorted { str1, str2 in
                return str1.lowercased().compare(str2.lowercased()) == .orderedAscending
            }
            return words
        }
    }
}

enum SKSkarnikError: Error, Equatable {
    case nextWordIndexRequired
    case networkError
    /// A source found a record whose `redirect_to` is set: the word was merged into another entry.
    /// Terminal at whichever tier detects it — never resolved inline by the source, never treated
    /// as a miss/fallthrough. The caller re-triggers a fresh top-of-cascade lookup for `redirectTo`.
    case redirect(word: SKWord, redirectTo: String)
}

extension String {
    /// Extracts trailing numeric id from a redirect path like "/tsbm/3528".
    var trailingWordId: Int64? {
        guard let lastComponent = self.split(separator: "/").last else { return nil }
        return Int64(lastComponent)
    }
}

// MARK: - Supabase Config

enum SKSupabaseConfig {
    static let projectURL = "https://cxblykicbulwcilncgxd.supabase.co"
    static let apiKey = "sb_publishable_aJ4mKd11QBgS0A3PG7P1HA_c8JOBqfo"
    static let headers = [
        "apikey": apiKey,
        "Authorization": "Bearer \(apiKey)"
    ]
}

// MARK: - Protocol

protocol SKTranslationSource {
    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation?
}

// MARK: - API Source

struct SKApiTranslationSource: SKTranslationSource {

    private struct APIResponse: Decodable {
        let translation: String?
        let redirect_to: String?
        let stress: String?
    }

    static func url(vocabularyType: ESKVocabularyType, wordId: Int64) -> String? {
        guard let skarnikId = vocabularyType.skarnikId else { return nil }
        return "https://skarnik.play.of.by/api/words/\(skarnikId)/\(wordId)/"
    }

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        guard let urlStr = Self.url(vocabularyType: word.lang_id, wordId: word.word_id) else {
            return nil
        }

        skLog("[API] Fetching word: \"\(word.word)\" (id: \(word.word_id), lang: \(word.lang_id.rawValue)) url: \(urlStr)")

        guard let data = await URLSession.skarnikDownload(urlStr: urlStr) else {
            skLog("[API] Network error for url: \(urlStr)", type: .error)
            throw SKSkarnikError.networkError
        }

        let response = try JSONDecoder().decode(APIResponse.self, from: data)

        if let redirectPath = response.redirect_to {
            skLog("[API] Redirect — terminal, redirectTo: \(redirectPath)")
            throw SKSkarnikError.redirect(word: word, redirectTo: redirectPath)
        }

        guard let html = response.translation else {
            return nil
        }

        let displayUrl = SKSkarnikTranslation.pageUrl(vocabularyType: word.lang_id, wordId: word.word_id) ?? urlStr
        skLog("[API] Parsed successfully for word: \"\(word.word)\" (id: \(word.word_id))")
        return SKSkarnikTranslation(word: word, url: displayUrl, html: html, stress: response.stress, sourceName: "api")
    }
}

// MARK: - Supabase Source

struct SKSupabaseTranslationSource: SKTranslationSource {
    private struct SupabaseResponse: Decodable {
        let translation: String?
        let redirect_to: String?
        let stress: String?
    }

    static func url(vocabularyType: ESKVocabularyType, wordId: Int64) -> String? {
        guard let skarnikId = vocabularyType.skarnikId else { return nil }
        return "\(SKSupabaseConfig.projectURL)/rest/v1/main_word?external_id=eq.\(wordId)&direction=eq.\(skarnikId)"
    }

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        guard let urlStr = Self.url(vocabularyType: word.lang_id, wordId: word.word_id) else {
            return nil
        }

        skLog("[Supabase] Fetching word: \"\(word.word)\" (id: \(word.word_id), lang: \(word.lang_id.rawValue)) url: \(urlStr)")

        guard let data = await URLSession.skarnikDownload(urlStr: urlStr, headers: SKSupabaseConfig.headers) else {
            skLog("[Supabase] Network error for url: \(urlStr)", type: .error)
            throw SKSkarnikError.networkError
        }

        let responses = try JSONDecoder().decode([SupabaseResponse].self, from: data)
        guard let response = responses.first else {
            return nil
        }

        if let redirectPath = response.redirect_to {
            skLog("[Supabase] Redirect — terminal, redirectTo: \(redirectPath)")
            throw SKSkarnikError.redirect(word: word, redirectTo: redirectPath)
        }

        guard let html = response.translation else {
            return nil
        }

        let displayUrl = SKSkarnikTranslation.pageUrl(vocabularyType: word.lang_id, wordId: word.word_id) ?? urlStr
        skLog("[Supabase] Parsed successfully for word: \"\(word.word)\" (id: \(word.word_id))")
        return SKSkarnikTranslation(word: word, url: displayUrl, html: html, stress: response.stress, sourceName: "supabase")
    }
}

// MARK: - Fallback Chain

struct SKFallbackTranslationSource: SKTranslationSource {
    let sources: [any SKTranslationSource]

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        skLog("[Fallback] Starting fetch for word: \"\(word.word)\" (id: \(word.word_id), lang: \(word.lang_id.rawValue)) — \(sources.count) source(s) available")
        var lastError: Error?
        for source in sources {
            let sourceName = String(describing: type(of: source))
            skLog("[Fallback] Trying \(sourceName)")
            do {
                if let result = try await source.wordTranslation(word) {
                    skLog("[Fallback] \(sourceName) succeeded")
                    return result
                }
                skLog("[Fallback] \(sourceName) returned nil, trying next")
            } catch SKSkarnikError.redirect(let word, let redirectTo) {
                skLog("[Fallback] \(sourceName) hit a terminal redirect — stopping cascade")
                throw SKSkarnikError.redirect(word: word, redirectTo: redirectTo)
            } catch {
                skLog("[Fallback] \(sourceName) failed with error: \(error), trying next", type: .error)
                lastError = error
            }
        }
        skLog("[Fallback] All sources exhausted for word: \"\(word.word)\"", type: lastError == nil ? .default : .error)
        if let lastError { throw lastError }
        return nil
    }

    /// Supabase, then the skarnik_admin API: the order every Skarnik app uses after the local store
    /// (Aleh, 2026-11-05).
    static let shared = SKFallbackTranslationSource(sources: [
        SKSupabaseTranslationSource(),
        SKApiTranslationSource()
    ])
}
