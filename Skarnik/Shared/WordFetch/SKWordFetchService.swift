//
//  SKWordFetchService.swift
//  WordWidgetExtension
//
//  Created by Logout on 24.10.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import Foundation

class SKWordFetchService: Any {

    private var storage = SKWordFetchStorage()
    private let translationSource: any SKTranslationSource

    init(translationSource: any SKTranslationSource = SKFallbackTranslationSource.shared) {
        self.translationSource = translationSource
    }
    
    public func fetchRandomWord(_ vocabulary: ESKVocabularyType, maxTries: Int = 30) async -> SKWordFetchEntry? {
        var loop = 0
        while true {
            loop += 1
            guard let word = self.randomWord(vocabulary) else {
                return nil
            }
            if self.storage.hasWord(vocabularyType: word.lang_id, wordId: word.word_id) && loop < maxTries {
                continue
            }

            guard let newWordEntry = await self.fetchWord(word) else {
                return nil
            }

            self.storage.addWord(newWordEntry)
            
            if newWordEntry.isSimilar && loop < maxTries {
                continue
            }
            
            return newWordEntry
        }
    }
    
    public func fetchWord(_ word: SKWord) async -> SKWordFetchEntry? {
        guard let wordTranslation = try? await translationSource.wordTranslation(word)?.attributedString?.string else {
            return nil
        }
        let newWordEntry = SKWordFetchEntry(word: word, translation: wordTranslation, createdAt: Date())
        
        return newWordEntry
    }
    
    /// A few attempts, then give up: an unbounded loop here spun forever when the database
    /// returned no row, and the widget never got a timeline.
    private func randomWord(_ vocabularyType: ESKVocabularyType, maxAttempts: Int = 3) -> SKWord? {
        for _ in 0..<maxAttempts {
            if let word = SKVocabularyIndex.shared.randomWord(vocabularyType: vocabularyType) {
                return word
            }
        }
        return nil
    }
}
