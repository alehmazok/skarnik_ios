//
//  SKHistoryViewController.swift
//  Skarnik
//

import SwiftUI
import UIKit

class SKHistoryViewController: UIHostingController<SKHistoryView> {

    let viewModel: SKHistoryViewModel

    /// On iOS 26 the field is a UIKit `UISearchController`, so a `UISearchTab` can move it to
    /// the bottom (Liquid Glass tab bar). Earlier versions keep SwiftUI's `.searchable` drawer.
    static var usesSystemSearchController: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Set only when `usesSystemSearchController` is `true`.
    private var searchController: UISearchController?

    init() {
        let vm = SKHistoryViewModel()
        self.viewModel = vm
        super.init(rootView: SKHistoryView(viewModel: vm, usesSystemSearchController: Self.usesSystemSearchController))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = SKLocalization.tabHistory
        navigationItem.largeTitleDisplayMode = .never
        rootView = SKHistoryView(
            viewModel: viewModel,
            usesSystemSearchController: Self.usesSystemSearchController,
            onWordSelected: { [weak self] word, entryPoint in
                self?.openWord(word, entryPoint: entryPoint)
            }
        )
        if Self.usesSystemSearchController {
            configureSearchController()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let word = sceneDelegate.pendingWord {
            sceneDelegate.pendingWord = nil
            openWord(word, entryPoint: "widget")
        }
    }

    /// Focuses the search field and shows the keyboard (Search tab re-tap).
    func activateSearch() {
        if let searchController {
            searchController.isActive = true
            Task { @MainActor in searchController.searchBar.becomeFirstResponder() }
            return
        }
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
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        searchController = controller
        observeSearchText()
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
