//
//  SKTabBarController.swift
//  Skarnik
//

import UIKit
import SwiftUI

class SKTabBarController: UITabBarController, UITabBarControllerDelegate {

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
            image: UIImage(systemName: "clock"),
            tag: 0
        )
        let historyNav = UINavigationController(rootViewController: historyVC)

        // Vocabularies tab
        let vocabVC = SKVocabulariesTableViewController()
        vocabVC.tabBarItem = UITabBarItem(
            title: SKLocalization.tabVocabularies,
            image: UIImage(systemName: "text.book.closed"),
            tag: 1
        )
        let vocabNav = UINavigationController(rootViewController: vocabVC)

        // Settings tab
        let settingsVC = SKSettingsViewController()
        let settingsTabItem = UITabBarItem(
            title: SKLocalization.tabSettings,
            image: UIImage(systemName: "gearshape"),
            tag: 2
        )
        // Empty-string badge renders as an unread dot (no number) — one-time promo for the
        // offline-dictionaries feature, dismissed for good the first time this tab is opened.
        settingsTabItem.badgeValue = SKOfflineDictionaryStorage.shared.promoSeen ? nil : ""
        settingsVC.tabBarItem = settingsTabItem
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        self.settingsNav = settingsNav

        viewControllers = [historyNav, vocabNav, settingsNav]
        selectedIndex = 0
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard viewController === settingsNav else { return }
        SKOfflineDictionaryStorage.shared.markPromoSeen()
        viewController.tabBarItem.badgeValue = nil
    }
}
