//
//  SKHistoryViewController.swift
//  Skarnik
//

import SwiftUI
import UIKit

class SKHistoryViewController: UIHostingController<SKHistoryView> {

    let viewModel: SKHistoryViewModel

    init() {
        let vm = SKHistoryViewModel()
        self.viewModel = vm
        super.init(rootView: SKHistoryView(viewModel: vm))
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
            onWordSelected: { [weak self] word, entryPoint in
                self?.openWord(word, entryPoint: entryPoint)
            }
        )
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
        if #available(iOS 17, *), !viewModel.isSearchPresented {
            // SwiftUI drives the field through `.searchable(isPresented:)`.
            viewModel.activateSearch()
        } else {
            // iOS 15–16 have no `isPresented` binding; on iOS 17+ this also re-focuses a field
            // that is still presented but whose keyboard was dismissed.
            searchBar?.becomeFirstResponder()
        }
    }

    // MARK: - Private

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

private extension UIView {
    func firstDescendant<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstDescendant(of: type) { return match }
        }
        return nil
    }
}
