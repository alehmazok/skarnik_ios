//
//  SKHtmlTextView.swift
//  Skarnik
//
//  Created by Logout on 10.11.23.
//  Copyright © 2023 Skarnik. All rights reserved.
//

import UIKit
import SwiftUI

struct SKHtmlTextView: View {
    var html: String

    @MainActor @State private var height: CGFloat = .zero
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight

    var body: some View {
        SKHtmlLabelView(html: html,
                        dynamicTypeSize: dynamicTypeSize,
                        boldText: legibilityWeight == .bold,
                        dynamicHeight: $height)
            .combinedBackground(.clear)
            .frame(minHeight: height)
            .combinedBackground(.clear)

    }
}

struct SKHtmlLabelView: UIViewRepresentable {

    let html: String
    let dynamicTypeSize: DynamicTypeSize
    let boldText: Bool
    @Binding var dynamicHeight: CGFloat

    final class Coordinator {
        var task: Task<Void, Never>?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let html = self.html
        let traits = SKTranslationRenderer.traits(contentSize: dynamicTypeSize.skContentSizeCategory,
                                                  boldText: boldText)

        // Rendering is SwiftSoup only (no WebKit), but still keep it off the layout pass.
        // updateUIView can be re-invoked before the previous render finishes (e.g. a Dynamic
        // Type change): cancel any in-flight task so an older render can't overwrite a newer one.
        context.coordinator.task?.cancel()
        context.coordinator.task = Task { @MainActor in
            let attributedString = await Task.detached(priority: .userInitiated) {
                SKUncheckedSendable(SKTranslationRenderer.render(html: html, traits: traits, layout: .compact))
            }.value.value
            guard !Task.isCancelled else { return }
            uiView.attributedText = attributedString
            let newHeight = uiView.sizeThatFits(CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)).height
            if dynamicHeight != newHeight {
                dynamicHeight = newHeight
            }
        }
    }
}

extension DynamicTypeSize {
    /// UIKit content size for this SwiftUI size (`UIContentSizeCategory(_:)` needs iOS 17).
    var skContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}
