import XCTest
@testable import Skarnik

final class SKFavoritesViewModelTests: XCTestCase {

    private var addedWords: [SKWord] = []

    override func tearDown() {
        for word in addedWords {
            SKFavoritesController.shared.removeFavorite(SKFavoriteWord(word: word, dateAdded: Date()))
        }
        addedWords = []
        super.tearDown()
    }

    private func addFavorite(word: String, wordId: Int64) {
        let skWord = SKWord(word_id: wordId, word: word, lang_id: .bel_rus)
        addedWords.append(skWord)
        SKFavoritesController.shared.toggleFavorite(skWord)
    }

    @MainActor
    func testSortByAlphabet_ordersWordsAscending() {
        addFavorite(word: "вожык", wordId: 888_001)
        addFavorite(word: "абрыкос", wordId: 888_002)
        addFavorite(word: "жаба", wordId: 888_003)

        let vm = SKFavoritesViewModel()
        vm.sortMode = .alphabet
        vm.reload()

        let words = vm.favorites.map(\.word.word)
        XCTAssertEqual(words, ["абрыкос", "вожык", "жаба"])
    }

    @MainActor
    func testSortByDate_newestFirst() {
        let skWord1 = SKWord(word_id: 888_004, word: "першы", lang_id: .bel_rus)
        addedWords.append(skWord1)
        SKFavoritesController.shared.toggleFavorite(skWord1)

        let skWord2 = SKWord(word_id: 888_005, word: "другі", lang_id: .bel_rus)
        addedWords.append(skWord2)
        SKFavoritesController.shared.toggleFavorite(skWord2)

        let vm = SKFavoritesViewModel()
        vm.sortMode = .date
        vm.reload()

        let words = vm.favorites.map(\.word.word)
        XCTAssertEqual(words, ["другі", "першы"])
    }

    @MainActor
    func testDeleteFavorite_removesFromControllerAndReloads() {
        addFavorite(word: "выдаліць", wordId: 888_006)

        let vm = SKFavoritesViewModel()
        vm.reload()
        XCTAssertEqual(vm.favorites.count, 1)

        vm.deleteFavorite(at: IndexSet(integer: 0))

        XCTAssertEqual(vm.favorites.count, 0)
        XCTAssertFalse(SKFavoritesController.shared.isFavorite(SKWord(word_id: 888_006, word: "выдаліць", lang_id: .bel_rus)))
    }
}
