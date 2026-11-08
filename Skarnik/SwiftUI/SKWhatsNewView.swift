//
//  SKWhatsNewView.swift
//  Skarnik
//
//  The post-update sheet and the Settings list of release notes. Content comes from
//  SKWhatsNewCatalog; when to show the sheet is decided by SKWhatsNewController.
//

import UIKit
import SwiftUI

/// One feature: system icon, bold title, a short sentence. Shared by the sheet and the list.
struct SKWhatsNewItemRow: View {
    let item: SKWhatsNewItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.symbol)
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text(item.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Apple-style "What's New" sheet: large title, a few feature rows, one button pinned at the bottom.
struct SKWhatsNewView: View {
    let release: SKWhatsNewRelease
    var onContinue: () -> Void = {}

    private static let contentMaxWidth: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text(SKLocalization.whatsNewTitle)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(SKLocalization.whatsNewVersion(release.version))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(release.items) { item in
                            SKWhatsNewItemRow(item: item)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: Self.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }

            Button(action: onContinue) {
                Text(SKLocalization.whatsNewContinue)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("whatsNew.continue")
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .frame(maxWidth: Self.contentMaxWidth)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .accessibilityIdentifier("whatsNew")
    }
}

/// Settings → «Што новага»: every release with notes, newest first.
struct SKWhatsNewHistoryView: View {
    let releases: [SKWhatsNewRelease]

    var body: some View {
        List {
            ForEach(releases) { release in
                Section {
                    ForEach(release.items) { item in
                        SKWhatsNewItemRow(item: item)
                            .padding(.vertical, 6)
                    }
                } header: {
                    Text(SKLocalization.whatsNewVersion(release.version))
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground.ignoresSafeArea())
        .accessibilityIdentifier("whatsNewHistory")
    }
}

// MARK: - UIKit hosts

final class SKWhatsNewViewController: UIHostingController<SKWhatsNewView> {

    init(release: SKWhatsNewRelease) {
        super.init(rootView: SKWhatsNewView(release: release))
        rootView.onContinue = { [weak self] in
            self?.dismiss(animated: true)
        }
        modalPresentationStyle = .formSheet
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

final class SKWhatsNewHistoryViewController: UIHostingController<SKWhatsNewHistoryView> {

    init(releases: [SKWhatsNewRelease] = SKWhatsNewController.shared.history) {
        super.init(rootView: SKWhatsNewHistoryView(releases: releases))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = SKLocalization.whatsNewRowTitle
        navigationItem.largeTitleDisplayMode = .never
    }
}

#if DEBUG
#Preview("Sheet") {
    SKWhatsNewView(release: SKWhatsNewCatalog.releases[0])
}

#Preview("History") {
    NavigationStack {
        SKWhatsNewHistoryView(releases: SKWhatsNewCatalog.releases)
    }
}
#endif
