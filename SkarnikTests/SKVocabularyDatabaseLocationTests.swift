import XCTest
@testable import Skarnik

// Issue #58: vocabulary.db is bundled only into the app; the widget extension reads the containing app's copy.
final class SKVocabularyDatabaseLocationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testAppBundleFindsItsOwnDatabase() {
        XCTAssertNotNil(SKVocabularyIndex.databaseURL(in: Bundle.main))
    }

    func testExtensionFindsContainingAppDatabase() throws {
        let app = try makeBundle("Skarnik.app", in: root, withDatabase: true)
        let appex = try makeBundle("WordWidgetExtension.appex", in: app.appendingPathComponent("PlugIns"), withDatabase: false)

        let url = SKVocabularyIndex.databaseURL(in: try XCTUnwrap(Bundle(url: appex)))

        XCTAssertEqual(url?.resolvingSymlinksInPath(),
                       app.appendingPathComponent("vocabulary.db").resolvingSymlinksInPath())
    }

    func testExtensionPrefersItsOwnCopyIfPresent() throws {
        let app = try makeBundle("Skarnik.app", in: root, withDatabase: true)
        let appex = try makeBundle("WordWidgetExtension.appex", in: app.appendingPathComponent("PlugIns"), withDatabase: true)

        let url = SKVocabularyIndex.databaseURL(in: try XCTUnwrap(Bundle(url: appex)))

        XCTAssertEqual(url?.resolvingSymlinksInPath(),
                       appex.appendingPathComponent("vocabulary.db").resolvingSymlinksInPath())
    }

    func testExtensionOutsideAnAppFindsNothing() throws {
        let appex = try makeBundle("WordWidgetExtension.appex", in: root.appendingPathComponent("PlugIns"), withDatabase: false)

        XCTAssertNil(SKVocabularyIndex.databaseURL(in: try XCTUnwrap(Bundle(url: appex))))
    }

    private func makeBundle(_ name: String, in parent: URL, withDatabase: Bool) throws -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "test.\(UUID().uuidString)", "CFBundlePackageType": "APPL"]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: url.appendingPathComponent("Info.plist"))
        if withDatabase {
            try Data("db".utf8).write(to: url.appendingPathComponent("vocabulary.db"))
        }
        return url
    }
}
