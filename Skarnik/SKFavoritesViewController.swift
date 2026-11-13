//
//  SKFavoritesViewController.swift
//  Skarnik
//

import SwiftUI
import UIKit

class SKFavoritesViewController: UIHostingController<SKFavoritesView> {

    let viewModel: SKFavoritesViewModel

    init() {
        let vm = SKFavoritesViewModel()
        self.viewModel = vm
        super.init(rootView: SKFavoritesView(viewModel: vm))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = SKLocalization.tabFavorites
        navigationItem.largeTitleDisplayMode = .never
        rootView = SKFavoritesView(
            viewModel: viewModel,
            onWordSelected: { [weak self] word in
                self?.showWordInDetail(word, entryPoint: "favorites")
            }
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(favoritesChanged), name: .skFavoritesChanged, object: nil
        )
    }

    /// A bookmark changed on the word screen. On iPad that screen is beside this list.
    @objc private func favoritesChanged() {
        viewModel.reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
    }
}
