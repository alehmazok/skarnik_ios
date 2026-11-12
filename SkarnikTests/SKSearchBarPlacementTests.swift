//
//  SKSearchBarPlacementTests.swift
//  SkarnikTests
//

import XCTest
@testable import Skarnik

final class SKSearchBarPlacementTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SKSearchBarPlacementTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefault_isBottom_whenAvailable() {
        XCTAssertTrue(SKSearchBarPlacement.prefersBottom(in: defaults))
        XCTAssertEqual(SKSearchBarPlacement.current(in: defaults, bottomAvailable: true), .bottom)
    }

    func testSwitchedOff_isTop() {
        defaults.set(false, forKey: SKSearchBarPlacement.userDefaultsKey)

        XCTAssertEqual(SKSearchBarPlacement.current(in: defaults, bottomAvailable: true), .top)
    }

    func testSwitchedBackOn_isBottom() {
        defaults.set(false, forKey: SKSearchBarPlacement.userDefaultsKey)
        defaults.set(true, forKey: SKSearchBarPlacement.userDefaultsKey)

        XCTAssertEqual(SKSearchBarPlacement.current(in: defaults, bottomAvailable: true), .bottom)
    }

    /// Before iOS 26 there is no bottom search tab, whatever the stored choice.
    func testUnavailable_isAlwaysTop() {
        XCTAssertEqual(SKSearchBarPlacement.current(in: defaults, bottomAvailable: false), .top)
        defaults.set(true, forKey: SKSearchBarPlacement.userDefaultsKey)
        XCTAssertEqual(SKSearchBarPlacement.current(in: defaults, bottomAvailable: false), .top)
    }

    /// The Firebase user property values.
    func testRawValues() {
        XCTAssertEqual(SKSearchBarPlacement.bottom.rawValue, "bottom")
        XCTAssertEqual(SKSearchBarPlacement.top.rawValue, "top")
        XCTAssertEqual(SKSearchBarPlacement.userPropertyName, "search_bar_position")
    }
}
