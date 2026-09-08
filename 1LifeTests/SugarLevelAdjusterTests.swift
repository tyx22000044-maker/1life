import XCTest
@testable import OneLife

@MainActor
final class SugarLevelAdjusterTests: XCTestCase {
    func testNoSugarForcesZeroSugar() {
        let match = SugarLevelAdjuster.match(in: "无糖美式")
        XCTAssertEqual(match?.label, "无糖")
        XCTAssertEqual(match?.multiplier, 0)
        XCTAssertEqual(match?.forcesZeroSugar, true)
    }

    func testHalfSugarVariants() {
        for text in ["五分糖奶茶", "半糖奶茶", "5分糖奶茶", "50%糖奶茶"] {
            let match = SugarLevelAdjuster.match(in: text)
            XCTAssertEqual(match?.label, "五分糖", "failed for \(text)")
            XCTAssertEqual(match?.multiplier, 0.5, "failed for \(text)")
            XCTAssertEqual(match?.forcesZeroSugar, false, "failed for \(text)")
        }
    }

    func testNotAdditionalSugarDoesNotForceZero() {
        let match = SugarLevelAdjuster.match(in: "不另外加糖的豆浆")
        XCTAssertEqual(match?.label, "不另外加糖")
        XCTAssertEqual(match?.multiplier, 1)
        XCTAssertEqual(match?.forcesZeroSugar, false)
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(SugarLevelAdjuster.match(in: "黑咖啡不加奶"))
    }

    func testSearchableFoodNameStripsSizeAndSugarWords() {
        let cleaned = SugarLevelAdjuster.searchableFoodName(from: "大杯五分糖珍珠奶茶")
        XCTAssertEqual(cleaned, "珍珠奶茶")
    }

    func testSearchableFoodNameTrimsWhitespaceWhenNothingRemains() {
        let cleaned = SugarLevelAdjuster.searchableFoodName(from: "  超大杯无糖  ")
        XCTAssertEqual(cleaned, "")
    }
}
