//
//  SKSplitViewController.swift
//  Skarnik
//
//  Created by Logout on 6.10.22.
//

import UIKit

class SKSplitViewController: UISplitViewController {

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        self.preferredDisplayMode = .oneBesideSecondary

        // Storyboard sets detail VC directly (no UINavigationController), so .bottomBar
        // toolbar spans full screen width and button position shifts per split ratio.
        // Wrapping in a nav controller bounds the toolbar to the secondary column.
        if let detail = viewControllers.last, !(detail is UINavigationController) {
            viewControllers = [viewControllers[0], UINavigationController(rootViewController: detail)]
        }
    }
    
}

// MARK: - Word detail navigation helper

extension UIViewController {
    /// Opens `word` in the word details screen.
    ///
    /// - Collapsed (iPhone): pushes a new `SKWordDetailsViewController` onto the
    ///   current navigation stack, which is the standard list→detail pattern.
    /// - Non-collapsed (iPad): updates the existing secondary column VC in place.
    func showWordInDetail(_ word: SKWord, entryPoint: String) {
        guard let splitVC = view.window?.rootViewController as? SKSplitViewController else { return }

        if splitVC.isCollapsed {
            // iPhone: push a fresh instance onto the visible nav stack.
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let vc = storyboard.instantiateViewController(
                withIdentifier: "SKWordDetailsViewController"
            ) as? SKWordDetailsViewController else { return }
            vc.hidesBottomBarWhenPushed = true
            vc.entryPoint = entryPoint
            vc.word = word
            // `self` may be the split VC (e.g. called from SceneDelegate on a warm
            // launch), which has no navigationController. Resolve via the tab bar
            // instead so the push always lands on the selected tab's nav stack.
            // The caller's own stack comes first: with the iOS 26 `UITab` API the tab bar's
            // `selectedViewController` is not always the tab's navigation controller.
            let navController = self.navigationController
                ?? (splitVC.viewControllers.first as? UITabBarController)?
                .selectedViewController as? UINavigationController
            navController?.pushViewController(vc, animated: true)
        } else {
            // iPad: update the existing secondary column VC and show it.
            let secondaryNav = splitVC.viewControllers.last as? UINavigationController
            guard let wordDetailsVC = secondaryNav?.topViewController as? SKWordDetailsViewController
                    ?? splitVC.viewControllers.last as? SKWordDetailsViewController else { return }
            wordDetailsVC.entryPoint = entryPoint
            wordDetailsVC.word = word
            // The search field keeps focus beside the word; hide the keyboard so it does not cover
            // the article and its toolbar (Share, Bookmark). The query and results stay.
            view.window?.endEditing(true)
            splitVC.showDetailViewController(secondaryNav ?? wordDetailsVC, sender: self)
        }
    }
}

extension SKSplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return .primary
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        return true
    }
}
