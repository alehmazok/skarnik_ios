//
//  SKLocalTranslationSource.swift
//  Skarnik
//

import Foundation

/// First tier of the lookup cascade: serves a translation from a downloaded dictionary with no
/// network call at all. A hit with a non-null `redirectTo` is terminal (see `SKSkarnikError.redirect`),
/// not a miss — it is not resolved locally and must not fall through to the next source.
struct SKLocalTranslationSource: SKTranslationSource {
    private let store: SKOfflineDictionaryStore

    init(store: SKOfflineDictionaryStore = .shared) {
        self.store = store
    }

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        guard let downloaded = store.word(langId: word.lang_id.rawValue, externalId: word.word_id) else {
            return nil
        }

        if let redirectTo = downloaded.redirectTo {
            throw SKSkarnikError.redirect(word: word, redirectTo: redirectTo)
        }

        let displayUrl = SKHtmlTranslationSource.url(vocabularyType: word.lang_id, wordId: word.word_id) ?? ""
        return SKSkarnikTranslation(word: word, url: displayUrl, html: downloaded.translation, stress: downloaded.stress, sourceName: "local")
    }
}

extension SKFallbackTranslationSource {
    /// Same cascade as `shared` (Supabase → API → HTML), with a local-cache tier prepended. Used by
    /// the main app's word-details flow so downloaded dictionaries are preferred over any network
    /// call; left separate from `shared` since that default is also used by the WordWidget
    /// extension, which has no App Group access to this app's local offline-dictionary store.
    static let sharedWithLocalCache = SKFallbackTranslationSource(sources: [
        SKLocalTranslationSource(),
        SKSupabaseTranslationSource(),
        SKApiTranslationSource(),
        SKHtmlTranslationSource()
    ])
}
