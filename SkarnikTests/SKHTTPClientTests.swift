import XCTest
@testable import Skarnik

/// Cache rules shared with skarnik_android: 24 h freshness whatever the server says, stale copy on a network failure.
final class SKHTTPClientTests: XCTestCase {

    private final class FakeNetwork: @unchecked Sendable {
        private let lock = NSLock()
        private var _calls = 0
        var result: Result<(Int, Data, [String: String]), Error> = .success((200, Data("fresh".utf8), [:]))

        var calls: Int { lock.withLock { _calls } }

        func respond(_ request: URLRequest) throws -> (Data, URLResponse) {
            lock.withLock { _calls += 1 }
            let (status, data, headers) = try result.get()
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: headers)!
            return (data, response)
        }
    }

    private final class Clock: @unchecked Sendable {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private var network: FakeNetwork!
    private var clock: Clock!
    private var client: SKHTTPClient!
    private let request = URLRequest(url: URL(string: "https://skarnik.play.of.by/api/words/belrus/27890/")!)

    override func setUp() {
        super.setUp()
        network = FakeNetwork()
        clock = Clock()
        let cache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 0, directory: nil)
        let network = self.network!
        let clock = self.clock!
        client = SKHTTPClient(cache: cache, now: { clock.date }) { try network.respond($0) }
    }

    func testCacheLifetimeIs24Hours() {
        XCTAssertEqual(SKHTTPClient.cacheLifetime, 24 * 60 * 60)
    }

    func testFreshResponseIsServedFromCache() async {
        let first = await client.data(for: request)
        network.result = .success((200, Data("changed".utf8), [:]))
        clock.date += SKHTTPClient.cacheLifetime - 60

        let second = await client.data(for: request)

        XCTAssertEqual(first, Data("fresh".utf8))
        XCTAssertEqual(second, Data("fresh".utf8))
        XCTAssertEqual(network.calls, 1)
    }

    func testServerNoCacheHeadersAreIgnored() async {
        network.result = .success((200, Data("fresh".utf8), ["Cache-Control": "no-cache, no-store", "Pragma": "no-cache"]))
        _ = await client.data(for: request)

        _ = await client.data(for: request)

        XCTAssertEqual(network.calls, 1)
    }

    func testResponseOlderThan24HoursIsFetchedAgain() async {
        _ = await client.data(for: request)
        network.result = .success((200, Data("changed".utf8), [:]))
        clock.date += SKHTTPClient.cacheLifetime + 1

        let data = await client.data(for: request)

        XCTAssertEqual(data, Data("changed".utf8))
        XCTAssertEqual(network.calls, 2)
    }

    func testNetworkFailureServesStaleCopy() async {
        _ = await client.data(for: request)
        clock.date += 30 * SKHTTPClient.cacheLifetime
        network.result = .failure(URLError(.notConnectedToInternet))

        let data = await client.data(for: request)

        XCTAssertEqual(data, Data("fresh".utf8))
        XCTAssertEqual(network.calls, 2)
    }

    func testNetworkFailureWithNothingCachedReturnsNil() async {
        network.result = .failure(URLError(.timedOut))

        let data = await client.data(for: request)

        XCTAssertNil(data)
    }

    func testCancelledRequestGetsNoStaleCopy() async {
        _ = await client.data(for: request)
        clock.date += SKHTTPClient.cacheLifetime + 1
        network.result = .failure(URLError(.cancelled))

        let data = await client.data(for: request)

        XCTAssertNil(data)
    }

    func testHttpErrorIsNotCachedAndGetsNoStaleCopy() async {
        _ = await client.data(for: request)
        clock.date += SKHTTPClient.cacheLifetime + 1
        network.result = .success((503, Data("down".utf8), [:]))

        let data = await client.data(for: request)

        XCTAssertNil(data)

        network.result = .success((200, Data("back".utf8), [:]))
        let recovered = await client.data(for: request)
        XCTAssertEqual(recovered, Data("back".utf8))
        XCTAssertEqual(network.calls, 3)
    }

    func testDifferentUrlsAreCachedSeparately() async {
        let other = URLRequest(url: URL(string: "https://skarnik.play.of.by/api/words/tsbm/1/")!)
        _ = await client.data(for: request)
        network.result = .success((200, Data("other".utf8), [:]))

        let data = await client.data(for: other)

        XCTAssertEqual(data, Data("other".utf8))
        XCTAssertEqual(network.calls, 2)
    }
}
