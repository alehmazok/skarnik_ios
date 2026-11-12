//
//  SKInstallSourceTests.swift
//  SkarnikTests
//

import Foundation
import StoreKit
import Testing
#if canImport(MarketplaceKit)
import MarketplaceKit
#endif
@testable import Skarnik

struct SKInstallSourceTests {

    // MARK: - Vocabulary (spec §3)

    @Test func rawValues_matchSharedVocabulary() {
        #expect(SKInstallSource.appStore.rawValue == "app_store")
        #expect(SKInstallSource.testFlight.rawValue == "testflight")
        #expect(SKInstallSource.iosMarketplace.rawValue == "ios_marketplace")
        #expect(SKInstallSource.sideload.rawValue == "sideload")
        #expect(SKInstallSource.debug.rawValue == "debug")
        #expect(SKInstallSource.unknown.rawValue == "unknown")
    }

    @Test func propertyNameAndValues_fitFirebaseLimits() {
        #expect(SKInstallSource.userPropertyName == "install_source")
        #expect(SKInstallSource.userPropertyName.count <= 24)
        let all: [SKInstallSource] = [.appStore, .testFlight, .iosMarketplace, .sideload, .debug, .unknown]
        for source in all {
            #expect(source.rawValue.count <= 36)
        }
    }

    // MARK: - Mapping (spec §4.2)

    @Test func receiptName_sandboxIsTestFlight_otherwiseAppStore() {
        #expect(SKInstallSource(receiptName: "sandboxReceipt") == .testFlight)
        #expect(SKInstallSource(receiptName: "receipt") == .appStore)
        #expect(SKInstallSource(receiptName: nil) == .appStore)
    }

    @Test func appTransactionEnvironment_mapsToChannel() {
        #expect(SKInstallSource(environment: .production) == .appStore)
        #expect(SKInstallSource(environment: .sandbox) == .testFlight)
        #expect(SKInstallSource(environment: .xcode) == .debug)
    }

    #if canImport(MarketplaceKit)
    @Test func appDistributor_mapsToChannel() {
        guard #available(iOS 17.4, *) else { return }
        #expect(SKInstallSource(distributor: .appStore) == .appStore)
        #expect(SKInstallSource(distributor: .testFlight) == .testFlight)
        #expect(SKInstallSource(distributor: .marketplace("com.example.store")) == .iosMarketplace)
        #expect(SKInstallSource(distributor: .other) == .sideload)
    }
    #endif

    // MARK: - Detection

    @Test func detect_inDebugBuild_reportsDebugWithoutLookup() async {
        #if DEBUG
        #expect(await SKInstallSourceDetector.detect() == .debug)
        #endif
    }

    @Test func withTimeout_returnsOperationResult_whenFast() async {
        let value = await SKInstallSourceDetector.withTimeout(seconds: 2, fallback: SKInstallSource.unknown) {
            .appStore
        }
        #expect(value == .appStore)
    }

    @Test func withTimeout_returnsFallbackPromptly_whenOperationHangs() async {
        let start = Date()
        let value = await SKInstallSourceDetector.withTimeout(seconds: 0.2, fallback: SKInstallSource.unknown) {
            // Ignores cancellation, like a stuck network call.
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                    continuation.resume(returning: SKInstallSource.appStore)
                }
            }
        }
        // Waiting for the operation would return .appStore after 120 s instead.
        #expect(value == .unknown)
        // Far under the 120 s the operation hangs for, with headroom for a stalled CI simulator.
        #expect(Date().timeIntervalSince(start) < 60)
    }
}
