//
//  SKHistoryViewController.swift
//  Skarnik
//

import SwiftUI
import UIKit

class SKHistoryViewController: UIHostingController<SKHistoryView> {

    let viewModel: SKHistoryViewModel

    let mode: SKHistoryScreenMode

    /// Set only in `.searchOnly` mode: a UIKit `UISearchController`, so the iOS 26
    /// `UISearchTab` can show the field at the bottom of the Liquid Glass tab bar.
    private var searchController: UISearchController?
    /// Hosts the extra letter row used as the search bar's input accessory (`.searchOnly`).
    private var keyRowController: UIHostingController<SKSearchKeyRow>?

    init(mode: SKHistoryScreenMode = .historyAndSearch) {
        let vm = SKHistoryViewModel()
        self.viewModel = vm
        self.mode = mode
        super.init(rootView: SKHistoryView(viewModel: vm, mode: mode))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = mode == .historyOnly ? SKLocalization.tabHistoryList : SKLocalization.tabHistory
        navigationItem.largeTitleDisplayMode = .never
        rootView = SKHistoryView(
            viewModel: viewModel,
            mode: mode,
            onWordSelected: { [weak self] word, entryPoint in
                self?.openWord(word, entryPoint: entryPoint)
            }
        )
        if mode == .searchOnly {
            configureSearchController()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The widget opens words from the start tab only (the search tab is created lazily).
        if mode != .searchOnly,
           let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let word = sceneDelegate.pendingWord {
            sceneDelegate.pendingWord = nil
            openWord(word, entryPoint: "widget")
        }
    }

    /// Focuses the search field and shows the keyboard (Search tab re-tap on iOS 17–25).
    func activateSearch() {
        if !viewModel.isSearchPresented {
            // SwiftUI drives the field through `.searchable(isPresented:)`.
            viewModel.activateSearch()
        } else {
            // The field is still presented but its keyboard was dismissed: focus it again.
            searchBar?.becomeFirstResponder()
        }
    }

    // MARK: - Private

    private func configureSearchController() {
        let controller = UISearchController(searchResultsController: nil)
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchResultsUpdater = self
        controller.delegate = self
        controller.searchBar.placeholder = SKLocalization.searchbarSearchWords
        controller.searchBar.inputAccessoryView = makeKeyRowAccessory()
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        searchController = controller
        observeSearchText()
    }

    /// The extra letter row as an input accessory: it rides on the keyboard, and the iOS 26
    /// floating search field sits above it.
    private func makeKeyRowAccessory() -> UIView {
        let host = UIHostingController(rootView: SKSearchKeyRow { [weak self] char in
            self?.viewModel.insertCharacter(char)
        })
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: SKSearchKeyRow.height)
        host.view.autoresizingMask = [.flexibleWidth]
        keyRowController = host
        return host.view
    }

    /// Mirrors view-model edits (the extra key row) into the UIKit field.
    private func observeSearchText() {
        withObservationTracking {
            _ = viewModel.searchText
        } onChange: { [weak self] in
            // `onChange` fires before the new value is stored: read it on the next main-actor turn.
            Task { @MainActor [weak self] in
                guard let self, let searchBar = self.searchController?.searchBar else { return }
                if searchBar.text != self.viewModel.searchText {
                    searchBar.text = self.viewModel.searchText
                }
                self.observeSearchText()
            }
        }
    }

    /// The `UISearchBar` SwiftUI installs for `.searchable(placement: .navigationBarDrawer)`.
    private var searchBar: UISearchBar? {
        if let bar = navigationItem.searchController?.searchBar { return bar }
        return navigationController?.navigationBar.firstDescendant(of: UISearchBar.self)
    }

    private func openWord(_ word: SKWord, entryPoint: String) {
        if entryPoint != "history" {
            SKStorageController.shared.addWord(word)
            viewModel.reload()
        }
        showWordInDetail(word, entryPoint: entryPoint)
    }
}

// MARK: - UISearchController (iOS 26)

extension SKHistoryViewController: UISearchResultsUpdating, UISearchControllerDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text ?? ""
        if viewModel.searchText != text {
            viewModel.searchText = text
        }
    }

    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isSearchPresented = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isSearchPresented = false
    }
}

private extension UIView {
    func firstDescendant<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstDescendant(of: type) { return match }
        }
        return nil
    }
}
