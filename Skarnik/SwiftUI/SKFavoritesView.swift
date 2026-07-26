//
//  SKFavoritesView.swift
//  Skarnik
//

import SwiftUI

// MARK: - ViewModel

enum SKFavoritesSortMode: String {
    case date
    case alphabet
}

@MainActor
final class SKFavoritesViewModel: ObservableObject {
    @Published private(set) var favorites: [SKFavoriteWord] = []
    @Published var sortMode: SKFavoritesSortMode {
        didSet {
            UserDefaults.standard.set(sortMode.rawValue, forKey: Self.sortModeKey)
            sortFavorites()
        }
    }

    private static let sortModeKey = "favoritesSortModeKey"
    private var unsorted: [SKFavoriteWord] = []

    init() {
        let storedMode = UserDefaults.standard.string(forKey: Self.sortModeKey).flatMap(SKFavoritesSortMode.init)
        self.sortMode = storedMode ?? .date
    }

    func reload() {
        unsorted = SKFavoritesController.shared.favorites
        sortFavorites()
    }

    func deleteFavorite(at offsets: IndexSet) {
        for index in offsets {
            SKFavoritesController.shared.removeFavorite(favorites[index])
        }
        reload()
    }

    private func sortFavorites() {
        switch sortMode {
        case .date:
            favorites = unsorted.sorted { $0.dateAdded > $1.dateAdded }
        case .alphabet:
            favorites = unsorted.sorted { $0.word.word.localizedStandardCompare($1.word.word) == .orderedAscending }
        }
    }
}

// MARK: - Content view

private struct SKFavoritesContentView: View {
    @ObservedObject var viewModel: SKFavoritesViewModel
    var onWordSelected: (SKWord) -> Void

    var body: some View {
        Group {
            if viewModel.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(SKLocalization.favoritesEmptyPlaceholder)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }

    private var favoritesList: some View {
        List {
            ForEach(viewModel.favorites, id: \.word.uniqueId) { favorite in
                Button {
                    onWordSelected(favorite.word)
                } label: {
                    wordCell(favorite.word)
                }
                .listRowBackground(Color.appBackground)
            }
            .onDelete { viewModel.deleteFavorite(at: $0) }
        }
        .listStyle(.plain)
        .modifier(ListBackgroundModifier())
    }

    @ViewBuilder
    private func wordCell(_ word: SKWord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(word.word).foregroundColor(.primary)
            if let name = word.lang_id.name {
                Text(name.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Main view

struct SKFavoritesView: View {
    @ObservedObject var viewModel: SKFavoritesViewModel
    var onWordSelected: (SKWord) -> Void = { _ in }

    var body: some View {
        SKFavoritesContentView(viewModel: viewModel, onWordSelected: onWordSelected)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortMenu
                }
            }
            .modifier(OpaqueTabBarModifier())
    }

    private var sortMenu: some View {
        Menu {
            Button {
                viewModel.sortMode = .date
            } label: {
                if viewModel.sortMode == .date {
                    Label(SKLocalization.favoritesSortByDate, systemImage: "checkmark")
                } else {
                    Text(SKLocalization.favoritesSortByDate)
                }
            }
            Button {
                viewModel.sortMode = .alphabet
            } label: {
                if viewModel.sortMode == .alphabet {
                    Label(SKLocalization.favoritesSortByAlphabet, systemImage: "checkmark")
                } else {
                    Text(SKLocalization.favoritesSortByAlphabet)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}
