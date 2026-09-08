import XCTest
@testable import OneLife

final class DrinkAdjustmentPolicyTests: XCTestCase {
    func testCanonicalSugarLevelRecognizesAliases() {
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarLevel(in: "五分糖奶茶"), .half)
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarLevel(in: "半糖奶茶"), .half)
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarLevel(in: "少糖美式"), .less)
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarLevel(in: "无糖乌龙"), .noSugar)
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarLevel(in: "全糖珍珠奶茶"), .standard)
        XCTAssertNil(DrinkAdjustmentPolicy.canonicalSugarLevel(in: "黑咖啡"))
    }

    func testCanonicalIceLevelRecognizesAliases() {
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalIceLevel(in: "去冰美式"), .noIce)
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalIceLevel(in: "少冰奶茶"), .less)
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalIceLevel(in: "热的拿铁"), .hot)
        XCTAssertNil(DrinkAdjustmentPolicy.canonicalIceLevel(in: "正常大小"))
    }

    func testCanonicalSugarTextMapsAliasToCanonicalLabel() {
        // "少糖" is an alias that canonicalizes to the "七分糖" label.
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarText("少糖"), "七分糖")
    }

    func testCanonicalSugarTextFallsBackToOriginalWhenUnrecognized() {
        XCTAssertEqual(DrinkAdjustmentPolicy.canonicalSugarText("特调风味"), "特调风味")
    }

    func testNormalizeLowercasesStripsWhitespaceAndConvertsFullwidth() {
        let normalized = DrinkAdjustmentPolicy.normalize("ABC １２３％ DEF")
        XCTAssertEqual(normalized, "abc123%def")
    }

    func testCalorieRangeMidpointAndDisplayText() {
        let range = DrinkAdjustmentPolicy.SugarLevel.standard.calorieRange
        XCTAssertEqual(range.min, 90)
        XCTAssertEqual(range.max, 110)
        XCTAssertEqual(range.midpoint, 100)
        XCTAssertEqual(range.displayText, "+90-110 kcal")
    }

    func testNoSugarAndNormalIceHaveZeroCalorieRange() {
        XCTAssertEqual(DrinkAdjustmentPolicy.SugarLevel.noSugar.calorieRange.midpoint, 0)
        XCTAssertEqual(DrinkAdjustmentPolicy.IceLevel.normal.calorieRange.midpoint, 0)
    }
}
