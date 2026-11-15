import XCTest
@testable import Skarnik

final class SKAbbreviationsTests: XCTestCase {

    private func found(_ text: String) -> [String] {
        SKAbbreviations.matches(in: text).map { "\($0.abbreviation)=\($0.expansion)" }
    }

    func testExpandsListAndFormsBelRusUses() {
        XCTAssertEqual(SKAbbreviations.expansion(of: "разг."), "разговорное слово, выражение")
        XCTAssertEqual(SKAbbreviations.expansion(of: "жен."), "женский род")
        XCTAssertEqual(SKAbbreviations.expansion(of: "муж."), "мужской род")
        XCTAssertEqual(SKAbbreviations.expansion(of: "несовер."), "несовершенный вид")
        XCTAssertEqual(SKAbbreviations.expansion(of: "антроп."), "антропология")
        XCTAssertNil(SKAbbreviations.expansion(of: "слова"))
    }

    func testFindsSeveralAbbreviationsInOneLabel() {
        XCTAssertEqual(found("жен., мн. нет"), ["жен.=женский род", "мн.=множественное число"])
        XCTAssertEqual(found("перен. разг."), ["перен.=переносное значение", "разг.=разговорное слово, выражение"])
    }

    func testPrefersTheLongestAbbreviation() {
        XCTAssertEqual(found("совер. в разн. знач."), ["совер.=совершенный вид", "в разн. знач.=в разных значениях"])
        XCTAssertEqual(found("в знач. сказ."), ["в знач. сказ.=в значении сказуемого"])
        XCTAssertEqual(found("ж.-д."), ["ж.-д.=железнодорожный термин"])
    }

    func testSpaceAfterDotIsOptional() {
        XCTAssertEqual(found("и т.п."), ["и т.п.=и тому подобное"])
        XCTAssertEqual(found("и т.\u{00A0}д."), ["и т.\u{00A0}д.=и так далее"])
    }

    func testNeverMatchesInsideAWord() {
        XCTAssertEqual(found("ср"), [])
        XCTAssertEqual(found("устарэлае слова, устарэлы выраз"), [])
        XCTAssertEqual(found("муж."), ["муж.=мужской род"])
        XCTAssertEqual(found("радиола"), [])
        XCTAssertEqual(found("радио"), ["радио=радиотехника"])
        XCTAssertEqual(found("п-в"), ["п-в=полуостров"])
    }

    func testRangesAreUTF16() {
        let match = SKAbbreviations.matches(in: "-ння ср.").first
        XCTAssertEqual(match?.range, NSRange(location: 5, length: 3))
    }
}
