//
//  SKTranslationRenderer.swift
//  Skarnik
//
//  Builds styled text from a translation's legacy HTML with SwiftSoup, without WebKit.
//  Same approach as skarnik_android (jsoup → AnnotatedString, ADR 0003).
//

import SwiftSoup
import UIKit

extension NSAttributedString.Key {
    /// The headword a `data-word` element stands for (rus_bel entries marked up by the admin's
    /// `find_inner_stress` / `fix_inner_stress`).
    static let skDataWord = NSAttributedString.Key("SKDataWord")
}

/// How the rendered text is laid out.
enum SKTranslationLayout {
    /// The translation screen: spacing between `<br>`-separated entries. No hanging indent: the
    /// source already indents definitions with `&nbsp;`, and both together push every line but
    /// the headwords to the right.
    case article
    /// Small fragments such as stress table cells: no extra spacing.
    case compact
}

/// Colours the legacy HTML uses, mapped to semantic roles. Any other colour is drawn as plain text,
/// so it stays readable in light, dark and Increase Contrast.
enum SKTranslationColorRole: CaseIterable {
    /// Headwords and translated words. Bold primary text, or the Skarnik red (Settings).
    case emphasis
    /// Grammar labels: «муж.», «смотрите», parts of speech.
    case grammar
    case plain
    /// Examples and their authors.
    case muted
    /// Spacers drawn in the page background colour on skarnik.by.
    case hidden

    var hexes: [String] {
        switch self {
        case .emphasis: return ["831b03", "0000a0", "4863a0"]
        case .grammar: return ["008000", "a52a2a", "cc33ff"]
        case .plain: return ["000000"]
        case .muted: return ["5f5f5f", "151b54"]
        case .hidden: return ["ffffff"]
        }
    }

    private static let byHex: [String: SKTranslationColorRole] = {
        var map: [String: SKTranslationColorRole] = [:]
        for role in allCases {
            for hex in role.hexes { map[hex] = role }
        }
        return map
    }()

    static func of(_ color: String) -> SKTranslationColorRole? {
        let hex = color.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .lowercased()
        return byHex[hex]
    }
}

enum SKTranslationRenderer {

    /// The Skarnik red, darker in light mode and lighter in dark mode with Increase Contrast.
    static let skarnikRed = UIColor { traits in
        let isDark = traits.userInterfaceStyle == .dark
        let isHighContrast = traits.accessibilityContrast == .high
        switch (isDark, isHighContrast) {
        case (false, false), (true, false): return UIColor(red: 0xF4 / 255, green: 0x4C / 255, blue: 0x3E / 255, alpha: 1)
        case (false, true): return UIColor(red: 0xC2 / 255, green: 0x1F / 255, blue: 0x14 / 255, alpha: 1)
        case (true, true): return UIColor(red: 0xFF / 255, green: 0x7A / 255, blue: 0x6E / 255, alpha: 1)
        }
    }

    /// Dynamic system colour for a role; resolved by the text view, so it follows dark mode and
    /// Increase Contrast without re-rendering.
    static func color(for role: SKTranslationColorRole, theme: SKArticleColorTheme) -> UIColor {
        switch role {
        case .emphasis: return theme == .skarnikRed ? skarnikRed : .label
        case .grammar: return .systemIndigo
        case .plain: return .label
        case .muted: return .secondaryLabel
        case .hidden: return .clear
        }
    }

    /// Relative links in the HTML (`/rusbel/123`) point at skarnik.by, which `handleUrl` routes.
    static let linkBaseURL = URL(string: "https://www.skarnik.by")!

    /// Trait collection for a content size and the Bold Text setting, for rendering off the main thread.
    static func traits(contentSize: UIContentSizeCategory, boldText: Bool = false) -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(preferredContentSizeCategory: contentSize),
            UITraitCollection(legibilityWeight: boldText ? .bold : .regular)
        ])
    }

    /// Converts translation HTML to styled text: colours by role, bold, italic, underline,
    /// superscript, line breaks, links and `data-word`. Fonts are the `textStyle` text style for
    /// `traits` (Dynamic Type, Bold Text); `nil` uses the current app settings. `<font size>` and CSS
    /// font sizes are ignored, so headwords match the body text. Thread-safe; no WebKit.
    static func render(html: String,
                       theme: SKArticleColorTheme = .current,
                       traits: UITraitCollection? = nil,
                       textStyle: UIFont.TextStyle = .body,
                       layout: SKTranslationLayout = .article) -> NSAttributedString {
        let builder = Builder(theme: theme, traits: traits, textStyle: textStyle)
        if let body = try? SwiftSoup.parseBodyFragment(html).body() {
            builder.appendChildren(of: body, style: Style())
        }
        return builder.finish(layout: layout)
    }

    /// `render(html:...)` on the concurrent pool, off the caller's actor. The result is a fresh
    /// value nothing else references, so it is handed back as `sending` (safe for any isolation).
    @concurrent
    static func renderAsync(html: String,
                            theme: SKArticleColorTheme = .current,
                            traits: UITraitCollection? = nil,
                            textStyle: UIFont.TextStyle = .body,
                            layout: SKTranslationLayout = .article) async -> sending NSAttributedString {
        render(html: html, theme: theme, traits: traits, textStyle: textStyle, layout: layout)
    }

    // MARK: - Builder

    fileprivate struct Style {
        enum Baseline { case normal, raised, lowered }

        var bold = false
        var italic = false
        var underline = false
        var color: UIColor?
        var scale: CGFloat = 1
        var baseline = Baseline.normal
        var link: URL?
        var dataWord: String?
    }

    private struct FontKey: Hashable {
        let bold: Bool
        let italic: Bool
        let scale: CGFloat
    }

    private final class Builder {
        private static let skippedTags: Set<String> = ["script", "style", "head", "title"]
        private static let blockTags: Set<String> = ["p", "div", "li", "ul", "ol", "table", "tr", "h1", "h2", "h3", "h4"]
        private static let nbsp: Character = "\u{00A0}"
        private static let spaces: Set<Character> = [" ", "\t", "\n", "\r", "\u{000C}", "\u{00A0}", "\r\n"]
        private static let cssColor = try? NSRegularExpression(pattern: "(?:^|;)\\s*color\\s*:\\s*(#?[0-9a-f]{3,6})\\b",
                                                               options: [.caseInsensitive])
        private static let cssBold = try? NSRegularExpression(pattern: "(?:^|;)\\s*font-weight\\s*:\\s*(bold|bolder|[6-9]00)\\b",
                                                              options: [.caseInsensitive])
        private static let cssItalic = try? NSRegularExpression(pattern: "(?:^|;)\\s*font-style\\s*:\\s*(italic|oblique)\\b",
                                                                options: [.caseInsensitive])
        private static let smallScale: CGFloat = 0.75
        private static let questionScale: CGFloat = 0.875

        private let theme: SKArticleColorTheme
        private let traits: UITraitCollection?
        private let textStyle: UIFont.TextStyle
        private let baseFont: UIFont
        private let result = NSMutableAttributedString()
        private var fonts: [FontKey: UIFont] = [:]
        private var lastChar: Character?
        /// True while the current line holds nothing or only non-breaking spaces (an indent).
        private var atLineStart = true

        init(theme: SKArticleColorTheme, traits: UITraitCollection?, textStyle: UIFont.TextStyle) {
            self.theme = theme
            self.traits = traits
            self.textStyle = textStyle
            self.baseFont = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        }

        func appendChildren(of element: Element, style: Style) {
            for node in element.getChildNodes() {
                if let text = node as? TextNode {
                    // getWholeText keeps &nbsp; as U+00A0; text() would turn it into a space.
                    appendText(text.getWholeText(), style: style)
                } else if let child = node as? Element {
                    appendElement(child, style: style)
                }
            }
        }

        private func appendElement(_ element: Element, style: Style) {
            let tag = element.tagName().lowercased()
            if Self.skippedTags.contains(tag) { return }
            if tag == "br" {
                breakLine(style: style)
                return
            }
            let childStyle = self.style(of: element, tag: tag, inherited: style)
            if Self.blockTags.contains(tag) {
                startLine(style: style)
                appendChildren(of: element, style: childStyle)
                startLine(style: style)
            } else {
                appendChildren(of: element, style: childStyle)
            }
        }

        private func style(of element: Element, tag: String, inherited: Style) -> Style {
            var style = inherited
            switch tag {
            case "b", "strong": style.bold = true
            case "i", "em": style.italic = true
            case "u": style.underline = true
            case "sup":
                style.baseline = .raised
                style.scale *= Self.smallScale
            case "sub":
                style.baseline = .lowered
                style.scale *= Self.smallScale
            case "a":
                let href = ((try? element.attr("href")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !href.isEmpty, let url = URL(string: href, relativeTo: SKTranslationRenderer.linkBaseURL) {
                    style.link = url.absoluteURL
                }
            default: break
            }

            let css = (try? element.attr("style")) ?? ""
            if !css.isEmpty {
                if Self.matches(Self.cssBold, css) != nil { style.bold = true }
                if Self.matches(Self.cssItalic, css) != nil { style.italic = true }
            }

            // Stress table classes (starnik.by and skarnik_admin), as in skarnik_android.
            if element.hasClass("pytanne") {
                style.italic = true
                style.color = SKTranslationRenderer.color(for: .muted, theme: theme)
                style.scale *= Self.questionScale
            }
            if element.hasClass("skarot") {
                style.italic = true
                style.bold = false
                style.color = SKTranslationRenderer.color(for: .grammar, theme: theme)
            }

            var rawColor = ((try? element.attr("color")) ?? "").trimmingCharacters(in: .whitespaces)
            if rawColor.isEmpty, let cssColor = Self.matches(Self.cssColor, css) {
                rawColor = cssColor
            }
            if !rawColor.isEmpty {
                let role = SKTranslationColorRole.of(rawColor) ?? .plain
                style.color = SKTranslationRenderer.color(for: role, theme: theme)
                // Primary-colour words need bold to stand out from body text; red ones keep the source weight.
                if role == .emphasis && theme == .system { style.bold = true }
            }

            let dataWord = ((try? element.attr("data-word")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !dataWord.isEmpty { style.dataWord = dataWord }
            return style
        }

        /// HTML whitespace. At the start of a line only `&nbsp;` is kept: the source indents with it.
        /// Inside a line any run of spaces and `&nbsp;` (also across tags) becomes one gap: a lone
        /// `&nbsp;` stays non-breaking, a longer run becomes one space, so «— &nbsp;слова» doesn't
        /// leave a wide hole.
        private func appendText(_ text: String, style: Style) {
            var token = ""
            var tokenIsSpace = false
            func flush() {
                guard !token.isEmpty else { return }
                if !tokenIsSpace {
                    append(token, style: style)
                } else if atLineStart {
                    append(String(token.filter { $0 == Self.nbsp }), style: style)
                } else if lastChar == " " || lastChar == Self.nbsp {
                    // Already have a gap.
                } else if token == String(Self.nbsp) {
                    append(token, style: style)
                } else {
                    append(" ", style: style)
                }
                token = ""
            }
            for char in text {
                let isSpace = Self.spaces.contains(char)
                if isSpace != tokenIsSpace { flush() }
                tokenIsSpace = isSpace
                token.append(char)
            }
            flush()
        }

        private func startLine(style: Style) {
            if let lastChar, lastChar != "\n" { breakLine(style: style) }
        }

        /// A line break; drops the regular space a line would otherwise end with
        /// («род \n» from pretty-printed HTML).
        private func breakLine(style: Style) {
            while result.length > 0, (result.string as NSString).character(at: result.length - 1) == 0x20 {
                result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
            }
            append("\n", style: style)
        }

        private func append(_ text: String, style: Style) {
            guard let last = text.last else { return }
            result.append(NSAttributedString(string: text, attributes: attributes(for: style)))
            lastChar = last
            for char in text {
                if char == "\n" {
                    atLineStart = true
                } else if char != Self.nbsp {
                    atLineStart = false
                }
            }
        }

        private func attributes(for style: Style) -> [NSAttributedString.Key: Any] {
            let font = self.font(bold: style.bold, italic: style.italic, scale: style.scale)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.color ?? UIColor.label
            ]
            if style.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            switch style.baseline {
            case .normal: break
            case .raised: attributes[.baselineOffset] = baseFont.pointSize * 0.35
            case .lowered: attributes[.baselineOffset] = -baseFont.pointSize * 0.15
            }
            if let link = style.link { attributes[.link] = link }
            if let dataWord = style.dataWord { attributes[.skDataWord] = dataWord }
            return attributes
        }

        private func font(bold: Bool, italic: Bool, scale: CGFloat) -> UIFont {
            let key = FontKey(bold: bold, italic: italic, scale: scale)
            if let font = fonts[key] { return font }
            var symbolicTraits = baseFont.fontDescriptor.symbolicTraits
            if bold { symbolicTraits.insert(.traitBold) }
            if italic { symbolicTraits.insert(.traitItalic) }
            let descriptor = baseFont.fontDescriptor.withSymbolicTraits(symbolicTraits) ?? baseFont.fontDescriptor
            let font = UIFont(descriptor: descriptor, size: baseFont.pointSize * scale)
            fonts[key] = font
            return font
        }

        func finish(layout: SKTranslationLayout) -> NSAttributedString {
            // Drop trailing whitespace and line breaks.
            let string = result.string as NSString
            let lastVisible = string.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted,
                                                      options: .backwards)
            if lastVisible.location == NSNotFound {
                result.deleteCharacters(in: NSRange(location: 0, length: result.length))
            } else {
                let end = NSMaxRange(lastVisible)
                result.deleteCharacters(in: NSRange(location: end, length: result.length - end))
            }
            guard result.length > 0 else { return NSAttributedString() }

            let metrics = UIFontMetrics(forTextStyle: textStyle)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            switch layout {
            case .article:
                paragraph.lineHeightMultiple = 1.15
                paragraph.paragraphSpacing = metrics.scaledValue(for: 8, compatibleWith: traits)
            case .compact:
                break
            }
            result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
            return result
        }

        private static func matches(_ regex: NSRegularExpression?, _ string: String) -> String? {
            guard let regex,
                  let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: (string as NSString).length)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: string) else { return nil }
            return String(string[range])
        }
    }
}
