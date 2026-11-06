//
//  SKCrashReporting.swift
//  Skarnik
//
//  Crash reporting with Sentry (issue #28), same rules as skarnik_android (docs/adr/0008 there).
//  Release builds that CI made with the SENTRY_DSN secret only; debug and local builds report nothing.
//  Not gated by the analytics consent, as Crashlytics wasn't: reports carry no user data.
//

import Foundation
import Sentry

/// Where crash reports go, read from the build. `dsn` is empty unless CI passed one.
struct SKCrashReportingConfig: Equatable {
    let dsn: String
    let environment: String

    var isEnabled: Bool { dsn.hasPrefix("https://") }

    /// `SKSentryDSN` in Info.plist is `$(SENTRY_DSN)`: empty in the project, set by CI on the archive.
    /// TestFlight and App Store run the same binary, so the environment comes from the receipt at run
    /// time: TestFlight installs have a sandbox receipt.
    static func current(bundle: Bundle = .main) -> SKCrashReportingConfig {
        make(dsn: bundle.object(forInfoDictionaryKey: "SKSentryDSN") as? String,
             receiptName: bundle.appStoreReceiptURL?.lastPathComponent)
    }

    static func make(dsn: String?, receiptName: String?) -> SKCrashReportingConfig {
        SKCrashReportingConfig(
            dsn: dsn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            environment: receiptName == "sandboxReceipt" ? "internal" : "production"
        )
    }
}

enum SKCrashReporting {
    /// Starts Sentry. Call first in `application(_:didFinishLaunchingWithOptions:)`. Does nothing in debug
    /// builds, under UI tests, or without a DSN.
    static func start(config: SKCrashReportingConfig = .current()) {
        #if DEBUG
        return
        #else
        guard config.isEnabled, !SKUITesting.isActive else { return }
        SentrySDK.start { options in
            SKCrashReporting.configure(options, config: config)
        }
        SKErrorReporting.reporter = { report in
            SentrySDK.capture(event: SKCrashReporting.event(for: report))
        }
        #endif
    }

    /// Crashes, hangs and the non-fatals from `SKErrorReporting`; nothing that names the user or what
    /// they looked up.
    static func configure(_ options: Options, config: SKCrashReportingConfig) {
        options.dsn = config.dsn
        options.environment = config.environment
        // No IP address, no user id.
        options.sendDefaultPii = false
        // The screen can show what the user searched for.
        options.attachScreenshot = false
        options.attachViewHierarchy = false
        // No tap or system breadcrumbs, and no network breadcrumbs or failed-request events: their URLs
        // carry the query or the word. Without swizzling none of the automatic UI/network hooks run.
        options.enableAutoBreadcrumbTracking = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false
        options.enableSwizzling = false
        // Errors only: no performance tracing, no session replay.
        options.tracesSampleRate = nil
        options.enableAutoPerformanceTracing = false
        options.enableUserInteractionTracing = false
        options.enableNetworkTracking = false
        options.enableFileIOTracing = false
        options.enableCoreDataTracing = false
        options.sessionReplay.sessionSampleRate = 0
        options.sessionReplay.onErrorSampleRate = 0
    }

    /// A non-fatal event with the error's type and code only; the SDK adds the stack trace.
    static func event(for report: SKErrorReport) -> Event {
        let event = Event(level: .error)
        event.exceptions = [Exception(value: "Code: \(report.code)", type: report.type)]
        event.tags = ["log_tag": report.tag]
        return event
    }
}
