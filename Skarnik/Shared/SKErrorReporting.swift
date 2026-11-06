//
//  SKErrorReporting.swift
//  Skarnik
//
//  Non-fatal error reports (issue #28). Shared by the app and the widget, so it does not import
//  Sentry: the app plugs Sentry in through `reporter` at launch (`SKCrashReporting.start`); in the
//  widget, debug builds and tests `reporter` stays nil and `logError` only logs.
//

import Foundation
import os.log

/// What a caught error sends: its type and code and where it was caught. Never the error's message,
/// description or `userInfo`, which can hold the search query, the word or a URL with either.
struct SKErrorReport: Equatable {
    /// The error type, e.g. `Swift.DecodingError` or `SQLite.Result` (the bridged `NSError` domain).
    let type: String
    /// The `NSError` code; for a Swift enum error, the index of the case.
    let code: Int
    /// Where the error was caught, e.g. `OfflineDictionaryStore`.
    let tag: String
}

/// An app error type that wraps network or server failures (offline, HTTP status, bad response).
/// Those cases are not reported, like `URLError`.
protocol SKNetworkFailureError: Error {
    var isNetworkFailure: Bool { get }
}

extension SKSkarnikError: SKNetworkFailureError {
    var isNetworkFailure: Bool { self == .networkError }
}

enum SKErrorReporting {
    /// Sends a report. Set once by the app at launch, before any other code runs.
    nonisolated(unsafe) static var reporter: ((SKErrorReport) -> Void)?

    /// Logs a caught error and reports it as a non-fatal when `isReportable(_:)`.
    static func logError(_ error: Error, tag: String) {
        os_log("[%{public}@] %{private}@", log: .default, type: .error, tag, String(describing: error))
        guard let reporter, let report = report(for: error, tag: tag) else { return }
        reporter(report)
    }

    /// The report for `error`, or nil when it is not worth one.
    static func report(for error: Error, tag: String) -> SKErrorReport? {
        guard isReportable(error) else { return nil }
        let nsError = error as NSError
        return SKErrorReport(type: nsError.domain, code: nsError.code, tag: tag)
    }

    /// Network and offline failures are expected on a phone and would bury real bugs, so they are not
    /// reported (same rule as Android's `IOException`); neither is a cancelled task.
    static func isReportable(_ error: Error) -> Bool {
        if error is URLError || error is CancellationError { return false }
        if let appError = error as? SKNetworkFailureError, appError.isNetworkFailure { return false }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return false }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return false
        }
        return true
    }
}
