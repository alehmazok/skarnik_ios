//
//  SKFavoritesController.swift
//  Skarnik
//

import Foundation

struct SKFavoriteWord: Codable, Equatable {
    let word: SKWord
    let dateAdded: Date
}

class SKFavoritesController {
    static let shared = SKFavoritesController()
    private(set) var favorites: [SKFavoriteWord] = []
    private static let favoritesKey = "favoriteWordsKey"

    private init() {
        self.favorites = self.loadFavorites()
    }

    private func loadFavorites() -> [SKFavoriteWord] {
        var favorites: [SKFavoriteWord]?
        if let jsonData = UserDefaults.standard.object(forKey: SKFavoritesController.favoritesKey) as? Data {
            favorites = try? JSONDecoder().decode([SKFavoriteWord].self, from: jsonData)
        }
        return favorites ?? []
    }

    private func saveFavorites() {
        if let jsonData = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(jsonData, forKey: SKFavoritesController.favoritesKey)
            UserDefaults.standard.synchronize()
        }
    }

    private func matches(_ favorite: SKFavoriteWord, _ word: SKWord) -> Bool {
        favorite.word.word_id == word.word_id && favorite.word.lang_id == word.lang_id
    }

    func isFavorite(_ word: SKWord) -> Bool {
        favorites.contains { matches($0, word) }
    }

    @discardableResult
    func toggleFavorite(_ word: SKWord) -> Bool {
        if let index = favorites.firstIndex(where: { matches($0, word) }) {
            favorites.remove(at: index)
            saveFavorites()
            return false
        }
        favorites.append(SKFavoriteWord(word: word, dateAdded: Date()))
        saveFavorites()
        return true
    }

    func removeFavorite(_ favorite: SKFavoriteWord) {
        favorites.removeAll { matches(favorite, $0.word) }
        saveFavorites()
    }
}
