//
//  SKWordDetailsView.swift
//  Skarnik
//

import SwiftUI
import TipKit
import UIKit
import Combine

// MARK: - Word link hint

/// The one-time hint about tappable Belarusian words (Aleh, 2026-11-16): shown once per install, on the
/// first translation that has such words, which are underlined while it shows. Same as skarnik_android.
struct SKWordLinkTip: Tip {
    static let doneActionId = "done"

    var title: Text { Text(SKLocalization.wordLinkHint) }

    var actions: [Action] {
        [Action(id: Self.doneActionId, title: SKLocalization.wordLinkHintDone)]
    }

    var options: [any TipOption] { [MaxDisplayCount(1)] }
}

// MARK: - UITextView representable

struct SKAttributedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString?
    let onLinkTap: (URL) -> Void
    var onWordLinkTap: (URL, String) -> Void = { _, _ in }
    /// Underlines the linked words (`.skWordLink`) while the word link hint shows.
    var underlinesWordLinks = false

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap, onWordLinkTap: onWordLinkTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.dataDetectorTypes = .link
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 17)
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.accessibilityIdentifier = "wordDetails.translation"
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onLinkTap = onLinkTap
        context.coordinator.onWordLinkTap = onWordLinkTap
        uiView.attributedText = underlinesWordLinks ? attributedText.map(Self.underliningWordLinks) : attributedText
        uiView.invalidateIntrinsicContentSize()
    }

    static func underliningWordLinks(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        text.enumerateAttribute(.skWordLink, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard value != nil else { return }
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        return result
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.frame.width
        guard width > 0 else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: (URL) -> Void
        var onWordLinkTap: (URL, String) -> Void

        init(onLinkTap: @escaping (URL) -> Void, onWordLinkTap: @escaping (URL, String) -> Void) {
            self.onLinkTap = onLinkTap
            self.onWordLinkTap = onWordLinkTap
        }

        /// A tap on a link or a linked Belarusian word opens it in the app; a tap on an abbreviation
        /// shows its full text.
        func textView(_ textView: UITextView,
                      primaryActionFor textItem: UITextItem,
                      defaultAction: UIAction) -> UIAction? {
            switch textItem.content {
            case .link(let url):
                return UIAction { [weak self] _ in self?.onLinkTap(url) }
            case .tag(let tag) where tag.hasPrefix(SKTranslationRenderer.wordLinkTagPrefix):
                let range = textItem.range
                guard let text = textView.attributedText, NSMaxRange(range) <= text.length,
                      let url = text.attribute(.skWordLink, at: range.location, effectiveRange: nil) as? URL else {
                    return nil
                }
                let word = (text.string as NSString).substring(with: range)
                return UIAction { [weak self] _ in self?.onWordLinkTap(url, word) }
            case .tag:
                let range = textItem.range
                return UIAction { [weak textView] _ in
                    guard let textView else { return }
                    SKAbbreviationPopover.present(for: range, in: textView)
                }
            default:
                return defaultAction
            }
        }

        /// No long-press menu on links and abbreviations: links stay inside the app, as before.
        func textView(_ textView: UITextView,
                      menuConfigurationFor textItem: UITextItem,
                      defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            switch textItem.content {
            case .link, .tag: return nil
            default: return UITextItem.MenuConfiguration(menu: defaultMenu)
            }
        }
    }
}

// MARK: - Translation content view (handles async attributed string loading)

private struct SKWordDetailsTranslationView: View {
    let translation: SKSkarnikTranslation
    let onLinkTap: (URL) -> Void
    var onWordLinkTap: (URL, String) -> Void = { _, _ in }
    // Colours are dynamic (dark mode, Increase Contrast resolve in the text view); fonts are not,
    // so the text is rebuilt when Dynamic Type or Bold Text changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @AppStorage(SKArticleColorTheme.userDefaultsKey) private var articleColorTheme = SKArticleColorTheme.system.rawValue
    @State private var attributedText: NSAttributedString?
    @State private var hasWordLinks = false
    @State private var hintVisible = false
    @State private var hintShownLogged = false
    private let wordLinkTip = SKWordLinkTip()

    var body: some View {
        SKAttributedTextView(
            attributedText: attributedText,
            onLinkTap: onLinkTap,
            onWordLinkTap: { url, word in
                if hintVisible {
                    hintVisible = false
                    SKAnalyticsManager.logWordLinkHintDismissed(byTap: true)
                }
                wordLinkTip.invalidate(reason: .actionPerformed)
                onWordLinkTap(url, word)
            },
            underlinesWordLinks: hintVisible
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            // The tip points at the top of the text, where the first linked word usually is.
            .overlay(alignment: .top) {
                if hasWordLinks {
                    Color.clear
                        .frame(height: 1)
                        .popoverTip(wordLinkTip, arrowEdge: .bottom) { action in
                            if action.id == SKWordLinkTip.doneActionId {
                                wordLinkTip.invalidate(reason: .tipClosed)
                            }
                        }
                }
            }
            .task(id: hasWordLinks) {
                guard hasWordLinks else { return }
                for await status in wordLinkTip.statusUpdates {
                    let available: Bool
                    if case .available = status { available = true } else { available = false }
                    if available, !hintShownLogged {
                        hintShownLogged = true
                        SKAnalyticsManager.logWordLinkHintShown()
                    } else if !available, hintVisible {
                        SKAnalyticsManager.logWordLinkHintDismissed(byTap: false)
                    }
                    hintVisible = available
                }
            }
            .onDisappear { hintVisible = false }
            .overlay(alignment: .topTrailing) {
                if SKUITesting.isActive {
                    // Lets UI tests check which source answered (local, supabase, api).
                    Text(translation.sourceName)
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .accessibilityIdentifier("wordDetails.source")
                }
            }
            .task(id: "\(translation.url)-\(dynamicTypeSize)-\(legibilityWeight == .bold)-\(articleColorTheme)") {
                let theme = SKArticleColorTheme(rawValue: articleColorTheme) ?? .system
                let traits = SKTranslationRenderer.traits(contentSize: UIContentSizeCategory(dynamicTypeSize),
                                                          boldText: legibilityWeight == .bold)
                let text = await translation.renderedText(theme: theme, traits: traits)
                guard !Task.isCancelled else { return }
                attributedText = text
                hasWordLinks = Self.hasWordLinks(text)
            }
    }
}

extension SKWordDetailsTranslationView {
    static func hasWordLinks(_ text: NSAttributedString) -> Bool {
        var found = false
        text.enumerateAttribute(.skWordLink, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

// MARK: - Header scroll tracking

/// Bottom edge of the word header in the scroll view's coordinate space. Negative once the
/// header has scrolled under the navigation bar.
private struct SKHeaderBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - Main view

struct SKWordDetailsView: View {
    @ObservedObject var viewModel: SKWordDetailsViewModel
    var onSpellingWord: (String) -> Void = { _ in }
    var onReport: () -> Void = {}

    @State private var toastMessage: String?
    /// True once the large headword has scrolled out of view; only then does the nav bar show it.
    @State private var isHeaderScrolledAway = false

    private static let scrollSpace = "SKWordDetailsScroll"

    var body: some View {
        ZStack {
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        contentView
                    }
                    .padding(.horizontal, 15)
                    // At least a screen tall, so the loading and error states can centre in the
                    // space under the header; a long translation still scrolls as before.
                    .frame(minHeight: viewport.size.height, alignment: .top)
                }
            }
            .coordinateSpace(name: Self.scrollSpace)
            .onPreferenceChange(SKHeaderBottomPreferenceKey.self) { bottom in
                let scrolledAway = bottom <= 0
                guard scrolledAway != isHeaderScrolledAway else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHeaderScrolledAway = scrolledAway
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("wordDetails")

            if let message = toastMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.tertiarySystemBackground))
                                .shadow(color: .black.opacity(0.2), radius: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                        .padding(.bottom, 24)
                        .transition(.opacity)
                        .accessibilityIdentifier("wordDetails.toast")
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(isHeaderScrolledAway ? (viewModel.navigationTitle ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if case .loading = viewModel.state {
                    // Reserve the slot while the translation loads so the bar doesn't shift.
                    spellingPlaceholder
                } else if !viewModel.spellingWords.isEmpty {
                    spellingControl
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                // Share on the left, Bookmark on the right: balanced on iOS 26 glass and older bars.
                shareButton
                Spacer()
                Button(action: {
                    viewModel.toggleFavorite()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: viewModel.isFavorite ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(viewModel.isFavorite
                                    ? SKLocalization.wordDetailsRemoveBookmark
                                    : SKLocalization.wordDetailsAddBookmark)
                .accessibilityIdentifier("wordDetails.bookmark")
                .disabled(viewModel.word == nil)
                // TODO: re-enable report button when ready (between Share and Bookmark)
            }
        }
        .onReceive(viewModel.effectSubject) { effect in
            handleEffect(effect)
        }
    }

    // MARK: Share

    /// Shares «word — link»: the word (stressed form when known) as text and subject, so a plain
    /// chat shows what the link is about and Mail gets a subject; the link keeps its preview.
    /// `ShareLink`, which SwiftUI shows as a popover from the button on iPad.
    @ViewBuilder
    private var shareButton: some View {
        let icon = Image(systemName: "square.and.arrow.up")
        if let translation = viewModel.translation, let url = URL(string: translation.sharingUrl) {
            let title = translation.shareTitle
            ShareLink(item: url,
                      subject: Text(title),
                      message: Text(title)) {
                icon
            }
            // ShareLink has no action callback; a simultaneous tap still reports the click.
            .simultaneousGesture(TapGesture().onEnded {
                logShareClicked(translation)
            })
            .accessibilityLabel(SKLocalization.wordDetailsShare)
            .accessibilityIdentifier("wordDetails.share")
        } else {
            // Same slot, disabled until the translation (and so the link) is there.
            Button(action: {}) { icon }
                .accessibilityLabel(SKLocalization.wordDetailsShare)
                .accessibilityIdentifier("wordDetails.share")
                .disabled(true)
        }
    }

    private func logShareClicked(_ translation: SKSkarnikTranslation) {
        SKAnalyticsManager.logShareClicked(word: translation.word, url: translation.sharingUrl)
    }

    // MARK: Header

    /// Large headword (stressed form when known) with the dictionary name under it. Both come
    /// from the word itself, so they are ready before the translation loads; the stress form only
    /// adds a combining accent, which keeps the line metrics and avoids a jump when it arrives.
    /// With no word (empty iPad detail pane) the header is hidden instead of holding placeholder text.
    @ViewBuilder
    private var header: some View {
        if let headword = viewModel.headword {
            VStack(alignment: .leading, spacing: 4) {
                Text(headword)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("wordDetails.headword")
                if let subtitle = viewModel.vocabularySubtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("wordDetails.subtitle")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SKHeaderBottomPreferenceKey.self,
                        value: proxy.frame(in: .named(Self.scrollSpace)).maxY
                    )
                }
            )
        }
    }

    // MARK: Content

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("wordDetailsLoading")
        case .success(let translation):
            SKWordDetailsTranslationView(
                translation: translation,
                onLinkTap: { url in viewModel.handleUrl(url.absoluteString) },
                onWordLinkTap: { url, word in viewModel.openWordLink(url, text: word) }
            )
        case .error(let message):
            errorView(message: message)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("wordDetailsError")
        }
    }

    /// Centred message with a retry button.
    private func errorView(message: String) -> some View {
        let retryButton = Button(SKLocalization.wordDetailsRetry) { viewModel.retry() }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("wordDetailsRetry")
        return ContentUnavailableView {
            Label(message, systemImage: "exclamationmark.triangle")
        } actions: {
            retryButton
        }
    }

    // MARK: Spelling toolbar control

    @ViewBuilder
    private var spellingControl: some View {
        let words = viewModel.spellingWords
        if words.count == 1 {
            Button(action: { onSpellingWord(words[0]) }) {
                Text(SKLocalization.wordDetailsSpelling)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityIdentifier("wordDetails.stress")
        } else {
            Menu {
                ForEach(words, id: \.self) { word in
                    Button(word) { onSpellingWord(word) }
                }
            } label: {
                Text(SKLocalization.wordDetailsSpelling)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityIdentifier("wordDetails.stress")
        }
    }

    private var spellingPlaceholder: some View {
        Button(action: {}) {
            Text(SKLocalization.wordDetailsSpelling)
        }
        .disabled(true)
    }

    // MARK: Helpers

    private func handleEffect(_ effect: SKWordDetailsEffect) {
        switch effect {
        case .redirection(let originalWord):
            showToast("Перанакіравана з «\(originalWord)»")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastMessage = nil }
        }
    }
}

// MARK: - Previews

#if DEBUG
private struct MockTranslationSource: SKTranslationSource {
    let translation: SKSkarnikTranslation?

    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        translation
    }
}

private struct ErrorTranslationSource: SKTranslationSource {
    func wordTranslation(_ word: SKWord) async throws -> SKSkarnikTranslation? {
        throw SKSkarnikError.networkError
    }
}

private let previewWord = SKWord(word_id: 1, word: "слова", lang_id: .bel_definition)

/// Sample translation HTML for previews and SKTranslationRendererTests (ТСБМ «кара»).
enum SKTranslationSamples {
    static let tsbmKara = """
    <p>
     <strong>
      <span style="color: #0000a0;">
       ка́ра,
      </span>
     </strong>
     <span style="color: #a52a2a;">
      -ы, жаночы род
     </span>
     <br/>
     Суровае пакаранне, спагнанне за правіннасць.
     <span style="color: #5f5f5f;">
      Панесці кару. Адбываць кару. ▪ У заключэнне пракурор патрабаваў вышэйшай меры кары, што азначана ў артыкулах, па якіх адбываўся суд.
     </span>
     <em>
      <span style="color: #151b54;">
       Колас.
      </span>
     </em>
     <span style="color: #5f5f5f;">
      Ні бацькі, ні дзяўчат гестапаўцам злавіць не ўдалося: іх папярэдзілі сувязныя. Увесь цяжар кары лёг на кволыя матчыны плечы.
     </span>
     <em>
      <span style="color: #151b54;">
       Брыль.
      </span>
     </em>
     <br/>
     <strong>
      <span style="color: #0000a0;">
       кара́,
      </span>
     </strong>
     <span style="color: #a52a2a;">
      -ы́, жаночы род
     </span>
     <br/>
     <strong>
      1.
     </strong>
     Паверхневая частка ствала, галін і кораня дрэвавых раслін, якая звычайна лёгка аддзяляецца.
     <span style="color: #5f5f5f;">
      Лазовая кара. Здымаць кару. ▪ Сонца заходзіла, распырскваючы чырвона-медзяныя пырскі па траве, па белай кары маладых бярозак.
     </span>
     <em>
      <span style="color: #151b54;">
       Мурашка.
      </span>
     </em>
     <span style="color: #5f5f5f;">
      Доўгімі і вострымі кіпцюрамі мядзведзіца здзірала кару з дрэў.
     </span>
     <em>
      <span style="color: #151b54;">
       В. Вольскі.
      </span>
     </em>
     <br/>
     <strong>
      2.
     </strong>
     чаго або якая. Верхні цвёрды слой на чым-н.
     <span style="color: #5f5f5f;">
      У лагчынах блішчэлі ахопленыя ледзяной карой лужыны.
     </span>
     <em>
      <span style="color: #151b54;">
       Бядуля.
      </span>
     </em>
     <span style="color: #5f5f5f;">
      Конь цвёрда ступаў, прабіваючы слабую кару гразі.
     </span>
     <em>
      <span style="color: #151b54;">
       Гартны.
      </span>
     </em>
     <span style="color: #cc33ff;">
      <strong>
       //
      </strong>
     </span>
     пераноснае значэнне; чаго. Аб чым-н. знешнім, паверхневым, за якім хаваецца якая-н. сутнасць.
     <span style="color: #5f5f5f;">
      Дрымота і здранцвеласць цела туманіла нам галовы і зацягвала сэрца карою абыякавасці.
     </span>
     <em>
      <span style="color: #151b54;">
       Чорны.
      </span>
     </em>
     <br/>
     •••
     <br/>
     <strong>
      <span style="color: #5f5f5f;">
       <span style="color: #4863a0;">
        Зямная кара
       </span>
      </span>
     </strong>
     — верхняя цвёрдая абалонка Зямлі.
     <br/>
     <strong>
      <span style="color: #5f5f5f;">
       <span style="color: #4863a0;">
        Кара вялікіх паўшар'яў галаўнога мозгу
       </span>
      </span>
     </strong>
     ;
     <strong>
      <span style="color: #5f5f5f;">
       <span style="color: #4863a0;">
        кара галаўнога мозгу
       </span>
      </span>
     </strong>
     — паверхневы слой галаўнога мозгу ў вышэйшых пазваночных жывёл і чалавека.
     <br/>
     <strong>
      <span style="color: #5f5f5f;">
       <span style="color: #4863a0;">
        Абрасці карою
       </span>
      </span>
     </strong>
     глядзі абрасці.
    </p>
    """
}

private let previewTranslation = SKSkarnikTranslation(
    word: previewWord,
    url: "https://skarnik.app/r/rusbel/1",
    html: SKTranslationSamples.tsbmKara,
//    stress: "сло́ва",
    stress: "добразычлівасць",
    sourceName: "mock"
)
#Preview("Loading") {
    NavigationStack {
        SKWordDetailsView(viewModel: SKWordDetailsViewModel())
    }
}

#Preview("Success") {
    let vm = SKWordDetailsViewModel(
        translationSource: MockTranslationSource(translation: previewTranslation)
    )
    return NavigationStack {
        SKWordDetailsView(viewModel: vm)
            .onAppear { vm.updateWord(previewWord) }
    }
}

#Preview("Error") {
    let vm = SKWordDetailsViewModel(translationSource: ErrorTranslationSource())
    return NavigationStack {
        SKWordDetailsView(viewModel: vm)
            .onAppear { vm.updateWord(previewWord) }
    }
}
#endif

// MARK: - Abbreviation popover

/// The full text of a tapped abbreviation («разг.» → «разговорное слово, выражение») in a small popover
/// with an arrow at the abbreviation, also on iPhone. A tap outside closes it.
enum SKAbbreviationPopover {
    private static let maxWidth: CGFloat = 300

    @MainActor
    static func present(for range: NSRange, in textView: UITextView) {
        guard let text = textView.attributedText, range.length > 0, NSMaxRange(range) <= text.length,
              let expansion = text.attribute(.skAbbreviation, at: range.location, effectiveRange: nil) as? String,
              let presenter = textView.skNearestViewController else { return }
        let abbreviation = (text.string as NSString).substring(with: range)

        let controller = SKAbbreviationPopoverController(
            rootView: SKAbbreviationPopoverView(abbreviation: abbreviation, expansion: expansion)
        )
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = controller.sizeThatFits(
            in: CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        )
        if let popover = controller.popoverPresentationController {
            popover.sourceView = textView
            popover.sourceRect = rect(of: range, in: textView)
            popover.permittedArrowDirections = [.down, .up]
            popover.delegate = controller
        }
        if presenter.presentedViewController is SKAbbreviationPopoverController {
            presenter.dismiss(animated: false) { presenter.present(controller, animated: true) }
        } else {
            presenter.present(controller, animated: true)
        }
    }

    /// The abbreviation's rect on its first line, in the text view's coordinates.
    @MainActor
    private static func rect(of range: NSRange, in textView: UITextView) -> CGRect {
        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end) else {
            return CGRect(origin: .zero, size: textView.bounds.size)
        }
        return textView.firstRect(for: textRange)
    }
}

final class SKAbbreviationPopoverController: UIHostingController<SKAbbreviationPopoverView>,
                                             UIPopoverPresentationControllerDelegate {
    /// A popover on iPhone too, instead of a sheet.
    func adaptivePresentationStyle(for controller: UIPresentationController,
                                   traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }
}

struct SKAbbreviationPopoverView: View {
    let abbreviation: String
    let expansion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(abbreviation)
                .font(.headline)
                .accessibilityIdentifier("wordDetails.abbreviation.title")
            Text(expansion)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("wordDetails.abbreviation.text")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private extension UIResponder {
    var skNearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
