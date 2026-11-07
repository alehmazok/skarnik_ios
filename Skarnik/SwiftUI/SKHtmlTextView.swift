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
            .background(Color.clear)
            .frame(minHeight: height)
            .background(Color.clear)

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
        let traits = SKTranslationRenderer.traits(contentSize: UIContentSizeCategory(dynamicTypeSize),
                                                  boldText: boldText)

        // Rendering is SwiftSoup only (no WebKit), but still keep it off the layout pass.
        // updateUIView can be re-invoked before the previous render finishes (e.g. a Dynamic
        // Type change): cancel any in-flight task so an older render can't overwrite a newer one.
        context.coordinator.task?.cancel()
        context.coordinator.task = Task.detached(priority: .userInitiated) {
            let attributedString = SKTranslationRenderer.render(html: html, traits: traits, layout: .compact)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                uiView.attributedText = attributedString
                let newHeight = uiView.sizeThatFits(CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)).height
                if dynamicHeight != newHeight {
                    dynamicHeight = newHeight
                }
            }
        }
    }
}
