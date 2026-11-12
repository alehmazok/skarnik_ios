//
//  SKAnalyticsConsentController.swift
//  Skarnik
//

import Foundation
import FirebaseAnalytics

final class SKAnalyticsConsentController {
    static let shared = SKAnalyticsConsentController()

    private static let hasRespondedKey = "analyticsConsentHasResponded"
    private static let grantedKey = "analyticsConsentGranted"

    private let userDefaults: UserDefaults
    private let onConsentGranted: () -> Void

    // Non-private init (unlike sibling singletons) so tests can inject an isolated UserDefaults suite.
    /// `onConsentGranted` runs after collection is switched on, so values set once per launch (the
    /// `install_source` user property) are not missing until the next launch.
    init(
        userDefaults: UserDefaults = .standard,
        onConsentGranted: @escaping () -> Void = {
            SKAnalyticsManager.reportInstallSource()
            SKAnalyticsManager.reportSearchBarPlacement()
        }
    ) {
        self.userDefaults = userDefaults
        self.onConsentGranted = onConsentGranted
    }

    var hasRespondedToConsent: Bool {
        userDefaults.bool(forKey: Self.hasRespondedKey)
    }

    var analyticsConsentGranted: Bool {
        userDefaults.bool(forKey: Self.grantedKey)
    }

    /// Whether Firebase collection is on: the user answered the prompt and agreed.
    var isCollectionEnabled: Bool {
        hasRespondedToConsent && analyticsConsentGranted
    }

    /// Re-applies the persisted consent decision to the Firebase SDK. Call at app launch,
    /// before any analytics event fires, so collection stays off until the user has answered.
    func applyStoredConsent() {
        Analytics.setAnalyticsCollectionEnabled(isCollectionEnabled)
    }

    func grantConsent() {
        userDefaults.set(true, forKey: Self.hasRespondedKey)
        userDefaults.set(true, forKey: Self.grantedKey)
        Analytics.setAnalyticsCollectionEnabled(true)
        onConsentGranted()
    }

    func revokeConsent() {
        userDefaults.set(true, forKey: Self.hasRespondedKey)
        userDefaults.set(false, forKey: Self.grantedKey)
        Analytics.setAnalyticsCollectionEnabled(false)
    }
}
