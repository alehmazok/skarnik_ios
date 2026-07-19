import Testing
@testable import Skarnik

// Fakes — no network. Cover stress_spec.md §4a (resolveWordList) and §4b (stressTable)
// branch-by-branch, mirroring the Flutter reference's use_case test coverage (spec §9).

private struct FakeStressBackend: SKStressBackend {
    let source: SKStressSource
    var wordList: [SKStressWordEntry] = []
    var wordListError: Error?
    var rows: [SKStressRow] = []
    var tableError: Error?

    func resolveWordList(_ word: String) async throws -> [SKStressWordEntry] {
        if let wordListError { throw wordListError }
        return wordList
    }

    func stressTable(_ wordId: Int) async throws -> [SKStressRow] {
        if let tableError { throw tableError }
        return rows
    }
}

private enum FakeError: Error {
    case boom
}

@Suite("SKStressResolver — word list resolution (§4a)")
struct SKStressResolverListTests {

    @Test("primary exact match wins, fallback never called")
    func primaryExactMatchWins() async {
        let primary = FakeStressBackend(source: .api, wordList: [
            SKStressWordEntry(id: 1, lemma: "муха", word: "му́ха", tableName: "Nouns", source: .api)
        ])
        let fallback = FakeStressBackend(source: .cloud, wordList: [
            SKStressWordEntry(id: 99, lemma: "муха", word: "должен-не-выбрацца", tableName: nil, source: .cloud)
        ])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)

        let result = await resolver.resolveWordList("муха")

        guard case .success(let entries) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(entries.map(\.id) == [1])
        #expect(entries.allSatisfy { $0.source == .api })
    }

    @Test("primary has no exact match → falls back, fallback exact match wins")
    func primaryEmptyFallsBackToFallbackSuccess() async {
        let primary = FakeStressBackend(source: .api, wordList: [
            SKStressWordEntry(id: 1, lemma: "мухалоўка", word: "мухало́ўка", tableName: nil, source: .api)
        ])
        let fallback = FakeStressBackend(source: .cloud, wordList: [
            SKStressWordEntry(id: 2, lemma: "муха", word: "му́ха", tableName: nil, source: .cloud)
        ])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)

        let result = await resolver.resolveWordList("муха")

        guard case .success(let entries) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(entries.map(\.id) == [2])
        #expect(entries.allSatisfy { $0.source == .cloud })
    }

    @Test("primary throws → falls back to fallback, does not propagate primary's error")
    func primaryThrowsFallsBackToFallback() async {
        let primary = FakeStressBackend(source: .api, wordListError: FakeError.boom)
        let fallback = FakeStressBackend(source: .cloud, wordList: [
            SKStressWordEntry(id: 2, lemma: "муха", word: "му́ха", tableName: nil, source: .cloud)
        ])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)

        let result = await resolver.resolveWordList("муха")

        guard case .success(let entries) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(entries.map(\.id) == [2])
    }

    @Test("fallback has no exact match → notFound, not an error")
    func fallbackEmptyReturnsNotFound() async {
        let primary = FakeStressBackend(source: .api, wordList: [])
        let fallback = FakeStressBackend(source: .cloud, wordList: [
            SKStressWordEntry(id: 2, lemma: "іншае", word: "і́ншае", tableName: nil, source: .cloud)
        ])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)

        let result = await resolver.resolveWordList("муха")

        guard case .notFound = result else {
            Issue.record("expected notFound, got \(result)")
            return
        }
    }

    @Test("fallback throws → error is propagated")
    func fallbackThrowsReturnsError() async {
        let primary = FakeStressBackend(source: .api, wordList: [])
        let fallback = FakeStressBackend(source: .cloud, wordListError: FakeError.boom)
        let resolver = SKStressResolver(primary: primary, fallback: fallback)

        let result = await resolver.resolveWordList("муха")

        guard case .error = result else {
            Issue.record("expected error, got \(result)")
            return
        }
    }

    @Test("exact match is case-sensitive plain string equality, not fuzzy")
    func exactMatchIsStrict() async {
        let primary = FakeStressBackend(source: .api, wordList: [
            SKStressWordEntry(id: 1, lemma: "Муха", word: "Му́ха", tableName: nil, source: .api)
        ])
        let fallback = FakeStressBackend(source: .cloud, wordList: [])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)

        let result = await resolver.resolveWordList("муха")

        guard case .notFound = result else {
            Issue.record("expected notFound (case mismatch must not count as exact), got \(result)")
            return
        }
    }
}

@Suite("SKStressResolver — stress table fetch (§4b)")
struct SKStressResolverTableTests {

    @Test("routes to primary backend for .api-sourced entries")
    func routesToPrimaryForApiSource() async {
        let primary = FakeStressBackend(source: .api, rows: [SKStressRow(title: "форма", content: "каза́к")])
        let fallback = FakeStressBackend(source: .cloud, rows: [SKStressRow(title: "wrong", content: "wrong")])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)
        let entry = SKStressWordEntry(id: 1, lemma: "казак", word: "каза́к", tableName: nil, source: .api)

        let result = await resolver.stressTable(entry)

        guard case .success(let rows) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(rows.first?.title == "форма")
    }

    @Test("routes to fallback backend for .cloud-sourced entries")
    func routesToFallbackForCloudSource() async {
        let primary = FakeStressBackend(source: .api, rows: [SKStressRow(title: "wrong", content: "wrong")])
        let fallback = FakeStressBackend(source: .cloud, rows: [SKStressRow(title: "форма", content: "каза́к")])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)
        let entry = SKStressWordEntry(id: 1, lemma: "казак", word: "каза́к", tableName: nil, source: .cloud)

        let result = await resolver.stressTable(entry)

        guard case .success(let rows) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(rows.first?.title == "форма")
    }

    @Test("empty row list is notFound, not success")
    func emptyRowsIsNotFound() async {
        let primary = FakeStressBackend(source: .api, rows: [])
        let fallback = FakeStressBackend(source: .cloud, rows: [])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)
        let entry = SKStressWordEntry(id: 1, lemma: "казак", word: "каза́к", tableName: nil, source: .api)

        let result = await resolver.stressTable(entry)

        guard case .notFound = result else {
            Issue.record("expected notFound, got \(result)")
            return
        }
    }

    @Test("backend throwing propagates as error, no cross-source retry")
    func backendThrowsPropagatesError() async {
        let primary = FakeStressBackend(source: .api, tableError: FakeError.boom)
        let fallback = FakeStressBackend(source: .cloud, rows: [SKStressRow(title: "should-not-be-used", content: "x")])
        let resolver = SKStressResolver(primary: primary, fallback: fallback)
        let entry = SKStressWordEntry(id: 1, lemma: "казак", word: "каза́к", tableName: nil, source: .api)

        let result = await resolver.stressTable(entry)

        guard case .error = result else {
            Issue.record("expected error (no fallback retry on table fetch), got \(result)")
            return
        }
    }
}
