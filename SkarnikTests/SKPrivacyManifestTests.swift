//
//  SKPrivacyManifestTests.swift
//  SkarnikTests
//

import Foundation
import Testing

/// Checks that the app and the widget ship their `PrivacyInfo.xcprivacy` (issue #59):
/// App Store Connect warns with ITMS-91053 when a bundle uses a required-reason API
/// (here `UserDefaults`) without declaring it.
struct SKPrivacyManifestTests {

    static let appBundleUrl = Bundle.main.bundleURL
    static let widgetBundleUrl = appBundleUrl
        .appendingPathComponent("PlugIns")
        .appendingPathComponent("WordWidgetExtension.appex")

    private func manifest(in bundleUrl: URL) throws -> [String: Any] {
        let url = bundleUrl.appendingPathComponent("PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    private func reasons(for category: String, in manifest: [String: Any]) -> [String] {
        let apis = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        return apis
            .filter { $0["NSPrivacyAccessedAPIType"] as? String == category }
            .flatMap { $0["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [] }
    }

    private func collectedTypes(in manifest: [String: Any]) -> [[String: Any]] {
        manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
    }

    @Test(arguments: [appBundleUrl, widgetBundleUrl])
    func declaresUserDefaultsAndNoTracking(bundleUrl: URL) throws {
        let manifest = try manifest(in: bundleUrl)

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        #expect(reasons(for: "NSPrivacyAccessedAPICategoryUserDefaults", in: manifest) == ["CA92.1"])
        for type in collectedTypes(in: manifest) {
            #expect(type["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        }
    }

    @Test func appDeclaresAnalyticsAndCrashData() throws {
        let manifest = try manifest(in: Self.appBundleUrl)
        let types = Set(collectedTypes(in: manifest).compactMap { $0["NSPrivacyCollectedDataType"] as? String })

        #expect(types == [
            "NSPrivacyCollectedDataTypeProductInteraction",
            "NSPrivacyCollectedDataTypeSearchHistory",
            "NSPrivacyCollectedDataTypeDeviceID",
            "NSPrivacyCollectedDataTypeCoarseLocation",
            "NSPrivacyCollectedDataTypeCrashData",
            "NSPrivacyCollectedDataTypeOtherDiagnosticData",
        ])
    }

    @Test func widgetCollectsNothing() throws {
        let manifest = try manifest(in: Self.widgetBundleUrl)

        #expect(collectedTypes(in: manifest).isEmpty)
    }
}
