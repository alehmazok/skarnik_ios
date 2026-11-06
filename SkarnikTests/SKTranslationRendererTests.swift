import XCTest
import UIKit
@testable import Skarnik

final class SKTranslationRendererTests: XCTestCase {

    // MARK: - Helpers

    private func render(_ html: String,
                        theme: SKArticleColorTheme = .system,
                        contentSize: UIContentSizeCategory = .large,
                        layout: SKTranslationLayout = .article) -> NSAttributedString {
        SKTranslationRenderer.render(html: html,
                                     theme: theme,
                                     traits: SKTranslationRenderer.traits(contentSize: contentSize),
                                     layout: layout)
    }

    private func attributes(of part: String, in text: NSAttributedString,
                            file: StaticString = #filePath, line: UInt = #line) -> [NSAttributedString.Key: Any] {
        let range = (text.string as NSString).range(of: part)
        guard range.location != NSNotFound else {
            XCTFail("«\(part)» not found in «\(text.string)»", file: file, line: line)
            return [:]
        }
        return text.attributes(at: range.location, effectiveRange: nil)
    }

    private func color(of part: String, in text: NSAttributedString,
                       file: StaticString = #filePath, line: UInt = #line) -> UIColor? {
        attributes(of: part, in: text, file: file, line: line)[.foregroundColor] as? UIColor
    }

    private func font(of part: String, in text: NSAttributedString,
                      file: StaticString = #filePath, line: UInt = #line) -> UIFont? {
        attributes(of: part, in: text, file: file, line: line)[.font] as? UIFont
    }

    private func isBold(_ part: String, in text: NSAttributedString,
                        file: StaticString = #filePath, line: UInt = #line) -> Bool {
        font(of: part, in: text, file: file, line: line)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
    }

    private func isItalic(_ part: String, in text: NSAttributedString,
                          file: StaticString = #filePath, line: UInt = #line) -> Bool {
        font(of: part, in: text, file: file, line: line)?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
    }

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { ($0 * 255).rounded() }
    }

    private static let appearances: [UITraitCollection] = [
        UITraitCollection(userInterfaceStyle: .light),
        UITraitCollection(userInterfaceStyle: .dark),
        UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: .light),
                                       UITraitCollection(accessibilityContrast: .high)]),
        UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: .dark),
                                       UITraitCollection(accessibilityContrast: .high)])
    ]

    /// Same colour in light, dark and both with Increase Contrast.
    private func assertColor(_ actual: UIColor?, _ expected: UIColor,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("no foreground colour", file: file, line: line)
            return
        }
        for traits in Self.appearances {
            XCTAssertEqual(rgba(actual.resolvedColor(with: traits)), rgba(expected.resolvedColor(with: traits)),
                           "\(traits)", file: file, line: line)
        }
    }

    private var bodySize: CGFloat {
        UIFont.preferredFont(forTextStyle: .body,
                             compatibleWith: SKTranslationRenderer.traits(contentSize: .large)).pointSize
    }

    // MARK: - Colours

    func testMapsLegacyColoursToSemanticRoles() {
        let text = render(
            "<font size=\"+2\" color=\"#831b03\">янтар</font>, <i>-ру <font color=\"008000\">муж.</font></i> " +
            "<font color=\"#5F5F5F\">заст.</font> <font color=\"#123456\">іншае</font>"
        )

        XCTAssertEqual(text.string, "янтар, -ру муж. заст. іншае")
        assertColor(color(of: "янтар", in: text), .label)
        XCTAssertTrue(isBold("янтар", in: text), "translated words are bold in the system theme")
        assertColor(color(of: "муж.", in: text), .systemIndigo)
        XCTAssertTrue(isItalic("муж.", in: text))
        assertColor(color(of: "заст.", in: text), .secondaryLabel)
        assertColor(color(of: "іншае", in: text), .label)
        XCTAssertFalse(isBold("іншае", in: text))
    }

    func testReadsColourFromInlineCssAndIgnoresFontSizes() {
        let text = render("<span style=\"font-size: small; color: #831b03;\">слова</span> " +
                          "<font size=\"5\">-ці</font>")

        assertColor(color(of: "слова", in: text), .label)
        XCTAssertTrue(isBold("слова", in: text))
        XCTAssertEqual(font(of: "слова", in: text)?.pointSize, bodySize)
        XCTAssertEqual(font(of: "-ці", in: text)?.pointSize, bodySize)
    }

    func testSkarnikRedThemeUsesTheAccentWithoutForcedBold() {
        let text = render("<font color=\"831b03\">слова</font> <span style=\"color: #0000a0;\">кара</span>",
                          theme: .skarnikRed)

        assertColor(color(of: "слова", in: text), SKTranslationRenderer.skarnikRed)
        assertColor(color(of: "кара", in: text), SKTranslationRenderer.skarnikRed)
        XCTAssertFalse(isBold("слова", in: text))
        XCTAssertFalse(isBold("кара", in: text))
    }

    func testSkarnikRedFollowsIncreaseContrast() {
        let red = SKTranslationRenderer.skarnikRed
        let light = red.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let lightHigh = red.resolvedColor(with: Self.appearances[2])
        let darkHigh = red.resolvedColor(with: Self.appearances[3])
        XCTAssertNotEqual(rgba(light), rgba(lightHigh))
        XCTAssertNotEqual(rgba(light), rgba(darkHigh))
    }

    func testWhiteSpacersAreInvisible() {
        let text = render("а<font color=\"#FFFFFF\">.</font>б")

        XCTAssertEqual(color(of: ".", in: text)?.cgColor.alpha, 0)
    }

    // MARK: - Text and whitespace

    func testBoldItalicUnderlineAndSuperscript() {
        let text = render("<b>тоўсты</b> <i>курсіў</i> <u>падкрэслены</u> x<sup>2</sup>")

        XCTAssertEqual(text.string, "тоўсты курсіў падкрэслены x2")
        XCTAssertTrue(isBold("тоўсты", in: text))
        XCTAssertTrue(isItalic("курсіў", in: text))
        XCTAssertEqual(attributes(of: "падкрэслены", in: text)[.underlineStyle] as? Int,
                       NSUnderlineStyle.single.rawValue)
        XCTAssertGreaterThan((attributes(of: "2", in: text)[.baselineOffset] as? CGFloat) ?? 0, 0)
        XCTAssertLessThan(font(of: "2", in: text)?.pointSize ?? .greatestFiniteMagnitude, bodySize)
    }

    func testCssFontWeightAndStyle() {
        let text = render("<span style=\"font-weight: bold\">а</span> <span style=\"font-style: italic\">б</span>")

        XCTAssertTrue(isBold("а", in: text))
        XCTAssertTrue(isItalic("б", in: text))
    }

    func testKeepsNonBreakingSpacesCollapsesOtherWhitespaceBreaksLinesOnBr() {
        let text = render("&nbsp;&nbsp;адзін \n\n  два<br>  тры<br/>")

        XCTAssertEqual(text.string, "\u{00A0}\u{00A0}адзін два\nтры")
    }

    func testRunOfSpacesAndNbspInsideALineBecomesOneGap() {
        let text = render(
            "благожелательность — &nbsp;<font color=\"#831b03\">добразычлівасць</font>" +
            "<span>&nbsp;</span> <i>жен.</i> ж.&nbsp;р."
        )

        XCTAssertEqual(text.string, "благожелательность — добразычлівасць\u{00A0}жен. ж.\u{00A0}р.")
    }

    func testKeepsNonBreakingIndentsAfterALineBreak() {
        let text = render("адзін<br>&nbsp;&nbsp; &nbsp;два")

        XCTAssertEqual(text.string, "адзін\n\u{00A0}\u{00A0}\u{00A0}два")
    }

    func testDropsScriptsAndKeepsTextOfUnknownTags() {
        let text = render("<script>alert(1)</script><blink>тэкст</blink>")

        XCTAssertEqual(text.string, "тэкст")
    }

    func testEmptyHtmlRendersEmptyText() {
        XCTAssertEqual(render("").length, 0)
        XCTAssertEqual(render("<br/> &nbsp; <p></p>").length, 0)
    }

    // MARK: - Links and data-word

    func testLinksKeepTheirHref() {
        let text = render("<i>смотрите</i> <a href=\"http://www.skarnik.by/rusbel/47880\">нерв</a>")

        XCTAssertEqual(text.string, "смотрите нерв")
        XCTAssertEqual(attributes(of: "нерв", in: text)[.link] as? URL,
                       URL(string: "http://www.skarnik.by/rusbel/47880"))
        XCTAssertNil(attributes(of: "смотрите", in: text)[.link])
    }

    func testRelativeLinksResolveAgainstSkarnikBy() {
        let text = render("<a href=\"/belrus/123\">слова</a>")

        XCTAssertEqual((attributes(of: "слова", in: text)[.link] as? URL)?.absoluteString,
                       "https://www.skarnik.by/belrus/123")
    }

    func testKeepsDataWord() {
        let text = render("<span data-word=\"добразычлівы\" data-link=\"/belrus/27891\">добразы́члівы</span>, " +
                          "<span data-word=\"прыхільны\">прыхі́льны</span>")

        XCTAssertEqual(text.string, "добразы́члівы, прыхі́льны")
        XCTAssertEqual(attributes(of: "добразы́члівы", in: text)[.skDataWord] as? String, "добразычлівы")
        XCTAssertEqual(attributes(of: "прыхі́льны", in: text)[.skDataWord] as? String, "прыхільны")
        XCTAssertNil(attributes(of: ",", in: text)[.skDataWord])
    }

    // MARK: - Layout and Dynamic Type

    func testArticleLayoutSpacesEntriesWithoutIndentingWrappedLines() {
        let text = render("першы радок<br>другі<br>трэці")

        XCTAssertEqual(text.string, "першы радок\nдругі\nтрэці")
        let style = attributes(of: "другі", in: text)[.paragraphStyle] as? NSParagraphStyle
        XCTAssertGreaterThan(style?.paragraphSpacing ?? 0, 0)
        XCTAssertEqual(style?.headIndent, 0)
        XCTAssertEqual(style?.firstLineHeadIndent, 0)
    }

    func testCompactLayoutHasNoExtraSpacing() {
        let text = render("а<br>б", layout: .compact)

        let style = attributes(of: "б", in: text)[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(style?.paragraphSpacing, 0)
        XCTAssertEqual(style?.headIndent, 0)
    }

    func testFollowsDynamicType() {
        let html = "<b>слова</b> пераклад<br>другі радок"
        let small = render(html, contentSize: .small)
        let large = render(html, contentSize: .accessibilityExtraLarge)

        let smallFont = font(of: "пераклад", in: small)?.pointSize ?? 0
        let largeFont = font(of: "пераклад", in: large)?.pointSize ?? 0
        XCTAssertGreaterThan(largeFont, smallFont)
        XCTAssertGreaterThan(font(of: "слова", in: large)?.pointSize ?? 0, font(of: "слова", in: small)?.pointSize ?? 0)
        XCTAssertTrue(isBold("слова", in: large))

        let smallSpacing = (attributes(of: "другі", in: small)[.paragraphStyle] as? NSParagraphStyle)?.paragraphSpacing ?? 0
        let largeSpacing = (attributes(of: "другі", in: large)[.paragraphStyle] as? NSParagraphStyle)?.paragraphSpacing ?? 0
        XCTAssertGreaterThan(largeSpacing, smallSpacing)
    }

    // MARK: - Stress table classes

    func testStylesStressTableClasses() {
        let text = render("Назоўны<br><span class=\"pytanne\">хто? што?</span>" +
                          "<br><span class=\"skarot\">мн.</span>&nbsp;<b> ру́кі </b>",
                          layout: .compact)

        XCTAssertEqual(text.string, "Назоўны\nхто? што?\nмн.\u{00A0}ру́кі")
        assertColor(color(of: "хто? што?", in: text), .secondaryLabel)
        XCTAssertTrue(isItalic("хто? што?", in: text))
        XCTAssertLessThan(font(of: "хто? што?", in: text)?.pointSize ?? .greatestFiniteMagnitude, bodySize)
        assertColor(color(of: "мн.", in: text), .systemIndigo)
        XCTAssertTrue(isItalic("мн.", in: text))
        XCTAssertFalse(isBold("мн.", in: text))
        XCTAssertTrue(isBold("ру́кі", in: text))
    }

    // MARK: - Entries from all three dictionaries

    /// ТСБМ «кара», the sample used by the SKWordDetailsView previews.
    func testTsbmPreviewSample() {
        let text = render(SKTranslationSamples.tsbmKara)
        let string = text.string

        XCTAssertTrue(string.hasPrefix("ка́ра, -ы, жаночы род\nСуровае пакаранне, спагнанне за правіннасць."), string)
        XCTAssertFalse(string.contains("<"))
        XCTAssertFalse(string.contains("  "), "whitespace from the pretty-printed HTML is collapsed")
        XCTAssertFalse(string.contains(" \n"))
        XCTAssertFalse(string.contains("\n "))
        XCTAssertTrue(string.contains("\n•••\n"))
        XCTAssertTrue(string.hasSuffix("глядзі абрасці."))

        // Headword: bold primary text.
        assertColor(color(of: "ка́ра,", in: text), .label)
        XCTAssertTrue(isBold("ка́ра,", in: text))
        // Grammar: indigo.
        assertColor(color(of: "-ы, жаночы род", in: text), .systemIndigo)
        assertColor(color(of: "//", in: text), .systemIndigo)
        XCTAssertTrue(isBold("//", in: text))
        // Examples: secondary; authors: secondary italic.
        assertColor(color(of: "Панесці кару.", in: text), .secondaryLabel)
        assertColor(color(of: "Колас.", in: text), .secondaryLabel)
        XCTAssertTrue(isItalic("Колас.", in: text))
        // Definitions: plain text.
        assertColor(color(of: "Суровае пакаранне", in: text), .label)
        XCTAssertFalse(isBold("Суровае пакаранне", in: text))
        // Phrases: the inner headword colour wins over the outer example colour.
        assertColor(color(of: "Зямная кара", in: text), .label)
        XCTAssertTrue(isBold("Зямная кара", in: text))
    }

    /// Бел-Рус «добразычлівасць» (27890), with the admin's `<span>&nbsp;</span>` after the dash.
    func testBelRusEntry() {
        let text = render("<font color=\"831b03\">добразычлівасць</font> —<span>&nbsp;</span> благожелательность")

        XCTAssertEqual(text.string, "добразычлівасць —\u{00A0}благожелательность")
        XCTAssertTrue(isBold("добразычлівасць", in: text))
        assertColor(color(of: "благожелательность", in: text), .label)
        XCTAssertFalse(isBold("благожелательность", in: text))
    }

    /// Рус-Бел «благожелательность», several entries with a `smotrite` link.
    func testRusBelEntry() {
        let html = "благожелательность — <font size=\"+2\" color=\"#831b03\">добразычлівасць</font>, " +
            "<font size=\"5\">-ці</font> <i><font color=\"008000\">жен.</font></i><br>" +
            "благожелательный — <span data-word=\"добразычлівы\">добразы́члівы</span><br>" +
            "<i>смотрите</i> <a href=\"http://www.skarnik.by/rusbel/47880\">нерв</a>"
        let text = render(html)

        XCTAssertEqual(text.string,
                       "благожелательность — добразычлівасць, -ці жен.\n" +
                       "благожелательный — добразы́члівы\n" +
                       "смотрите нерв")
        XCTAssertTrue(isBold("добразычлівасць", in: text))
        assertColor(color(of: "жен.", in: text), .systemIndigo)
        XCTAssertEqual(attributes(of: "добразы́члівы", in: text)[.skDataWord] as? String, "добразычлівы")
        XCTAssertNotNil(attributes(of: "нерв", in: text)[.link])
    }

    // MARK: - SKSkarnikTranslation

    func testRenderedTextMatchesRenderer() async {
        let word = SKWord(word_id: 1, word: "кара", lang_id: .bel_definition)
        let translation = SKSkarnikTranslation(word: word, url: "https://example.com", html: SKTranslationSamples.tsbmKara)
        let traits = SKTranslationRenderer.traits(contentSize: .large)

        let text = await translation.renderedText(theme: .system, traits: traits)

        XCTAssertEqual(text.string, render(SKTranslationSamples.tsbmKara).string)
    }
}
