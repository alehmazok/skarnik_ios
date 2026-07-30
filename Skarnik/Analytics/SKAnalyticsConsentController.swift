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

    // Non-private init (unlike sibling singletons) so tests can inject an isolated UserDefaults suite.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasRespondedToConsent: Bool {
        userDefaults.bool(forKey: Self.hasRespondedKey)
    }

    var analyticsConsentGranted: Bool {
        userDefaults.bool(forKey: Self.grantedKey)
    }

    /// Re-applies the persisted consent decision to the Firebase SDK. Call at app launch,
    /// before any analytics event fires, so collection stays off until the user has answered.
    func applyStoredConsent() {
        Analytics.setAnalyticsCollectionEnabled(hasRespondedToConsent && analyticsConsentGranted)
    }

    func grantConsent() {
        userDefaults.set(true, forKey: Self.hasRespondedKey)
        userDefaults.set(true, forKey: Self.grantedKey)
        Analytics.setAnalyticsCollectionEnabled(true)
    }

    func revokeConsent() {
        userDefaults.set(true, forKey: Self.hasRespondedKey)
        userDefaults.set(false, forKey: Self.grantedKey)
        Analytics.setAnalyticsCollectionEnabled(false)
    }
}
