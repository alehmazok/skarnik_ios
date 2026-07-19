
import XCTest
import Combine
@testable import Skarnik

final class SKWordDetailsViewControllerTests: XCTestCase {

    private var sut: SKWordDetailsViewController!
    private var storyboard: UIStoryboard!

    @MainActor
    override func setUp() {
        super.setUp()
        storyboard = UIStoryboard(name: "Main", bundle: nil)
        sut = storyboard.instantiateViewController(withIdentifier: "SKWordDetailsViewController") as? SKWordDetailsViewController
        sut.loadViewIfNeeded()
    }

    @MainActor
    override func tearDown() {
        sut = nil
        storyboard = nil
        super.tearDown()
    }

    @MainActor
    func testInitialState_IsIdle() {
        XCTAssertNil(sut.word)
        guard case .idle = sut.viewModel.state else {
            XCTFail("Expected idle state on init")
            return
        }
    }

    @MainActor
    func testLoadingState_AfterWordSet() {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        sut.word = word

        guard case .loading = sut.viewModel.state else {
            XCTFail("Expected loading state after setting word")
            return
        }
    }

    // Regression test: navigation title must reflect the word passed to the $word publisher,
    // not viewModel.word read back inside the sink (which would still be the old value due
    // to @Published using willSet semantics).
    @MainActor
    func testNavigationTitle_ShowsOnFirstWord() {
        let word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        sut.word = word
        XCTAssertEqual(sut.viewModel.navigationTitle, "«\u{200E}тэст»")
    }

    @MainActor
    func testNavigationTitle_UpdatesImmediatelyOnWordChange() {
        let word1 = SKWord(word_id: 1, word: "першы", lang_id: .bel_rus)
        let word2 = SKWord(word_id: 2, word: "другі", lang_id: .bel_rus)

        sut.word = word1
        sut.word = word2

        XCTAssertEqual(sut.viewModel.navigationTitle, "«\u{200E}другі»")
    }

    @MainActor
    func testNilWord_ResetsState() {
        sut.word = SKWord(word_id: 1, word: "тэст", lang_id: .bel_rus)
        sut.word = nil

        XCTAssertNil(sut.viewModel.navigationTitle)
        guard case .idle = sut.viewModel.state else {
            XCTFail("Expected idle state after setting nil word")
            return
        }
    }

    // MARK: - spellingWordPickerAlert

    // Regression: resolving a tapped word to a starnik.by entry can surface several
    // homonyms (e.g. "а" as noun/conjunction/preposition/...); the picker must offer one
    // action per candidate plus a cancel action, not silently pick the first.
    @MainActor
    func testSpellingWordPickerAlert_oneActionPerCandidatePlusCancel() {
        let candidates = [
            SKStressWordEntry(id: 1, lemma: "а", word: "а", tableName: "Nouns", source: .api),
            SKStressWordEntry(id: 234065, lemma: "а", word: "а", tableName: "Conjunctions", source: .api)
        ]

        let alert = sut.spellingWordPickerAlert(for: candidates)

        XCTAssertEqual(alert.title, SKLocalization.wordDetailsSpellingTitle)
        XCTAssertEqual(alert.message, SKLocalization.wordDetailsSpellingMessage)
        XCTAssertEqual(alert.actions.count, 3)
        XCTAssertEqual(alert.actions[0].title, "а — назоўнік")
        XCTAssertEqual(alert.actions[1].title, "а — злучнік")
        XCTAssertEqual(alert.actions[2].title, SKLocalization.wordDetailsSpellingCancel)
        XCTAssertEqual(alert.actions[2].style, .cancel)
    }

    @MainActor
    func testSpellingWordPickerAlert_fallsBackToRawTableNameWhenUnmapped() {
        let candidate = SKStressWordEntry(id: 1, lemma: "тэст", word: "тэст", tableName: "Gerunds", source: .api)

        let alert = sut.spellingWordPickerAlert(for: [candidate])

        XCTAssertEqual(alert.actions.first?.title, "тэст — Gerunds")
    }

    @MainActor
    func testSpellingWordPickerAlert_omitsPosSeparatorWhenTypeMissing() {
        let candidate = SKStressWordEntry(id: 1, lemma: "тэст", word: "тэст", tableName: nil, source: .api)

        let alert = sut.spellingWordPickerAlert(for: [candidate])

        XCTAssertEqual(alert.actions.first?.title, "тэст")
    }

    // MARK: - stressMessageAlert

    @MainActor
    func testStressMessageAlert_notFound_showsSpecCopyWithSingleDoneAction() {
        let alert = sut.stressMessageAlert(SKLocalization.wordStressNotFound)

        XCTAssertNil(alert.title)
        XCTAssertEqual(alert.message, SKLocalization.wordStressNotFound)
        XCTAssertEqual(alert.actions.count, 1)
        XCTAssertEqual(alert.actions[0].title, SKLocalization.aboutDone)
        XCTAssertEqual(alert.actions[0].style, .default)
    }

    @MainActor
    func testStressMessageAlert_error_showsSpecCopy() {
        let alert = sut.stressMessageAlert(SKLocalization.wordStressError)

        XCTAssertEqual(alert.message, SKLocalization.wordStressError)
        XCTAssertEqual(alert.actions.count, 1)
    }
}
