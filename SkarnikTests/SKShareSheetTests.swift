//
//  SKShareSheetTests.swift
//  SkarnikTests
//

import LinkPresentation
import UIKit
import XCTest
@testable import Skarnik

@MainActor
final class SKShareSheetTests: XCTestCase {

    private let translation = SKSkarnikTranslation(
        word: SKWord(word_id: 27890, word: "добразычлівасць", lang_id: .bel_rus),
        url: "https://example.com",
        html: "",
        stress: "добразы́члівасць"
    )

    func testActivityItems_areTitleThenLink() throws {
        let items = try XCTUnwrap(SKShareSheet.activityItems(for: translation))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0] as? String, "добразы́члівасць")
        let link = try XCTUnwrap(items[1] as? SKShareLinkItem)
        XCTAssertEqual(link.url.absoluteString, "https://skarnik.app/r/belrus/27890")
        XCTAssertEqual(link.title, "добразы́члівасць")
    }

    func testLinkItem_givesUrlSubjectAndPreview() throws {
        let url = try XCTUnwrap(URL(string: "https://skarnik.app/r/belrus/27890"))
        let item = SKShareLinkItem(url: url, title: "мова")
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        XCTAssertEqual(item.activityViewControllerPlaceholderItem(controller) as? URL, url)
        XCTAssertEqual(item.activityViewController(controller, itemForActivityType: .mail) as? URL, url)
        XCTAssertEqual(item.activityViewController(controller, subjectForActivityType: .mail), "мова")
        let metadata = try XCTUnwrap(item.activityViewControllerLinkMetadata(controller))
        XCTAssertEqual(metadata.url, url)
        XCTAssertEqual(metadata.originalURL, url)
        XCTAssertEqual(metadata.title, "мова")
    }

    /// The tap itself logs `share`, even when there is nothing to present from (#95).
    func testPresent_logsShareOnTap() {
        var logged: [String] = []
        SKShareSheet.present(translation, from: nil) { logged.append($0.sharingUrl) }
        XCTAssertEqual(logged, ["https://skarnik.app/r/belrus/27890"])
    }

    func testFallbackSourceRect_sitsAboveBottomSafeAreaAtLeadingEdge() {
        let rect = SKShareSheet.fallbackSourceRect(
            in: CGRect(x: 0, y: 0, width: 800, height: 1000),
            safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 70, right: 0)
        )
        XCTAssertEqual(rect, CGRect(x: 8, y: 886, width: 44, height: 44))
    }
}
