
import XCTest
import Combine
import SwiftUI
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
        XCTAssertEqual(sut.viewModel.navigationTitle, "«тэст»")
    }

    @MainActor
    func testNavigationTitle_UpdatesImmediatelyOnWordChange() {
        let word1 = SKWord(word_id: 1, word: "першы", lang_id: .bel_rus)
        let word2 = SKWord(word_id: 2, word: "другі", lang_id: .bel_rus)

        sut.word = word1
        sut.word = word2

        XCTAssertEqual(sut.viewModel.navigationTitle, "«другі»")
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

    // MARK: - stressWordPicker

    // Homonyms (e.g. "пара") open a resizable sheet listing every candidate,
    // not an action sheet and not a silent pick of the first one.
    @MainActor
    func testStressWordPicker_isResizableSheetWithAllCandidates() {
        let candidates = [
            SKStressWordEntry(id: 52855, lemma: "пара", word: "па́ра", tableName: "Nouns", source: .api, meaning: "два аднолькавыя прадметы"),
            SKStressWordEntry(id: 52857, lemma: "пара", word: "пара́", tableName: "Nouns", source: .api)
        ]

        let picker = sut.stressWordPicker(for: candidates)

        let hosting = picker as? UIHostingController<SKStressWordPickerView>
        XCTAssertNotNil(hosting)
        XCTAssertEqual(hosting?.rootView.entries, candidates)
        XCTAssertEqual(picker.sheetPresentationController?.detents, [.medium(), .large()])
        XCTAssertEqual(picker.sheetPresentationController?.prefersGrabberVisible, true)
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
