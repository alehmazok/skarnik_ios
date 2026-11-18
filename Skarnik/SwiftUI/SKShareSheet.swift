//
//  SKShareSheet.swift
//  Skarnik
//
//  The word screen's share sheet. A plain button logs `share` and then presents
//  `UIActivityViewController`, instead of `ShareLink`: ShareLink has no action callback, and a
//  simultaneous tap gesture on it often did not fire, so `share` was under-reported (#95).
//

import LinkPresentation
import SwiftUI
import UIKit

/// The link in a share: the item itself, the subject for Mail, and the preview in the sheet header.
final class SKShareLinkItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String

    init(url: URL, title: String) {
        self.url = url
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        return metadata
    }
}

enum SKShareSheet {

    /// «word» as text plus the link, as `ShareLink(item:subject:message:)` shared it: a plain chat
    /// shows what the link is about, Mail gets the word as subject, the link keeps its preview.
    static func activityItems(for translation: SKSkarnikTranslation) -> [Any]? {
        guard let url = URL(string: translation.sharingUrl) else { return nil }
        let title = translation.shareTitle
        return [title, SKShareLinkItem(url: url, title: title)]
    }

    /// Logs `share` (same name and params as Android, on tap, like Android's share sheet) and opens
    /// the sheet over the screen that holds `anchor`. On iPad the sheet is a popover from the Share
    /// button when it can be found, else from the bottom-leading corner where the button sits.
    @MainActor
    static func present(_ translation: SKSkarnikTranslation,
                        from anchor: UIView?,
                        log: (SKSkarnikTranslation) -> Void = SKShareSheet.logShare) {
        guard let items = activityItems(for: translation) else { return }
        log(translation)

        guard let anchor, let presenter = presenter(for: anchor) else { return }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            if let item = barItem(withIdentifier: shareButtonIdentifier, in: anchor.window) {
                popover.sourceItem = item
            } else if let view = view(withIdentifier: shareButtonIdentifier, in: anchor.window) {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            } else {
                popover.sourceView = anchor
                popover.sourceRect = fallbackSourceRect(in: anchor.bounds, safeArea: anchor.safeAreaInsets)
            }
        }
        presenter.present(controller, animated: true)
    }

    static func logShare(_ translation: SKSkarnikTranslation) {
        SKAnalyticsManager.logShareClicked(word: translation.word, url: translation.sharingUrl)
    }

    static let shareButtonIdentifier = "wordDetails.share"

    /// A small rect at the bottom-leading corner, just above the bottom safe area (the toolbar).
    static func fallbackSourceRect(in bounds: CGRect, safeArea: UIEdgeInsets) -> CGRect {
        let side: CGFloat = 44
        let x = bounds.minX + max(safeArea.left, 8)
        let y = max(bounds.minY, bounds.maxY - safeArea.bottom - side)
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// The view controller showing `anchor`, or what it already presents on top.
    private static func presenter(for anchor: UIView) -> UIViewController? {
        var responder: UIResponder? = anchor
        while let current = responder, !(current is UIViewController) {
            responder = current.next
        }
        var controller = (responder as? UIViewController) ?? anchor.window?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }

    private static func barItem(withIdentifier identifier: String, in root: UIView?) -> UIBarButtonItem? {
        guard let root else { return nil }
        if let toolbar = root as? UIToolbar,
           let item = toolbar.items?.first(where: { $0.accessibilityIdentifier == identifier }) {
            return item
        }
        for subview in root.subviews {
            if let item = barItem(withIdentifier: identifier, in: subview) { return item }
        }
        return nil
    }

    private static func view(withIdentifier identifier: String, in root: UIView?) -> UIView? {
        guard let root else { return nil }
        if root.accessibilityIdentifier == identifier, !root.isHidden, root.window != nil,
           root.bounds.width > 0, root.bounds.height > 0 {
            return root
        }
        for subview in root.subviews {
            if let view = view(withIdentifier: identifier, in: subview) { return view }
        }
        return nil
    }
}

/// An invisible view in the word screen, so a SwiftUI button can find its window and view
/// controller to present the share sheet from.
struct SKShareAnchor: UIViewRepresentable {
    let holder: SKShareAnchorHolder

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        holder.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        holder.view = uiView
    }
}

final class SKShareAnchorHolder {
    weak var view: UIView?
}
