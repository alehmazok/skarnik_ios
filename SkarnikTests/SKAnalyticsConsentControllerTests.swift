//
//  SKAnalyticsConsentControllerTests.swift
//  SkarnikTests
//

import Foundation
import Testing
@testable import Skarnik

struct SKAnalyticsConsentControllerTests {

    private func makeController() -> SKAnalyticsConsentController {
        let suiteName = "SKAnalyticsConsentControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SKAnalyticsConsentController(userDefaults: defaults)
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
}
