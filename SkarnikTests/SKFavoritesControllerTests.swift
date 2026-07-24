import XCTest
@testable import Skarnik

final class SKFavoritesControllerTests: XCTestCase {

    private func cleanUp(_ word: SKWord) {
        SKFavoritesController.shared.removeFavorite(SKFavoriteWord(word: word, dateAdded: Date()))
    }

    func testToggleFavorite_addsWord() {
        let word = SKWord(word_id: 777_001, word: "закладка", lang_id: .bel_rus)
        defer { cleanUp(word) }

        XCTAssertFalse(SKFavoritesController.shared.isFavorite(word))
        SKFavoritesController.shared.toggleFavorite(word)
        XCTAssertTrue(SKFavoritesController.shared.isFavorite(word))
    }

    func testToggleFavorite_removesAlreadyFavoritedWord() {
        let word = SKWord(word_id: 777_002, word: "закладка2", lang_id: .bel_rus)
        defer { cleanUp(word) }

        SKFavoritesController.shared.toggleFavorite(word)
        XCTAssertTrue(SKFavoritesController.shared.isFavorite(word))

        SKFavoritesController.shared.toggleFavorite(word)
        XCTAssertFalse(SKFavoritesController.shared.isFavorite(word))
    }

    func testToggleFavorite_returnsNewFavoriteState() {
        let word = SKWord(word_id: 777_003, word: "закладка3", lang_id: .bel_rus)
        defer { cleanUp(word) }

        XCTAssertTrue(SKFavoritesController.shared.toggleFavorite(word))
        XCTAssertFalse(SKFavoritesController.shared.toggleFavorite(word))
    }

    func testIsFavorite_distinguishesByLangId() {
        let belRusWord = SKWord(word_id: 777_004, word: "аднолькавы", lang_id: .bel_rus)
        let rusBelWord = SKWord(word_id: 777_004, word: "аднолькавы", lang_id: .rus_bel)
        defer { cleanUp(belRusWord); cleanUp(rusBelWord) }

        SKFavoritesController.shared.toggleFavorite(belRusWord)

        XCTAssertTrue(SKFavoritesController.shared.isFavorite(belRusWord))
        XCTAssertFalse(SKFavoritesController.shared.isFavorite(rusBelWord))
    }

    func testPersistence_survivesReload() {
        let word = SKWord(word_id: 777_005, word: "устойлівы", lang_id: .bel_rus)
        defer { cleanUp(word) }

        SKFavoritesController.shared.toggleFavorite(word)

        let jsonData = UserDefaults.standard.object(forKey: "favoriteWordsKey") as? Data
        XCTAssertNotNil(jsonData)
        let decoded = try? JSONDecoder().decode([SKFavoriteWord].self, from: jsonData!)
        XCTAssertEqual(decoded?.contains { $0.word.word_id == word.word_id && $0.word.lang_id == word.lang_id }, true)
    }
}
