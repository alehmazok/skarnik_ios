//
//  SKCrashReportingTests.swift
//  SkarnikTests
//

import Foundation
import Testing
@testable import Skarnik

struct SKCrashReportingConfigTests {

    @Test func emptyDSN_isDisabled() {
        let config = SKCrashReportingConfig.make(dsn: "", receiptName: "receipt")
        #expect(config.isEnabled == false)
    }

    @Test func missingDSN_isDisabled() {
        let config = SKCrashReportingConfig.make(dsn: nil, receiptName: nil)
        #expect(config.isEnabled == false)
    }

    @Test func unexpandedBuildSetting_isDisabled() {
        let config = SKCrashReportingConfig.make(dsn: "$(SENTRY_DSN)", receiptName: nil)
        #expect(config.isEnabled == false)
    }

    @Test func httpsDSN_isEnabled() {
        let config = SKCrashReportingConfig.make(dsn: " https://key@o1.ingest.sentry.io/2\n", receiptName: "receipt")
        #expect(config.isEnabled)
        #expect(config.dsn == "https://key@o1.ingest.sentry.io/2")
    }

    @Test func sandboxReceipt_isInternal() {
        let config = SKCrashReportingConfig.make(dsn: "https://key@o1.ingest.sentry.io/2", receiptName: "sandboxReceipt")
        #expect(config.environment == "internal")
    }

    @Test func appStoreReceipt_isProduction() {
        let config = SKCrashReportingConfig.make(dsn: "https://key@o1.ingest.sentry.io/2", receiptName: "receipt")
        #expect(config.environment == "production")
    }

    @Test func testBuild_hasNoDSN() {
        // Debug builds (the ones tests run) must never report.
        #expect(SKCrashReportingConfig.current().isEnabled == false)
    }
}

struct SKErrorReportingTests {

    private enum SampleError: Error {
        case first
        case withWord(String)
    }

    @Test func urlError_isNotReported() {
        #expect(SKErrorReporting.report(for: URLError(.notConnectedToInternet), tag: "T") == nil)
    }

    @Test func urlDomainNSError_isNotReported() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        #expect(SKErrorReporting.report(for: error, tag: "T") == nil)
    }

    @Test func wrappedURLError_isNotReported() {
        let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let error = NSError(domain: "Wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: underlying])
        #expect(SKErrorReporting.report(for: error, tag: "T") == nil)
    }

    @Test func cancellation_isNotReported() {
        #expect(SKErrorReporting.report(for: CancellationError(), tag: "T") == nil)
    }

    @Test func appNetworkErrors_areNotReported() {
        #expect(SKErrorReporting.report(for: SKSkarnikError.networkError, tag: "T") == nil)
        #expect(SKErrorReporting.report(for: SKStressError.networkError, tag: "T") == nil)
        #expect(SKErrorReporting.report(for: SKOfflineDictionaryCloudError.invalidResponse, tag: "T") == nil)
    }

    @Test func programmingErrors_areReported() {
        #expect(SKErrorReporting.report(for: SKOfflineDictionaryCloudError.invalidURL, tag: "T") != nil)
        #expect(SKErrorReporting.report(for: SKSkarnikError.nextWordIndexRequired, tag: "T") != nil)
    }

    @Test func report_hasTypeCodeAndTagOnly() throws {
        let report = try #require(SKErrorReporting.report(for: SampleError.withWord("сакрэт"), tag: "WordDetails"))
        #expect(report.type.hasSuffix("SampleError"))
        #expect(report.code == 1)
        #expect(report.tag == "WordDetails")
        #expect(!report.type.contains("сакрэт"))
    }

    @Test func nsErrorReport_dropsUserInfo() throws {
        let error = NSError(domain: "SQLite.Result", code: 3, userInfo: [NSLocalizedDescriptionKey: "no such word: сакрэт"])
        let report = try #require(SKErrorReporting.report(for: error, tag: "VocabularyIndex"))
        #expect(report == SKErrorReport(type: "SQLite.Result", code: 3, tag: "VocabularyIndex"))
    }

    @Test func logError_withoutReporter_doesNotCrash() {
        // The widget, debug builds and tests have no reporter.
        SKErrorReporting.logError(SampleError.first, tag: "NoReporter")
    }
}
