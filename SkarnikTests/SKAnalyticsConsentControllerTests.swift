//
//  SKAnalyticsConsentControllerTests.swift
//  SkarnikTests
//

import Foundation
import Testing
@testable import Skarnik

struct SKAnalyticsConsentControllerTests {

    private func makeController(onConsentGranted: @escaping () -> Void = {}) -> SKAnalyticsConsentController {
        let suiteName = "SKAnalyticsConsentControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SKAnalyticsConsentController(userDefaults: defaults, onConsentGranted: onConsentGranted)
    }

    @Test func defaultState_hasNotResponded() {
        let controller = makeController()

        #expect(controller.hasRespondedToConsent == false)
        #expect(controller.analyticsConsentGranted == false)
    }

    @Test func grantConsent_persistsRespondedAndGranted() {
        let controller = makeController()

        controller.grantConsent()

        #expect(controller.hasRespondedToConsent == true)
        #expect(controller.analyticsConsentGranted == true)
    }

    @Test func revokeConsent_persistsRespondedButNotGranted() {
        let controller = makeController()

        controller.revokeConsent()

        #expect(controller.hasRespondedToConsent == true)
        #expect(controller.analyticsConsentGranted == false)
    }

    @Test func grantAfterRevoke_flipsGrantedBackToTrue() {
        let controller = makeController()

        controller.revokeConsent()
        controller.grantConsent()

        #expect(controller.hasRespondedToConsent == true)
        #expect(controller.analyticsConsentGranted == true)
    }

    // MARK: - install_source hook (spec §5.2)

    @Test func collectionEnabled_onlyAfterGrant() {
        let controller = makeController()
        #expect(controller.isCollectionEnabled == false)

        controller.grantConsent()
        #expect(controller.isCollectionEnabled == true)

        controller.revokeConsent()
        #expect(controller.isCollectionEnabled == false)
    }

    @Test func grantConsent_runsGrantedHook_soInstallSourceIsSetMidSession() {
        var calls = 0
        let controller = makeController(onConsentGranted: { calls += 1 })

        controller.grantConsent()

        #expect(calls == 1)
    }

    @Test func revokeConsent_doesNotRunGrantedHook() {
        var calls = 0
        let controller = makeController(onConsentGranted: { calls += 1 })

        controller.revokeConsent()

        #expect(calls == 0)
    }
}
