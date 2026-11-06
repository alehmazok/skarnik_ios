//
//  SKWhatsNewControllerTests.swift
//  SkarnikTests
//

import Foundation
import Testing
@testable import Skarnik

struct SKWhatsNewControllerTests {

    private static let releases = [
        SKWhatsNewRelease(version: "3.8.0", items: [SKWhatsNewItem(symbol: "star", title: "C", text: "c")]),
        SKWhatsNewRelease(version: "3.7.0", items: [SKWhatsNewItem(symbol: "star", title: "B", text: "b")]),
        SKWhatsNewRelease(version: "3.6.0", items: [SKWhatsNewItem(symbol: "star", title: "A", text: "a")]),
    ]

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SKWhatsNewControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeController(_ defaults: UserDefaults, version: String) -> SKWhatsNewController {
        SKWhatsNewController(userDefaults: defaults, releases: Self.releases, currentVersion: version)
    }

    @Test func freshInstall_showsNothingAndMarksVersionSeen() {
        let defaults = makeDefaults()
        let controller = makeController(defaults, version: "3.7.0")

        controller.prepareAtLaunch()

        #expect(controller.releaseToShow == nil)
        #expect(defaults.string(forKey: SKWhatsNewController.lastSeenVersionKey) == "3.7.0")
    }

    @Test func freshInstall_staysQuietAfterConsentIsAnswered() {
        let defaults = makeDefaults()
        makeController(defaults, version: "3.7.0").prepareAtLaunch()
        defaults.set(true, forKey: "analyticsConsentHasResponded")

        let nextLaunch = makeController(defaults, version: "3.7.0")
        nextLaunch.prepareAtLaunch()

        #expect(nextLaunch.releaseToShow == nil)
    }

    @Test func existingUserFromBeforeTheFeature_seesCurrentRelease() {
        let defaults = makeDefaults()
        defaults.set(Data(), forKey: "wordsHistoryKey")
        let controller = makeController(defaults, version: "3.7.0")

        controller.prepareAtLaunch()

        #expect(controller.releaseToShow?.version == "3.7.0")
    }

    @Test func update_showsNewestUnseenReleaseNotNewerThanApp() {
        let defaults = makeDefaults()
        defaults.set("3.6.0", forKey: SKWhatsNewController.lastSeenVersionKey)
        let controller = makeController(defaults, version: "3.7.2")

        controller.prepareAtLaunch()

        #expect(controller.releaseToShow?.version == "3.7.0")
    }

    @Test func markSeen_hidesSheetUntilNextReleaseWithNotes() {
        let defaults = makeDefaults()
        defaults.set("3.6.0", forKey: SKWhatsNewController.lastSeenVersionKey)
        let controller = makeController(defaults, version: "3.7.0")
        controller.prepareAtLaunch()

        controller.markCurrentVersionSeen()

        #expect(controller.releaseToShow == nil)
        #expect(makeController(defaults, version: "3.7.1").releaseToShow == nil)
        #expect(makeController(defaults, version: "3.8.0").releaseToShow?.version == "3.8.0")
    }

    @Test func versionWithoutNotes_isMarkedSeenAtLaunch() {
        let defaults = makeDefaults()
        defaults.set("3.7.0", forKey: SKWhatsNewController.lastSeenVersionKey)
        let controller = makeController(defaults, version: "3.7.1")

        controller.prepareAtLaunch()

        #expect(defaults.string(forKey: SKWhatsNewController.lastSeenVersionKey) == "3.7.1")
    }

    @Test func history_isNewestFirstAndSkipsFutureReleases() {
        let controller = makeController(makeDefaults(), version: "3.7.0")

        #expect(controller.history.map(\.version) == ["3.7.0", "3.6.0"])
    }

    @Test func compare_isNumericAndPadsMissingParts() {
        #expect(SKWhatsNewController.compare("3.10.0", "3.9.0") == .orderedDescending)
        #expect(SKWhatsNewController.compare("3.7", "3.7.0") == .orderedSame)
        #expect(SKWhatsNewController.compare("3.6.4", "3.7.0") == .orderedAscending)
    }

    @Test func catalog_isNewestFirstWithItems() {
        let versions = SKWhatsNewCatalog.releases.map(\.version)
        let sorted = versions.sorted { SKWhatsNewController.compare($0, $1) == .orderedDescending }
        #expect(versions == sorted)
        #expect(SKWhatsNewCatalog.releases.allSatisfy { !$0.items.isEmpty })
    }
}
