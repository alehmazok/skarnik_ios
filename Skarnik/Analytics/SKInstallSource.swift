//
//  SKInstallSource.swift
//  Skarnik
//
//  The distribution channel the app was installed from, reported as the GA4 user property
//  `install_source` (shared install-source spec, §3 and §4.2). Values are the cross-platform
//  vocabulary shared with skarnik_android, so one GA4 report covers both apps.
//

import Foundation
import StoreKit
#if canImport(MarketplaceKit)
import MarketplaceKit
#endif

enum SKInstallSource: String, Sendable {
    case appStore = "app_store"
    case testFlight = "testflight"
    case iosMarketplace = "ios_marketplace"
    case sideload = "sideload"
    case debug = "debug"
    case unknown = "unknown"

    /// Firebase user property name (max 24 characters). GA4 custom dimension `customUser:install_source`.
    static let userPropertyName = "install_source"

    #if canImport(MarketplaceKit)
    /// iOS 17.4+: MarketplaceKit names the distributor directly. `.web` and `.other` are sideloads.
    @available(iOS 17.4, *)
    init(distributor: AppDistributor) {
        switch distributor {
        case .appStore:
            self = .appStore
        case .testFlight:
            self = .testFlight
        case .marketplace:
            self = .iosMarketplace
        default:
            self = .sideload
        }
    }
    #endif

    /// iOS 16+: the StoreKit 2 app transaction environment. TestFlight installs are sandbox.
    @available(iOS 16.0, *)
    init(environment: AppStore.Environment) {
        switch environment {
        case .production:
            self = .appStore
        case .sandbox:
            self = .testFlight
        case .xcode:
            self = .debug
        default:
            self = .unknown
        }
    }

    /// Last fallback: TestFlight installs have a receipt named `sandboxReceipt`. Same rule as SKCrashReporting.
    init(receiptName: String?) {
        self = receiptName == "sandboxReceipt" ? .testFlight : .appStore
    }
}

enum SKInstallSourceDetector {
    /// How long the lookup may take before `unknown` is reported. `AppTransaction` can hit the network.
    static let timeout: TimeInterval = 3

    /// Debug builds report `debug` without any lookup. Never call on the main actor's critical path:
    /// callers run it from a detached task.
    static func detect() async -> SKInstallSource {
        #if DEBUG
        return .debug
        #else
        return await withTimeout(seconds: timeout, fallback: .unknown) {
            await lookup()
        }
        #endif
    }

    private static func lookup() async -> SKInstallSource {
        #if canImport(MarketplaceKit)
        if #available(iOS 17.4, *), let distributor = try? await AppDistributor.current {
            return SKInstallSource(distributor: distributor)
        }
        #endif
        if #available(iOS 16.0, *), let result = try? await AppTransaction.shared {
            switch result {
            case .verified(let transaction), .unverified(let transaction, _):
                // Only the channel is read, so an unverified transaction is good enough.
                return SKInstallSource(environment: transaction.environment)
            }
        }
        return SKInstallSource(receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent)
    }

    /// Returns `operation`'s result, or `fallback` if it has not finished within `seconds`.
    /// Unlike a task group, this does not wait for a hung operation to finish: the operation is
    /// cancelled and its late result ignored.
    static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        fallback: T,
        operation: @escaping @Sendable () async -> T
    ) async -> T {
        await withCheckedContinuation { continuation in
            let gate = SKResumeOnce(continuation)
            let work = Task {
                gate.resume(returning: await operation())
            }
            Task {
                try? await Task.sleep(seconds: seconds)
                work.cancel()
                gate.resume(returning: fallback)
            }
        }
    }
}

/// Resumes a continuation exactly once, whichever caller comes first.
private final class SKResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
