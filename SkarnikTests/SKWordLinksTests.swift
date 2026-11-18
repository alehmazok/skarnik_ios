import XCTest
import UIKit
@testable import Skarnik

/// Tappable Belarusian words in translations (same rules as skarnik_android's `FindWordLinksUseCase`).
final class SKWordLinksTests: XCTestCase {

    private let yantar = URL(string: "https://skarnik.app/r/belrus/10")!
    private let burshtyn = URL(string: "https://skarnik.app/r/belrus/20")!

    private func wordLinks(in text: NSAttributedString) -> [(word: String, url: URL)] {
        var links: [(String, URL)] = []
        text.enumerateAttribute(.skWordLink, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let url = value as? URL else { return }
            links.append(((text.string as NSString).substring(with: range), url))
        }
        return links
    }

    func testWordKeyIsLowercaseWithoutStressMark() {
        XCTAssertEqual(SKSkarnikTranslation.wordKey("Я\u{301}нтар"), "янтар")
    }

    func testRunPartsAreSingleWordsBetweenCommas() {
        let parts = SKTranslationRenderer.runParts("янтар,  бурштын, брацца\u{00A0}за, ")
        XCTAssertEqual(parts.map { $0.word }, ["янтар", "бурштын"])
        XCTAssertEqual(parts.map { $0.range }, [NSRange(location: 0, length: 5), NSRange(location: 8, length: 7)])
    }

    func testRendererLinksKnownWordsOfHeadwordRunsOnly() {
        let html = """
        янтарь — <font color="#831b03">Я\u{301}нтар, <b>бурштын</b>, цельпука</font> \
        <a href="/belrus/20"><font color="#831b03">бурштын</font></a>
        """
        let text = SKTranslationRenderer.render(html: html, wordLinks: ["янтар": yantar, "бурштын": burshtyn])

        let links = wordLinks(in: text)
        XCTAssertEqual(links.map { $0.word }, ["Я\u{301}нтар", "бурштын"])
        XCTAssertEqual(links.map { $0.url }, [yantar, burshtyn])
        let start = (text.string as NSString).range(of: "Я\u{301}нтар").location
        let tag = text.attribute(.textItemTag, at: start, effectiveRange: nil) as? String
        XCTAssertEqual(tag, SKTranslationRenderer.wordLinkTagPrefix + yantar.absoluteString)
    }

    func testRendererLinksTinyMCEStyleAndDataWordRuns() {
        let html = """
        <span style="color: #831B03;">бурштын</span> <font color="#831b03" data-word="янтар"> я\u{301}нтар </font>
        """
        let text = SKTranslationRenderer.render(html: html, wordLinks: ["янтар": yantar, "бурштын": burshtyn])

        XCTAssertEqual(wordLinks(in: text).map { $0.word }, ["бурштын", "я\u{301}нтар"])
    }

    func testNoWordLinksWithoutTheMap() {
        let text = SKTranslationRenderer.render(html: ##"<font color="#831b03">янтар</font>"##)
        XCTAssertTrue(wordLinks(in: text).isEmpty)
    }

    func testUnderlinesOnlyTheLinkedWords() {
        let text = SKTranslationRenderer.render(html: ##"<font color="#831b03">янтар</font>, бурштын"##,
                                                wordLinks: ["янтар": yantar])

        XCTAssertNotNil(text.attribute(.underlineStyle, at: 0, effectiveRange: nil))
        let plain = (text.string as NSString).range(of: "бурштын").location
        XCTAssertNil(text.attribute(.underlineStyle, at: plain, effectiveRange: nil))
    }

    func testHeadwordColouredWordsAndDataWords() {
        let html = """
        <font color="#831b03">янтар, бурштын</font> <span style="color:#831b03">лодар</span> \
        <font color="#831b03">брацца&nbsp;за</font> <font color="#008000">муж.</font>
        """
        XCTAssertEqual(SKSkarnikTranslation.headwordColouredWords(inHtml: html), ["янтар", "бурштын", "лодар"])
        XCTAssertEqual(SKSkarnikTranslation.dataWords(inHtml: #"<a data-word="янтар">я</a> <b data-word="брацца за">x</b>"#),
                       ["янтар"])
    }

    func testBundledIndexFindsBelRusHeadwordsOnly() {
        let found = SKVocabularyIndex.shared.belarusianWords(["прывітанне", "привет", "прывітаннем"])
        XCTAssertEqual(Set(found.keys), ["прывітанне"])
        XCTAssertEqual(found["прывітанне"]?.lang_id, .bel_rus)
        XCTAssertEqual(found["прывітанне"]?.word, "прывітанне")
    }

    func testWordLinksOfARusBelTranslationLeaveOutUnknownWords() {
        let word = SKWord(word_id: 1, word: "привет", lang_id: .rus_bel)
        let translation = SKSkarnikTranslation(word: word, url: "", html: ##"<font color="#831b03">прывітанне, прывітаннем</font>"##)

        XCTAssertEqual(Array(translation.wordLinks.keys), ["прывітанне"])
    }

    func testATsbmTranslationHasNoWordLinks() {
        let word = SKWord(word_id: 1, word: "прывітанне", lang_id: .bel_definition)
        let translation = SKSkarnikTranslation(word: word, url: "", html: ##"<font color="#831b03">прывітанне</font>"##)

        XCTAssertTrue(translation.wordLinks.isEmpty)
    }

    @MainActor
    func testWordLinkUrlsRouteBackToTheirWord() {
        let word = SKWord(word_id: 27890, word: "бурштын", lang_id: .bel_rus)
        let url = SKSkarnikTranslation.url(of: word)
        XCTAssertEqual(url?.absoluteString, "https://skarnik.app/r/belrus/27890")
        XCTAssertEqual(SKWordDetailsViewModel.word(forUrl: url!.absoluteString)?.word_id, 27890)
        // Links in the legacy translation HTML are routed by path, whatever their host.
        XCTAssertEqual(SKWordDetailsViewModel.word(forUrl: "http://example.org/belrus/27890")?.word_id, 27890)
    }
}
