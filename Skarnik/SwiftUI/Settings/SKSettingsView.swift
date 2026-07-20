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

    var onAboutTapped: (() -> Void)?

    private static let dictionaries = SKOfflineDictionaryDownloadManager.downloadableDictionaries

    var body: some View {
        List {
            Section {
                ForEach(Self.dictionaries, id: \.rawValue) { dictionary in
                    row(for: dictionary)
                }
            } header: {
                Text(SKLocalization.offlineSectionTitle)
            }

            Section {
                rateAppRow
                aboutRow
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

    private var rateAppRow: some View {
        HStack {
            Text(SKLocalization.rateAppRowTitle)
                .font(.system(size: 16, weight: .medium))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let url = URL(string: SKLocalization.rateAppURLString) else { return }
            UIApplication.shared.open(url)
        }
        .padding(.vertical, 4)
    }

    private var aboutRow: some View {
        HStack {
            Text(SKLocalization.aboutRowTitle)
                .font(.system(size: 16, weight: .medium))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onAboutTapped?()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func row(for dictionary: ESKVocabularyType) -> some View {
        let state = manager.states[dictionary] ?? .notDownloaded

        HStack(alignment: .top, spacing: 12) {
            leadingIcon(for: state)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(shortName(for: dictionary))
                    .font(.system(size: 16, weight: .medium))

                subtitle(for: state)

                if case .downloading(let done, let total) = state {
                    ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                    Text(SKLocalization.offlineProgressLabel(done: done, total: total))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }

            Spacer()

            if case .downloaded = state {
                Button {
                    dictionaryPendingDelete = dictionary
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch state {
            case .notDownloaded, .failed:
                manager.startDownload(dictionary)
            case .downloading, .downloaded:
                break
            }
        }
        .padding(.vertical, 4)
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
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.secondaryLabel))
        case .failed:
            Text(SKLocalization.offlineFailedSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.red)
        case .downloading:
            Text(SKLocalization.offlineDownloadingSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.secondaryLabel))
        case .downloaded(let count):
            Text(SKLocalization.offlineDownloadedSubtitle(count: count))
                .font(.system(size: 13))
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
        rootView.onAboutTapped = { [weak self] in
            self?.navigationController?.pushViewController(SKAboutViewController(), animated: true)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: SKSettingsView())
        rootView.onAboutTapped = { [weak self] in
            self?.navigationController?.pushViewController(SKAboutViewController(), animated: true)
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
    NavigationView {
        SKSettingsView()
    }
}
#endif
