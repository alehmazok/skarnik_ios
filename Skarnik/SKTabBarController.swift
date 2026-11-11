//
//  SKTabBarController.swift
//  Skarnik
//

import UIKit
import SwiftUI

class SKTabBarController: UITabBarController, UITabBarControllerDelegate {

    private weak var historyNav: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabs()
    }

    private func setupTabs() {
        let favoritesNav = UINavigationController(rootViewController: SKFavoritesViewController())
        let vocabNav = UINavigationController(rootViewController: SKVocabulariesTableViewController())
        let settingsNav = UINavigationController(rootViewController: SKSettingsViewController())

        if #available(iOS 26.0, *) {
            setupTabsWithSearchTab(favoritesNav: favoritesNav, vocabNav: vocabNav, settingsNav: settingsNav)
            return
        }

        // iOS 17–25: one Пошук tab with history and the search field at the top.
        let historyVC = SKHistoryViewController(mode: .historyAndSearch)
        historyVC.tabBarItem = UITabBarItem(
            title: SKLocalization.tabHistory,
            image: UIImage(systemName: "magnifyingglass"),
            tag: 0
        )
        let historyNav = UINavigationController(rootViewController: historyVC)
        self.historyNav = historyNav

        favoritesNav.tabBarItem = UITabBarItem(
            title: SKLocalization.tabFavorites,
            image: UIImage(systemName: "bookmark"),
            tag: 1
        )
        vocabNav.tabBarItem = UITabBarItem(
            title: SKLocalization.tabVocabularies,
            image: UIImage(systemName: "text.book.closed"),
            tag: 2
        )
        settingsNav.tabBarItem = UITabBarItem(
            title: SKLocalization.tabSettings,
            image: UIImage(systemName: "gearshape"),
            tag: 3
        )

        viewControllers = [historyNav, favoritesNav, vocabNav, settingsNav]
        selectedIndex = 0
    }

    /// iOS 26: Гісторыя is the start tab, and search is a `UISearchTab`. The system shows it as
    /// the round button at the end of the Liquid Glass tab bar; selecting it turns the tab bar
    /// into the search field at the bottom and focuses it.
    @available(iOS 26.0, *)
    private func setupTabsWithSearchTab(
        favoritesNav: UINavigationController,
        vocabNav: UINavigationController,
        settingsNav: UINavigationController
    ) {
        let historyNav = UINavigationController(rootViewController: SKHistoryViewController(mode: .historyOnly))
        let searchNav = UINavigationController(rootViewController: SKHistoryViewController(mode: .searchOnly))

        let historyTab = UITab(
            title: SKLocalization.tabHistoryList,
            image: UIImage(systemName: "clock.arrow.circlepath"),
            identifier: "history"
        ) { _ in historyNav }
        let favoritesTab = UITab(
            title: SKLocalization.tabFavorites,
            image: UIImage(systemName: "bookmark"),
            identifier: "favorites"
        ) { _ in favoritesNav }
        let vocabTab = UITab(
            title: SKLocalization.tabVocabularies,
            image: UIImage(systemName: "text.book.closed"),
            identifier: "vocabularies"
        ) { _ in vocabNav }
        let settingsTab = UITab(
            title: SKLocalization.tabSettings,
            image: UIImage(systemName: "gearshape"),
            identifier: "settings"
        ) { _ in settingsNav }
        let searchTab = UISearchTab { _ in searchNav }
        searchTab.title = SKLocalization.tabHistory
        searchTab.automaticallyActivatesSearch = true

        tabs = [historyTab, favoritesTab, vocabTab, settingsTab, searchTab]
        selectedTab = historyTab
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // iOS 17–25 (historyNav is nil on iOS 26, where the UISearchTab focuses the field itself).
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
}
