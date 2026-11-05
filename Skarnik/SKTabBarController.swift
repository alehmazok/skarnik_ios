//
//  SKTabBarController.swift
//  Skarnik
//

import UIKit
import SwiftUI

class SKTabBarController: UITabBarController, UITabBarControllerDelegate {

    private weak var historyNav: UINavigationController?
    private weak var settingsNav: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabs()
    }

    private func setupTabs() {
        // History tab
        let historyVC = SKHistoryViewController()
        historyVC.tabBarItem = UITabBarItem(
            title: SKLocalization.tabHistory,
            image: UIImage(systemName: "magnifyingglass"),
            tag: 0
        )
        let historyNav = UINavigationController(rootViewController: historyVC)
        self.historyNav = historyNav

        // Favorites tab
        let favoritesVC = SKFavoritesViewController()
        favoritesVC.tabBarItem = UITabBarItem(
            title: SKLocalization.tabFavorites,
            image: UIImage(systemName: "bookmark"),
            tag: 1
        )
        let favoritesNav = UINavigationController(rootViewController: favoritesVC)

        // Vocabularies tab
        let vocabVC = SKVocabulariesTableViewController()
        vocabVC.tabBarItem = UITabBarItem(
            title: SKLocalization.tabVocabularies,
            image: UIImage(systemName: "text.book.closed"),
            tag: 2
        )
        let vocabNav = UINavigationController(rootViewController: vocabVC)

        // Settings tab
        let settingsVC = SKSettingsViewController()
        let settingsTabItem = UITabBarItem(
            title: SKLocalization.tabSettings,
            image: UIImage(systemName: "gearshape"),
            tag: 3
        )
        // Empty-string badge renders as an unread dot (no number) — one-time promo for the
        // offline-dictionaries feature, dismissed for good the first time this tab is opened.
        settingsTabItem.badgeValue = SKOfflineDictionaryStorage.shared.promoSeen ? nil : ""
        settingsVC.tabBarItem = settingsTabItem
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        self.settingsNav = settingsNav

        viewControllers = [historyNav, favoritesNav, vocabNav, settingsNav]
        selectedIndex = 0
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // A re-tap on the active Search tab is its primary action: focus the search field.
        // Checked here, before the switch, because didSelect fires for first and repeat taps alike.
        // With a word open, the re-tap keeps UIKit's default pop-to-root and does nothing else;
        // the next re-tap (now at the root) opens search.
        if viewController === selectedViewController,
           let historyNav, viewController === historyNav,
           historyNav.viewControllers.count == 1,
           let historyVC = historyNav.viewControllers.first as? SKHistoryViewController {
            historyVC.activateSearch()
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard viewController === settingsNav else { return }
        SKOfflineDictionaryStorage.shared.markPromoSeen()
        viewController.tabBarItem.badgeValue = nil
    }
}
