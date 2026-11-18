//
//  SKWordDetailsViewModel.swift
//  Skarnik
//
//  Created by Gemini on 8.03.26.
//

import Foundation
import UIKit
import Combine

enum SKWordDetailsState {
    case idle
    case loading
    case success(SKSkarnikTranslation)
    case error(String)
}

enum SKWordDetailsEffect {
    case redirection(String)
}

@MainActor
class SKWordDetailsViewModel: ObservableObject {
    @Published private(set) var state: SKWordDetailsState = .idle
    @Published var word: SKWord?
    @Published private(set) var isFavorite: Bool = false
    /// The same word in the other dictionary (Бел-Рус ⇄ ТСБМ), or nil. Found in the bundled index
    /// as soon as the word is set, so the header button doesn't jump in when the translation arrives.
    @Published private(set) var dictionaryLink: SKDictionaryLink?

    var entryPoint: String = ""

    private var fetchTask: Task<Void, Never>?
    let effectSubject = PassthroughSubject<SKWordDetailsEffect, Never>()
    private let translationSource: any SKTranslationSource
    private var favoritesObserver: AnyCancellable?
    private let dictionaryLinkPlacement: () -> SKDictionaryLinkPlacement
    private let onAddedToFavorites: (SKWord) -> Void

    init(translationSource: any SKTranslationSource = SKFallbackTranslationSource.shared,
         dictionaryLinkPlacement: @escaping () -> SKDictionaryLinkPlacement = { SKRemoteConfig.shared.dictionaryLinkPlacement },
         onAddedToFavorites: @escaping (SKWord) -> Void = { SKAnalyticsManager.logAddToFavorites(word: $0) }) {
        self.translationSource = translationSource
        self.dictionaryLinkPlacement = dictionaryLinkPlacement
        self.onAddedToFavorites = onAddedToFavorites
        // On iPad the word stays open beside Закладкі, where a swipe can remove its bookmark.
        favoritesObserver = NotificationCenter.default.publisher(for: .skFavoritesChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshFavorite() }
            }
    }

    private func refreshFavorite() {
        isFavorite = word.map { SKFavoritesController.shared.isFavorite($0) } ?? false
    }
    
    var translation: SKSkarnikTranslation? {
        if case .success(let translation) = state {
            return translation
        }
        return nil
    }
    
    var spellingWords: [String] {
        return translation?.belWords ?? []
    }
    
    /// The word the screen is about: the stressed form once the translation brings one,
    /// otherwise the plain word. Shown as the large heading above the translation.
    var headword: String? {
        guard let word = word else { return nil }
        if let stress = translation?.stress, !stress.isEmpty {
            return stress
        }
        return word.word
    }

    /// Compact title for the navigation bar, shown once the large heading scrolls out of view.
    var navigationTitle: String? {
        headword.map { "«\($0)»" }
    }
    
    var vocabularySubtitle: String? {
        return word?.lang_id.wordDetailsSubtitle?.uppercased()
    }
    
    /// Bounds how many redirects `updateWord` will chase in a row — guards against a circular
    /// `redirect_to` chain (e.g. A → B → A) looping forever instead of settling on an error.
    private static let maxRedirectDepth = 5

    func updateWord(_ word: SKWord?) {
        updateWord(word, redirectDepth: 0)
    }

    private func updateWord(_ word: SKWord?, redirectDepth: Int) {
        // Cancel any ongoing fetch task for a previous word
        fetchTask?.cancel()
        
        guard let word = word else {
            self.word = nil
            self.isFavorite = false
            self.dictionaryLink = nil
            self.state = .idle
            return
        }
        
        // Avoid redundant updates if it's the same word and already loaded
        if self.word?.word_id == word.word_id && self.word?.lang_id == word.lang_id {
            if case .success = state { return }
            if case .loading = state { return }
        }

        self.word = word
        self.isFavorite = SKFavoritesController.shared.isFavorite(word)
        self.dictionaryLink = SKDictionaryLink.find(for: word, placement: dictionaryLinkPlacement())
        self.state = .loading
        
        fetchTask = Task {
            do {
                guard let translation = try await translationSource.wordTranslation(word) else {
                    if !Task.isCancelled {
                        self.state = .error(SKLocalization.errorWordNotFound)
                    }
                    return
                }
                
                // Check cancellation again after the async call
                guard !Task.isCancelled else { return }
                
                SKAnalyticsManager.logTranslation(
                    uri: translation.url,
                    word: translation.word.word,
                    word_id: word.word_id,
                    lang_id: word.lang_id.rawValue,
                    dict_name: word.lang_id.analyticsName ?? "unknown",
                    dict_path: word.lang_id.skarnikId ?? "unknown",
                    source_name: translation.sourceName,
                    entry_point: self.entryPoint
                )
                
                self.state = .success(translation)
                SKAppstoreReviewController.requestReview()
            } catch is CancellationError {
                // Task was cancelled, do nothing
            } catch SKSkarnikError.redirect(let fromWord, let redirectPath) {
                guard !Task.isCancelled else { return }
                guard redirectDepth < Self.maxRedirectDepth,
                      let redirectId = redirectPath.trailingWordId,
                      let nextWord = SKVocabularyIndex.shared.word(id: redirectId, vocabularyType: fromWord.lang_id) else {
                    self.state = .error(SKLocalization.errorWordNotFound)
                    return
                }
                self.effectSubject.send(.redirection(fromWord.word))
                self.updateWord(nextWord, redirectDepth: redirectDepth + 1)
            } catch SKSkarnikError.networkError {
                if !Task.isCancelled {
                    self.state = .error(SKLocalization.errorNetworkErrorTryAgainLater)
                }
            } catch {
                if !Task.isCancelled {
                    SKErrorReporting.logError(error, tag: "WordDetails")
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    /// Loads the current word again after an error («Паспрабаваць яшчэ»). Does nothing in any
    /// other state, so a double tap can't restart a load that is already running.
    func retry() {
        guard case .error = state, let word else { return }
        updateWord(word)
    }

    func toggleFavorite() {
        guard let word else { return }
        isFavorite = SKFavoritesController.shared.toggleFavorite(word)
        // Only adding is logged (`add_to_favorites`), as on Android.
        if isFavorite { onAddedToFavorites(word) }
    }

    func handleUrl(_ urlString: String) {
        if let newWord = Self.word(forUrl: urlString) {
            self.updateWord(newWord)
        }
    }

    /// A Belarusian word of the translation (`text` as shown) was tapped: log it and open its entry.
    func openWordLink(_ url: URL, text: String) {
        if let from = word, let target = Self.word(forUrl: url.absoluteString) {
            SKAnalyticsManager.logTranslationWordClicked(from: from, word: text, target: target)
        }
        handleUrl(url.absoluteString)
    }

    /// The link to the same word in the other dictionary was tapped: log it and open that entry in
    /// place, as links in translations do.
    func openDictionaryLink() {
        guard let from = word, let link = dictionaryLink else { return }
        SKAnalyticsManager.logDictionaryLinkClicked(from: from, target: link.target, placement: link.placement)
        updateWord(link.target)
    }

    /// The word a `/belrus/123`-style link points at: relative, absolute on any host (links in the
    /// legacy translation HTML) or `SKSkarnikTranslation.url(of:)` (`https://skarnik.app/r/belrus/123`).
    static func word(forUrl urlString: String) -> SKWord? {
        let regexPattern = #"/(?<vocabularyPath>belrus|rusbel|tsbm)/(?<wordId>[0-9]+)"#

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []),
              let match = regex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.utf16.count)) else {
            return nil
        }

        guard let vocabularyPath = extractNamedGroup(from: match, named: "vocabularyPath", in: urlString),
              let wordIdString = extractNamedGroup(from: match, named: "wordId", in: urlString),
              let wordId = Int64(wordIdString),
              let vocabularyType = ESKVocabularyType.from(vocabularyPath: vocabularyPath) else {
            return nil
        }
        return SKVocabularyIndex.shared.word(id: wordId, vocabularyType: vocabularyType)
    }

    private static func extractNamedGroup(from match: NSTextCheckingResult, named groupName: String, in text: String) -> String? {
        let groupRange = match.range(withName: groupName)
        if groupRange.location != NSNotFound, let range = Range(groupRange, in: text) {
            return String(text[range])
        }
        return nil
    }
}
