//
//  SKAnalyticsConsentView.swift
//  Skarnik
//

import UIKit
import SwiftUI

struct SKAnalyticsConsentView: View {
    var onDecision: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text(SKLocalization.analyticsConsentTitle)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)

            Text(SKLocalization.analyticsConsentMessage)
                .font(.system(size: 15))
                .foregroundStyle(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    SKAnalyticsConsentController.shared.grantConsent()
                    onDecision?()
                } label: {
                    Text(SKLocalization.analyticsConsentAccept)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    SKAnalyticsConsentController.shared.revokeConsent()
                    onDecision?()
                } label: {
                    Text(SKLocalization.analyticsConsentDecline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }
}

// MARK: - UIKit presentation

final class SKAnalyticsConsentViewController: UIHostingController<SKAnalyticsConsentView> {

    init() {
        super.init(rootView: SKAnalyticsConsentView())
        rootView.onDecision = { [weak self] in
            self?.dismiss(animated: true)
        }
        modalPresentationStyle = .formSheet
        isModalInPresentation = true
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#if DEBUG
#Preview {
    SKAnalyticsConsentView()
}
#endif
