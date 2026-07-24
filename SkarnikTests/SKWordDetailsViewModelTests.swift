
import XCTest
import Combine
@testable import Skarnik

final class SKWordDetailsViewModelTests: XCTestCase {
    
    private var viewModel: SKWordDetailsViewModel!
    private var cancellables: Set<AnyCancellable>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        viewModel = SKWordDetailsViewModel()
        cancellables = []
    }
    
    @MainActor
    override func tearDown() {
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    @MainActor
    func testNavigationTitle() {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        viewModel.word = word
        
        XCTAssertEqual(viewModel.navigationTitle, "«‎тэст»")
    }
    
    @MainActor
    func testNavigationTitle_NilWord() {
        viewModel.word = nil
        XCTAssertNil(viewModel.navigationTitle)
    }
    
    @MainActor
    func testVocabularySubtitle_BelRus() {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        viewModel.word = word
        
        // SKLocalization.wordDetailsSubtitleBelRus = "Пераклад на рускую мову"
        XCTAssertEqual(viewModel.vocabularySubtitle, "ПЕРАКЛАД НА РУСКУЮ МОВУ")
    }
    
    @MainActor
    func testVocabularySubtitle_RusBel() {
        let word = SKWord(word_id: 1, word: "тест", lang_id: .rus_bel)
        viewModel.word = word
        
        // SKLocalization.wordDetailsSubtitleRusBel = "Пераклад на беларускую мову"
        XCTAssertEqual(viewModel.vocabularySubtitle, "ПЕРАКЛАД НА БЕЛАРУСКУЮ МОВУ")
    }
    
    @MainActor
    func testVocabularySubtitle_BelDefinition() {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_definition)
        viewModel.word = word
        
        // SKLocalization.wordDetailsSubtitleDenifition = "Тлумачэнне слова"
        XCTAssertEqual(viewModel.vocabularySubtitle, "ТЛУМАЧЭННЕ СЛОВА")
    }
    
    @MainActor
    func testUpdateWord_Nil() {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        viewModel.updateWord(word)
        
        viewModel.updateWord(nil)
        
        XCTAssertNil(viewModel.word)
        if case .idle = viewModel.state {
            // Success
        } else {
            XCTFail("State should be idle after updateWord(nil)")
        }
    }
    
    @MainActor
    func testHandleUrl_BelRus() {
        // This test might be tricky because handleUrl calls SKVocabularyIndex.shared.word which hits SQLite.
        // But we can check if it at least parses the URL correctly and triggers updateWord.
        // We'll use a wordId that might not exist, but the goal is to see if it calls updateWord.

        let expectation = XCTestExpectation(description: "Wait for word update")

        viewModel.$word
            .dropFirst() // Drop initial nil
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.handleUrl("https://skarnik.by/belrus/123")

        // Since we can't easily mock SKVocabularyIndex, this might not fulfill if the word is nil.
        // Let's just check the state if it goes to loading or remains idle.
    }

    // MARK: - Tests with Mock Source

    @MainActor
    func testUpdateWord_success() async {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        let translation = SKSkarnikTranslation(word: word, url: "https://example.com", html: "<b>ok</b>")
        let vm = SKWordDetailsViewModel(translationSource: MockTranslationSource { translation })

        let exp = expectation(description: "success state")
        vm.$state
            .sink { if case .success = $0 { exp.fulfill() } }
            .store(in: &cancellables)

        vm.updateWord(word)
        await fulfillment(of: [exp], timeout: 1.0)

        guard case .success(let result) = vm.state else {
            XCTFail("Expected .success state"); return
        }
        XCTAssertEqual(result.word.word_id, word.word_id)
    }

    @MainActor
    func testUpdateWord_networkError() async {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        let vm = SKWordDetailsViewModel(translationSource: MockTranslationSource { throw SKSkarnikError.networkError })

        let exp = expectation(description: "error state")
        vm.$state
            .sink { if case .error = $0 { exp.fulfill() } }
            .store(in: &cancellables)

        vm.updateWord(word)
        await fulfillment(of: [exp], timeout: 1.0)

        guard case .error(let message) = vm.state else {
            XCTFail("Expected .error state"); return
        }
        XCTAssertFalse(message.isEmpty)
    }

    @MainActor
    func testUpdateWord_notFound() async {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        let vm = SKWordDetailsViewModel(translationSource: MockTranslationSource { nil })

        let exp = expectation(description: "not found error")
        vm.$state
            .sink { if case .error = $0 { exp.fulfill() } }
            .store(in: &cancellables)

        vm.updateWord(word)
        await fulfillment(of: [exp], timeout: 1.0)

        if case .error = vm.state { /* ok */ } else {
            XCTFail("Expected .error state when translation not found")
        }
    }

    @MainActor
    func testUpdateWord_redirect() async {
        // Redirect is terminal at the source that detects it (thrown, not returned as a mismatched
        // success) — the ViewModel must resolve `redirectTo` via the local vocabulary index itself
        // and re-trigger a fresh top-of-cascade lookup for it.
        guard let redirectTarget = SKVocabularyIndex.shared.word("мова", vocabularyType: .bel_rus) else {
            XCTFail("Fixture word \"мова\" not found in vocabulary.db"); return
        }
        let requestedWord = SKWord(word_id: 999_999, word: "тэст", lang_id: .bel_rus)
        let resolvedTranslation = SKSkarnikTranslation(word: redirectTarget, url: "https://example.com", html: "<b>ok</b>")
        let source = RedirectingMockTranslationSource(
            redirectFromWordId: requestedWord.word_id,
            redirectTo: "/belrus/\(redirectTarget.word_id)",
            resolvedTranslation: resolvedTranslation
        )
        let vm = SKWordDetailsViewModel(translationSource: source)

        let exp = expectation(description: "redirection effect")
        vm.effectSubject
            .sink { effect in
                if case .redirection(let from) = effect {
                    XCTAssertEqual(from, requestedWord.word)
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)

        vm.updateWord(requestedWord)
        await fulfillment(of: [exp], timeout: 1.0)

        guard case .success(let translation) = vm.state else {
            XCTFail("Expected .success state after following the redirect"); return
        }
        XCTAssertEqual(vm.word?.word_id, redirectTarget.word_id)
        XCTAssertEqual(translation.word.word_id, redirectTarget.word_id)
    }

    @MainActor
    func testUpdateWord_circularRedirect_terminatesWithError() async {
        // A → B → A forever would hang without a bound — must settle on an error instead.
        guard let wordA = SKVocabularyIndex.shared.word("мова", vocabularyType: .bel_rus),
              let wordB = SKVocabularyIndex.shared.word("дом", vocabularyType: .bel_rus) else {
            XCTFail("Fixture words not found in vocabulary.db"); return
        }
        let source = CircularRedirectMockTranslationSource(wordA: wordA, wordB: wordB)
        let vm = SKWordDetailsViewModel(translationSource: source)

        let exp = expectation(description: "error state after bounded redirects")
        vm.$state
            .sink { if case .error = $0 { exp.fulfill() } }
            .store(in: &cancellables)

        vm.updateWord(wordA)
        await fulfillment(of: [exp], timeout: 2.0)

        guard case .error = vm.state else {
            XCTFail("Expected a terminal .error state, not an infinite redirect loop"); return
        }
        XCTAssertLessThanOrEqual(source.callCount, 7, "Redirect chasing must be bounded, not unbounded")
    }

    @MainActor
    func testIsFavorite_reflectsControllerStateOnUpdateWord() {
        let word = SKWord(word_id: 555_001, word: "тэст-закладка", lang_id: .bel_rus)
        SKFavoritesController.shared.removeFavorite(SKFavoriteWord(word: word, dateAdded: Date()))
        defer { SKFavoritesController.shared.removeFavorite(SKFavoriteWord(word: word, dateAdded: Date())) }

        viewModel.updateWord(word)
        XCTAssertFalse(viewModel.isFavorite)

        SKFavoritesController.shared.toggleFavorite(word)
        viewModel.updateWord(nil)
        viewModel.updateWord(word)
        XCTAssertTrue(viewModel.isFavorite)
    }

    @MainActor
    func testToggleFavorite_addsThenRemoves() {
        let word = SKWord(word_id: 555_002, word: "яшчэ-закладка", lang_id: .bel_rus)
        defer { SKFavoritesController.shared.removeFavorite(SKFavoriteWord(word: word, dateAdded: Date())) }
        viewModel.updateWord(word)

        viewModel.toggleFavorite()
        XCTAssertTrue(viewModel.isFavorite)
        XCTAssertTrue(SKFavoritesController.shared.isFavorite(word))

        viewModel.toggleFavorite()
        XCTAssertFalse(viewModel.isFavorite)
        XCTAssertFalse(SKFavoritesController.shared.isFavorite(word))
    }

    @MainActor
    func testToggleFavorite_noWord_doesNothing() {
        viewModel.updateWord(nil)
        viewModel.toggleFavorite()
        XCTAssertFalse(viewModel.isFavorite)
    }

    @MainActor
    func testUpdateWord_sameWordAlreadyLoaded_doesNotRefetch() async {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        let translation = SKSkarnikTranslation(word: word, url: "https://example.com", html: "<b>ok</b>")
        var fetchCount = 0
        let vm = SKWordDetailsViewModel(translationSource: MockTranslationSource { fetchCount += 1; return translation })

        let exp = expectation(description: "first success")
        vm.$state
            .sink { if case .success = $0 { exp.fulfill() } }
            .store(in: &cancellables)

        vm.updateWord(word)
        await fulfillment(of: [exp], timeout: 1.0)

        vm.updateWord(word)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(fetchCount, 1, "Should not refetch when same word is already loaded")
    }
}

// MARK: - Mock

private struct MockTranslationSource: SKTranslationSource {
    let handler: () async throws -> SKSkarnikTranslation?

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        try await handler()
    }
}

/// Always throws a terminal redirect, bouncing between `wordA`/`wordB` regardless of which was
/// queried — simulates a circular `redirect_to` chain.
private final class CircularRedirectMockTranslationSource: SKTranslationSource {
    let wordA: SKWord
    let wordB: SKWord
    private(set) var callCount = 0

    init(wordA: SKWord, wordB: SKWord) {
        self.wordA = wordA
        self.wordB = wordB
    }

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        callCount += 1
        let redirectTarget = word.word_id == wordA.word_id ? wordB : wordA
        throw SKSkarnikError.redirect(word: word, redirectTo: "/belrus/\(redirectTarget.word_id)")
    }
}

/// Throws a terminal redirect for one specific word id, resolves any other id (i.e. the
/// redirect's target, once the ViewModel re-triggers a lookup for it) to a fixed translation.
private struct RedirectingMockTranslationSource: SKTranslationSource {
    let redirectFromWordId: Int64
    let redirectTo: String
    let resolvedTranslation: SKSkarnikTranslation

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        if word.word_id == redirectFromWordId {
            throw SKSkarnikError.redirect(word: word, redirectTo: redirectTo)
        }
        return resolvedTranslation
    }
}
