//
//  SKTabBarController.swift
//  Skarnik
//

import UIKit
import SwiftUI

class SKTabBarController: UITabBarController, UITabBarControllerDelegate {

    /// The Пошук tab's stack when it shows history + the search field at the top (iOS 17–25, or
    /// iOS 26 with «Радок пошуку ўнізе» off). Nil with the bottom search tab.
    private weak var historyNav: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabs()
        NotificationCenter.default.addObserver(
            self, selector: #selector(searchBarPlacementChanged),
            name: .skSearchBarPlacementChanged, object: nil
        )
    }

    @objc private func searchBarPlacementChanged() {
        // Налады is a sheet presented by the root controller, so swapping the tabs underneath is safe.
        setupTabs()
    }

    private func setupTabs() {
        let favoritesNav = UINavigationController(rootViewController: SKFavoritesViewController())
        let vocabNav = UINavigationController(rootViewController: SKVocabulariesTableViewController())

        if #available(iOS 26.0, *) {
            setupUITabs(favoritesNav: favoritesNav, vocabNav: vocabNav, placement: SKSearchBarPlacement.current())
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
        // Налады open from the gear on the start screen (SKHistoryViewController).
        viewControllers = [historyNav, favoritesNav, vocabNav]
        selectedIndex = 0
    }

    /// iOS 26, `.bottom`: Гісторыя is the start tab, and search is a `UISearchTab`. The system shows
    /// it as the round button at the end of the Liquid Glass tab bar; selecting it turns the tab bar
    /// into the search field at the bottom and focuses it.
    /// iOS 26, `.top`: the iOS 17–25 layout (one Пошук tab, field at the top), built with `UITab`
    /// so the tab bar can switch between the two without being recreated.
    @available(iOS 26.0, *)
    private func setupUITabs(
        favoritesNav: UINavigationController,
        vocabNav: UINavigationController,
        placement: SKSearchBarPlacement
    ) {
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

        switch placement {
        case .bottom:
            self.historyNav = nil
            let listNav = UINavigationController(rootViewController: SKHistoryViewController(mode: .historyOnly))
            let searchNav = UINavigationController(rootViewController: SKHistoryViewController(mode: .searchOnly))
            let historyTab = UITab(
                title: SKLocalization.tabHistoryList,
                image: UIImage(systemName: "clock.arrow.circlepath"),
                identifier: "history"
            ) { _ in listNav }
            let searchTab = UISearchTab { _ in searchNav }
            searchTab.title = SKLocalization.tabHistory
            searchTab.automaticallyActivatesSearch = true
            tabs = [historyTab, favoritesTab, vocabTab, searchTab]
            selectedTab = historyTab
        case .top:
            let historyNav = UINavigationController(rootViewController: SKHistoryViewController(mode: .historyAndSearch))
            self.historyNav = historyNav
            let historyTab = UITab(
                title: SKLocalization.tabHistory,
                image: UIImage(systemName: "magnifyingglass"),
                identifier: "historyAndSearch"
            ) { _ in historyNav }
            tabs = [historyTab, favoritesTab, vocabTab]
            selectedTab = historyTab
        }
    }

    /// The `UITab` API's re-tap callback (iOS 26 with the field at the top), same rule as below.
    /// If UIKit calls both callbacks, the second `activateSearch()` only refocuses the field.
    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        if tab === selectedTab, let historyNav, tab.viewController === historyNav {
            activateSearchIfAtRoot(historyNav)
        }
        return true
    }

    private func activateSearchIfAtRoot(_ historyNav: UINavigationController) {
        if historyNav.viewControllers.count == 1,
           let historyVC = historyNav.viewControllers.first as? SKHistoryViewController {
            historyVC.activateSearch()
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // A re-tap on the active Search tab is its primary action: focus the search field.
        // Checked here, before the switch, because didSelect fires for first and repeat taps alike.
        // With a word open, the re-tap keeps UIKit's default pop-to-root and does nothing else;
        // the next re-tap (now at the root) opens search. Not used with the bottom search tab,
        // which focuses the field itself (historyNav is nil then).
        if viewController === selectedViewController,
           let historyNav, viewController === historyNav {
            activateSearchIfAtRoot(historyNav)
        }
        return true
    }
}

// MARK: - Search bar placement

/// Where the search field lives. iOS 26 defaults to the bottom search tab; the user can switch
/// back to the iOS 17–25 layout (one Пошук tab, field at the top) in Налады.
enum SKSearchBarPlacement: String {
    case bottom
    case top

    static let userDefaultsKey = "searchBarAtBottom"
    /// Firebase user property, so we can see how many people switch back.
    static let userPropertyName = "search_bar_position"

    /// The bottom search tab needs iOS 26 (Liquid Glass `UISearchTab`).
    static var isBottomAvailable: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// The user's choice; on by default.
    static func prefersBottom(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: userDefaultsKey) as? Bool ?? true
    }

    static func current(in defaults: UserDefaults = .standard, bottomAvailable: Bool = isBottomAvailable) -> SKSearchBarPlacement {
        bottomAvailable && prefersBottom(in: defaults) ? .bottom : .top
    }
}

extension Notification.Name {
    /// Posted after the user changes «Радок пошуку ўнізе»; the tab bar rebuilds.
    static let skSearchBarPlacementChanged = Notification.Name("SKSearchBarPlacementChanged")
}
