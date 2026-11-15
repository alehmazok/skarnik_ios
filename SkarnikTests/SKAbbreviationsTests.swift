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

    // MARK: - Тлумачальны слоўнік

    private func tsbm(_ text: String, _ place: SKTextPlace) -> [String] {
        SKTsbmAbbreviations.matches(in: text, place: place).map { "\($0.abbreviation)=\($0.expansion)" }
    }

    func testFindsTsbmSourceAsWholeSpanWithoutItsDot() {
        let colas = SKTsbmAbbreviations.matches(in: " Колас.", place: .source).first
        XCTAssertEqual(colas?.range, NSRange(location: 1, length: 5))
        XCTAssertEqual(colas?.abbreviation, "Колас")
        XCTAssertEqual(colas?.expansion.hasPrefix("Якуб Колас:"), true)
        XCTAssertEqual(tsbm("Ядвігін Ш.", .source), ["Ядвігін Ш.=Ядвігін Ш.: Выбр. тв., 1976."])
        XCTAssertEqual(tsbm("З нар.", .source), ["З нар.=з народнай творчасці"])
        XCTAssertEqual(tsbm("Прыказка.", .source), [])
        XCTAssertEqual(tsbm("Колас і Купала.", .source), [])
    }

    func testFindsTsbmAbbreviationsAndSignsOnlyWhereTheDictionaryUsesThem() {
        XCTAssertEqual(tsbm("прыназоўнік з Т.", .label), ["Т=творны склон"])
        XCTAssertEqual(tsbm("Т", .plain), [])
        XCTAssertEqual(tsbm("(у 1 знач.)", .plain), ["знач.=значэнне"])
        XCTAssertEqual(tsbm("[Ад грэч. palaios.]", .plain), ["грэч.=грэчаскае слова"])
        XCTAssertEqual(tsbm("//", .label), ["//=адценне значэння"])
        XCTAssertEqual(tsbm("км/г", .plain), [])
        XCTAssertEqual(tsbm("Разм. жарт.", .quote), [])
    }

    func testFindsACutInACitationButNotOtherDots() {
        XCTAssertEqual(tsbm("Валасы павылазілі. ▪ Карані .. павыпіналіся", .quote),
                       ["▪=знак, які аддзяляе цытаты ад рэдакцыйных прыкладаў", "..=скарачэнне ў цытаце"])
        XCTAssertEqual(tsbm("запрог.. [кабылу]", .quote), ["..=скарачэнне ў цытаце"])
        XCTAssertEqual(tsbm("Чаму?.. Так... Ну!..", .quote), [])
    }
}
