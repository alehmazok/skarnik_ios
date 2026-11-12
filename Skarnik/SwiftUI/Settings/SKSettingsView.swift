//
//  SKSettingsView.swift
//  Skarnik
//

import UIKit
import SwiftUI
import Combine

struct SKSettingsView: View {
    @ObservedObject var manager = SKOfflineDictionaryDownloadManager.shared

    @State private var dictionaryPendingDelete: ESKVocabularyType?
    @State private var showRateLimitAlert = false
    @AppStorage(SKArticleColorTheme.userDefaultsKey) private var articleColorTheme = SKArticleColorTheme.system.rawValue
    /// Mirrors the consent controller, which is not observable, so the toggle redraws when flipped.
    @State private var analyticsGranted = SKAnalyticsConsentController.shared.analyticsConsentGranted
    @AppStorage(SKSearchBarPlacement.userDefaultsKey) private var searchBarAtBottom = true

    var onAboutTapped: (() -> Void)?
    var onWhatsNewTapped: (() -> Void)?

    private static let dictionaries = SKOfflineDictionaryDownloadManager.downloadableDictionaries

    var body: some View {
        List {
            Section {
                ForEach(Self.dictionaries, id: \.rawValue) { dictionary in
                    row(for: dictionary)
                }
            } header: {
                Text(SKLocalization.offlineSectionTitle)
            } footer: {
                Text(SKLocalization.offlineSectionFooter)
            }

            Section {
                if SKSearchBarPlacement.isBottomAvailable {
                    Toggle(SKLocalization.searchBarAtBottomRowTitle, isOn: Binding(
                        get: { searchBarAtBottom },
                        set: { atBottom in
                            searchBarAtBottom = atBottom
                            NotificationCenter.default.post(name: .skSearchBarPlacementChanged, object: nil)
                            SKAnalyticsManager.reportSearchBarPlacement()
                        }
                    ))
                    .accessibilityIdentifier("settings.searchBarAtBottom")
                }

                Picker(SKLocalization.articleColorsTitle, selection: $articleColorTheme) {
                    Text(SKLocalization.articleColorsSystem).tag(SKArticleColorTheme.system.rawValue)
                    Text(SKLocalization.articleColorsSkarnikRed).tag(SKArticleColorTheme.skarnikRed.rawValue)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.articleColors")
            } header: {
                Text(SKLocalization.settingsAppearanceSectionTitle)
            } footer: {
                Text(SKLocalization.articleColorsFooter)
            }

            Section {
                Toggle(SKLocalization.analyticsConsentSettingsRowTitle, isOn: Binding(
                    get: { analyticsGranted },
                    set: { isGranted in
                        analyticsGranted = isGranted
                        if isGranted {
                            SKAnalyticsConsentController.shared.grantConsent()
                        } else {
                            SKAnalyticsConsentController.shared.revokeConsent()
                        }
                    }
                ))
                .accessibilityIdentifier("settings.analytics")

                externalLinkRow(SKLocalization.privacyPolicyRowTitle,
                                urlString: SKLocalization.privacyPolicyURLString,
                                identifier: "settings.privacyPolicy")
            } header: {
                Text(SKLocalization.settingsPrivacySectionTitle)
            } footer: {
                Text(SKLocalization.analyticsSettingsFooter)
            }

            Section {
                navigationRow(SKLocalization.whatsNewRowTitle, identifier: "settings.whatsNew") {
                    onWhatsNewTapped?()
                }
                navigationRow(SKLocalization.aboutRowTitle, identifier: "settings.about") {
                    onAboutTapped?()
                }
                externalLinkRow(SKLocalization.rateAppRowTitle,
                                urlString: SKLocalization.rateAppURLString,
                                identifier: "settings.rateApp")
            } header: {
                Text(SKLocalization.settingsAboutSectionTitle)
            } footer: {
                if let version = SKAboutView.versionString {
                    Text(version)
                        .accessibilityIdentifier("settings.version")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground.ignoresSafeArea())
        .task { await manager.refreshDownloadedCounts() }
        .onReceive(manager.effectSubject) { effect in
            switch effect {
            case .rateLimited:
                showRateLimitAlert = true
            }
        }
        .alert(SKLocalization.offlineRateLimitMessage, isPresented: $showRateLimitAlert) {
            Button(SKLocalization.aboutDone, role: .cancel) {}
        }
        .alert(
            SKLocalization.offlineDeleteConfirmTitle,
            isPresented: Binding(
                get: { dictionaryPendingDelete != nil },
                set: { isPresented in if !isPresented { dictionaryPendingDelete = nil } }
            )
        ) {
            Button(SKLocalization.offlineDeleteConfirmCancel, role: .cancel) { dictionaryPendingDelete = nil }
            Button(SKLocalization.offlineDeleteConfirmConfirm, role: .destructive) {
                if let dictionary = dictionaryPendingDelete {
                    Task { await manager.delete(dictionary) }
                }
                dictionaryPendingDelete = nil
            }
        } message: {
            if let dictionary = dictionaryPendingDelete {
                Text(SKLocalization.offlineDeleteConfirmMessage(dictName: shortName(for: dictionary)))
            }
        }
    }

    /// Pushes a screen inside the sheet: a system-style chevron, highlight and button trait.
    private func navigationRow(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Color(UIColor.label))
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    /// Leaves the app (Safari, App Store): an outward arrow instead of a chevron.
    @ViewBuilder
    private func externalLinkRow(_ title: String, urlString: String, identifier: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack {
                    Text(title)
                        .foregroundStyle(Color(UIColor.label))
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private func row(for dictionary: ESKVocabularyType) -> some View {
        let state = manager.states[dictionary] ?? .notDownloaded
        let id = dictionary.skarnikId ?? ""

        HStack(alignment: .center, spacing: 12) {
            leadingIcon(for: state)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(shortName(for: dictionary))
                    .accessibilityIdentifier("settings.offline.\(id).name")

                subtitle(for: state)
                    .accessibilityIdentifier("settings.offline.\(id).status")

                if case .downloading(let done, let total) = state {
                    ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                    Text(SKLocalization.offlineProgressLabel(done: done, total: total))
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }

            Spacer()

            switch state {
            case .notDownloaded, .failed:
                Button(SKLocalization.offlineDownloadButtonTitle) {
                    manager.startDownload(dictionary)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .accessibilityIdentifier("settings.offline.\(id).download")
            case .downloading:
                EmptyView()
            case .downloaded:
                Button(role: .destructive) {
                    dictionaryPendingDelete = dictionary
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(SKLocalization.offlineDeleteButtonTitle)
                .accessibilityIdentifier("settings.offline.\(id).delete")
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if case .downloaded = state {
                Button(SKLocalization.offlineDeleteButtonTitle, role: .destructive) {
                    dictionaryPendingDelete = dictionary
                }
            }
        }
        .contextMenu {
            if case .downloaded = state {
                Button(SKLocalization.offlineDeleteButtonTitle, systemImage: "trash", role: .destructive) {
                    dictionaryPendingDelete = dictionary
                }
            }
        }
    }

    @ViewBuilder
    private func leadingIcon(for state: SKOfflineDictionaryState) -> some View {
        switch state {
        case .notDownloaded, .failed:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.accentColor)
        case .downloading:
            ProgressView()
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private func subtitle(for state: SKOfflineDictionaryState) -> some View {
        switch state {
        case .notDownloaded:
            Text(SKLocalization.offlineNotDownloadedSubtitle)
                .font(.footnote)
                .foregroundStyle(Color(UIColor.secondaryLabel))
        case .failed:
            Text(SKLocalization.offlineFailedSubtitle)
                .font(.footnote)
                .foregroundStyle(.red)
        case .downloading:
            Text(SKLocalization.offlineDownloadingSubtitle)
                .font(.footnote)
                .foregroundStyle(Color(UIColor.secondaryLabel))
        case .downloaded(let count):
            Text(SKLocalization.offlineDownloadedSubtitle(count: count))
                .font(.footnote)
                .foregroundStyle(Color(UIColor.secondaryLabel))
        }
    }

    private func shortName(for dictionary: ESKVocabularyType) -> String {
        switch dictionary {
        case .rus_bel: return SKLocalization.segmentRusBel
        case .bel_rus: return SKLocalization.segmentBelRus
        case .bel_definition: return SKLocalization.segmentDefinition
        default: return dictionary.name ?? ""
        }
    }
}

// MARK: - UIKit host

class SKSettingsViewController: UIHostingController<SKSettingsView> {

    init() {
        super.init(rootView: SKSettingsView())
        wireRows()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: SKSettingsView())
        wireRows()
    }

    private func wireRows() {
        rootView.onAboutTapped = { [weak self] in
            self?.navigationController?.pushViewController(SKAboutViewController(), animated: true)
        }
        rootView.onWhatsNewTapped = { [weak self] in
            self?.navigationController?.pushViewController(SKWhatsNewHistoryViewController(), animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = SKLocalization.tabSettings
        navigationItem.largeTitleDisplayMode = .never
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SKSettingsView()
    }
}
#endif
