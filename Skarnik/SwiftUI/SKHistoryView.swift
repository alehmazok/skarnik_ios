//
//  SKHistoryView.swift
//  Skarnik
//

import Combine
import SwiftUI

// MARK: - ViewModel

@MainActor
final class SKHistoryViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { updateSearch(searchText) }
    }
    @Published private(set) var searchResults: [SKWord] = []
    @Published private(set) var words: [SKWord] = []

    private var searchTask: Task<Void, Never>?

    // Second, independent 500ms debounce layered on top of the search-as-you-type
    // above: only the last settle in a burst of typing fires a search analytics event.
    private let searchSettleSubject = PassthroughSubject<(query: String, resultCount: Int), Never>()
    private var cancellables = Set<AnyCancellable>()

    private let onSearchPerformed: (_ query: String, _ resultCount: Int) -> Void
    private let onSearchNoResults: (_ query: String) -> Void
    private let onSearchResultTapped: (_ word: SKWord, _ position: Int, _ query: String) -> Void

    init(
        onSearchPerformed: @escaping (_ query: String, _ resultCount: Int) -> Void = SKAnalyticsManager.logSearchPerformed,
        onSearchNoResults: @escaping (_ query: String) -> Void = SKAnalyticsManager.logSearchNoResults,
        onSearchResultTapped: @escaping (_ word: SKWord, _ position: Int, _ query: String) -> Void = SKAnalyticsManager.logSearchResultTapped
    ) {
        self.onSearchPerformed = onSearchPerformed
        self.onSearchNoResults = onSearchNoResults
        self.onSearchResultTapped = onSearchResultTapped

        searchSettleSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] settle in
                guard let self else { return }
                if settle.resultCount > 0 {
                    self.onSearchPerformed(settle.query, settle.resultCount)
                } else {
                    self.onSearchNoResults(settle.query)
                }
            }
            .store(in: &cancellables)
    }

    func reload() {
        words = SKStorageController.shared.words
    }

    func deleteWord(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            SKStorageController.shared.removeWord(index: index)
        }
        reload()
    }

    func updateSearch(_ text: String) {
        searchTask?.cancel()
        guard !text.isEmpty else {
            searchResults = []
            return
        }
        let query = text.lowercased()
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            let results = SKVocabularyIndex.shared.search(query: query, vocabularyType: .all, limit: 20).words
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                self.searchResults = results
                self.recordSearchSettle(query: trimmedText, resultCount: results.count)
            }
        }
    }

    /// Feeds the 500ms analytics debounce (§3 of the search analytics spec). Exposed
    /// (not private) so tests can drive settle timing without depending on the real
    /// SQLite-backed search pipeline in `updateSearch`.
    func recordSearchSettle(query: String, resultCount: Int) {
        searchSettleSubject.send((query: query, resultCount: resultCount))
    }

    func resultTapped(_ word: SKWord, position: Int) {
        onSearchResultTapped(word, position, searchText)
    }
}

// MARK: - Content view (reads isSearching from environment)

private struct SKHistoryContentView: View {
    @ObservedObject var viewModel: SKHistoryViewModel
    @Environment(\.isSearching) private var isSearching
    var onWordSelected: (SKWord, String) -> Void

    private static let rusKeyboardChars = ["и", "щ", "ъ"]
    private static let belKeyboardChars = ["і", "ў", "'"]

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if isSearching { belarusianKeyboardRow }
            }
    }

    // MARK: Content routing

    @ViewBuilder
    private var mainContent: some View {
        if isSearching {
            searchContent
        } else if viewModel.words.isEmpty {
            emptyState
        } else {
            wordList
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(SKLocalization.historyEmptyPlaceholder)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }

    // MARK: History list

    private var wordList: some View {
        List {
            ForEach(viewModel.words, id: \.uniqueId) { word in
                Button {
                    onWordSelected(word, "history")
                } label: {
                    wordCell(word)
                }
                .listRowBackground(Color.appBackground)
            }
            .onDelete { viewModel.deleteWord(at: $0) }
        }
        .listStyle(.plain)
        .modifier(ListBackgroundModifier())
    }

    // MARK: Search results

    @ViewBuilder
    private var searchContent: some View {
        if viewModel.searchResults.isEmpty {
            VStack {
                Text(SKLocalization.searchHeaderAdditionalRules)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .padding()
                Spacer()
            }
        } else {
            List(Array(viewModel.searchResults.enumerated()), id: \.element.uniqueId) { position, word in
                Button {
                    viewModel.resultTapped(word, position: position)
                    onWordSelected(word, "search")
                } label: {
                    wordCell(word)
                }
                .listRowBackground(Color.appBackground)
            }
            .listStyle(.plain)
            .modifier(ListBackgroundModifier())
        }
    }

    // MARK: Belarusian character row

    private var belarusianKeyboardRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.rusKeyboardChars, id: \.self) { keyboardKey($0, tint: .secondary) }
            Spacer()
            ForEach(Self.belKeyboardChars, id: \.self) { keyboardKey($0, tint: .accentColor) }
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
        .padding(.bottom, 6)
    }

    private var buttonBorderShape: ButtonBorderShape {
        if #available(iOS 17, *) { return .circle }
        return .roundedRectangle
    }

    @ViewBuilder
    private func keyboardKey(_ char: String, tint: Color) -> some View {
        let button = Button(action: { viewModel.searchText += char }) {
            Text(char)
                .font(.system(size: 17))
                .frame(width: 24, height: 24)
        }
        .buttonBorderShape(buttonBorderShape)
        .tint(tint)

        if #available(iOS 26.0, *) {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    // MARK: Cell helper

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

struct SKHistoryView: View {
    @ObservedObject var viewModel: SKHistoryViewModel
    var onWordSelected: (SKWord, String) -> Void = { _, _ in }

    var body: some View {
        SKHistoryContentView(viewModel: viewModel, onWordSelected: onWordSelected)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: SKLocalization.searchbarSearchWords
            )
            .modifier(OpaqueTabBarModifier())
    }
}
