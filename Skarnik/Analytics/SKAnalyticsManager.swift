import Foundation

class SKAnalyticsManager {
    static let shared = SKAnalyticsManager()

    private let service: SKAnalyticsService

    private init() {
        #if DEBUG
            self.service = SKDebugAnalytics()
        #else
            self.service = SKFirebaseAnalytics()
        #endif
    }
    
    static func logTranslation(
        uri: String, word: String, word_id: Int64, lang_id: Int, dict_name: String, dict_path: String, source_name: String, entry_point: String
    ) {
        shared.service.logTranslation(
            uri: uri, word: word, word_id: word_id, lang_id: lang_id, dict_name: dict_name, dict_path: dict_path, source_name: source_name, entry_point: entry_point
        )
    }

    static func logAppOpen() {
        shared.service.logAppOpen()
    }
    
    static func logStressClicked(word: String) {
        shared.service.logStressClicked(word: word)
    }

    static func logStarnikByOpened() {
        shared.service.logStarnikByOpened()
    }

    static func logDrukarnikOpened() {
        shared.service.logDrukarnikOpened()
    }

    static func logWidgetDeepLink(word: SKWord, appState: SKWidgetDeepLinkAppState) {
        shared.service.logWidgetDeepLink(word: word, appState: appState)
    }

    static func logShareClicked(word: SKWord, url: String) {
        shared.service.logShareClicked(word: word, url: url)
    }

    static func logOfflineDictionaryDownloadClick(dictName: String, dictPath: String) {
        shared.service.logOfflineDictionaryDownloadClick(dictName: dictName, dictPath: dictPath)
    }

    static func logVocabularyWordClicked(word: SKWord) {
        shared.service.logVocabularyWordClicked(word: word)
    }

    /// `usedPrepositionFallback`: the results came from the retry without a glued one-letter
    /// preposition (`SKVocabularyIndex.search`). Sent as 0/1, as on Android.
    static func logSearchPerformed(query: String, resultCount: Int, usedPrepositionFallback: Bool) {
        shared.service.logSearchPerformed(query: query, resultCount: resultCount, usedPrepositionFallback: usedPrepositionFallback)
    }

    static func logSearchNoResults(query: String, usedPrepositionFallback: Bool) {
        shared.service.logSearchNoResults(query: query, usedPrepositionFallback: usedPrepositionFallback)
    }

    static func logSearchResultTapped(word: SKWord, position: Int, query: String) {
        shared.service.logSearchResultTapped(word: word, position: position, query: query)
    }

    static func logTranslationWordClicked(from: SKWord, word: String, target: SKWord) {
        shared.service.logTranslationWordClicked(from: from, word: word, target: target)
    }

    /// The goal event of the `dictionary_link_placement` experiment.
    static func logDictionaryLinkClicked(from: SKWord, target: SKWord, placement: SKDictionaryLinkPlacement) {
        shared.service.logDictionaryLinkClicked(from: from, target: target, placement: placement.rawValue)
    }

    /// A word was bookmarked. Removing a bookmark is not logged, as on Android and in the Flutter app.
    static func logAddToFavorites(word: SKWord) {
        shared.service.logAddToFavorites(word: word)
    }

    /// Sets the `install_source` user property. Fire-and-forget: the lookup runs off the main thread
    /// and never blocks launch. Call at launch (after `applyStoredConsent`) and when consent is granted;
    /// does nothing while analytics consent is not granted.
    static func reportInstallSource(consent: SKAnalyticsConsentController = .shared) {
        guard consent.isCollectionEnabled else { return }
        Task.detached(priority: .utility) {
            let source = await SKInstallSourceDetector.detect()
            shared.service.setInstallSource(source)
        }
    }

    /// Sets the `search_bar_position` user property (`bottom` / `top`) on iOS 26, where the user
    /// can choose. Call at launch, when consent is granted and when the setting changes; does nothing
    /// while analytics consent is not granted.
    static func reportSearchBarPlacement(consent: SKAnalyticsConsentController = .shared) {
        guard consent.isCollectionEnabled, SKSearchBarPlacement.isBottomAvailable else { return }
        shared.service.setSearchBarPlacement(SKSearchBarPlacement.current())
    }
}
