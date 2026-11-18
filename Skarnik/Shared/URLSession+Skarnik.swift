//
//  URLSession.swift
//  Skarnik
//
//  Created by Logout on 4.11.22.
//  Copyright © 2022 Skarnik. All rights reserved.
//

import Foundation

/// HTTP for translations (Supabase, the admin API) and stress tables (starnik.by, the admin API), with the same
/// cache rules as skarnik_android's OkHttp client (`NetworkModule`, `CacheLifetimeInterceptor`):
///
/// - One 20 MB disk cache. A successful GET is served from it for `cacheLifetime` (24 h) whatever the server
///   says: none of these servers sends cache headers meant for this.
/// - A constant, not a remote setting: dictionary edits are rare and a day of staleness is fine.
/// - When the network fails (no connection, timeout, DNS: a `URLError`), a cached response of any age is
///   served instead, so a word opened before still opens offline. An HTTP error status is not a network
///   failure and gets no stale fallback, same as Android.
/// - No ETags or revalidation: after 24 h the response is fetched again in full.
///
/// The cache is handled here rather than by `URLSession`'s HTTP caching, which follows the servers' headers.
final class SKHTTPClient: @unchecked Sendable {
    // @unchecked: every stored property is immutable, and `URLCache` is thread-safe.

    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let cacheLifetime: TimeInterval = 24 * 60 * 60
    static let timeout: TimeInterval = 20
    private static let diskCapacity = 20 * 1024 * 1024
    private static let memoryCapacity = 2 * 1024 * 1024
    /// When the response was stored, in seconds since 1970: the age check reads this, not the server's `Date`.
    static let storedAtHeader = "X-Skarnik-Stored-At"

    static let shared: SKHTTPClient = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = timeout
        let session = URLSession(configuration: configuration)
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("http", isDirectory: true)
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, directory: directory)
        return SKHTTPClient(cache: cache) { try await session.data(for: $0) }
    }()

    private let cache: URLCache
    private let transport: Transport
    private let now: @Sendable () -> Date

    init(cache: URLCache, now: @escaping @Sendable () -> Date = { Date() }, transport: @escaping Transport) {
        self.cache = cache
        self.now = now
        self.transport = transport
    }

    /// The body of a 2xx response, from the cache while it is fresh, else from the network; a stale cached body
    /// when the network fails. `nil` for an HTTP error status, a cancelled request, or a failure with nothing cached.
    func data(for request: URLRequest) async -> Data? {
        let cached = cache.cachedResponse(for: request)
        if let cached, isFresh(cached) {
            return cached.data
        }
        do {
            let (data, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return nil
            }
            store(data: data, response: http, for: request)
            return data
        } catch let error as URLError where error.code != .cancelled {
            return cached?.data
        } catch {
            return nil
        }
    }

    private func isFresh(_ cached: CachedURLResponse) -> Bool {
        guard let header = (cached.response as? HTTPURLResponse)?.value(forHTTPHeaderField: Self.storedAtHeader),
              let storedAt = TimeInterval(header) else { return false }
        let age = now().timeIntervalSince1970 - storedAt
        return age >= 0 && age < Self.cacheLifetime
    }

    private func store(data: Data, response: HTTPURLResponse, for request: URLRequest) {
        guard request.httpMethod == nil || request.httpMethod == "GET", let url = response.url ?? request.url else { return }
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String, let value = value as? String else { continue }
            switch key.lowercased() {
            case "cache-control", "pragma", "expires", "vary", "set-cookie": continue
            default: headers[key] = value
            }
        }
        headers["Cache-Control"] = "max-age=\(Int(Self.cacheLifetime))"
        headers[Self.storedAtHeader] = String(Int(now().timeIntervalSince1970))
        guard let stored = HTTPURLResponse(url: url, statusCode: response.statusCode,
                                           httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        cache.storeCachedResponse(CachedURLResponse(response: stored, data: data, storagePolicy: .allowed), for: request)
    }
}

extension URLSession {

    class func skarnikDownload(urlStr: String) async -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        return await SKHTTPClient.shared.data(for: URLRequest(url: url))
    }

    class func skarnikDownload(urlStr: String, headers: [String: String]) async -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return await SKHTTPClient.shared.data(for: request)
    }
}
