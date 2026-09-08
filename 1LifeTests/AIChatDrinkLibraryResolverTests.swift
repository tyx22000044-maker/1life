import XCTest
@testable import OneLife

@MainActor
final class AIChatDrinkLibraryResolverTests: XCTestCase {
    // MARK: - shouldPreferLibraryOnlyIntent

    func testPureDrinkTextPrefersLibraryOnlyIntent() {
        XCTAssertTrue(AIChatDrinkLibraryResolver.shouldPreferLibraryOnlyIntent(originalText: "喝了一杯美式咖啡"))
    }

    func testTextMentioningMealSignalDoesNotPreferLibraryOnlyIntent() {
        XCTAssertFalse(AIChatDrinkLibraryResolver.shouldPreferLibraryOnlyIntent(originalText: "早餐喝了牛奶"))
    }

    func testTextWithoutDrinkSignalDoesNotPreferLibraryOnlyIntent() {
        XCTAssertFalse(AIChatDrinkLibraryResolver.shouldPreferLibraryOnlyIntent(originalText: "吃了米饭和青菜"))
    }

    // MARK: - waterAmount

    func testWaterAmountSumsDirectMillilitersFromKnownDrinkLibraryItems() {
        var cupItem = AIParsedFoodItem(name: "喜茶多肉葡萄", amount: 650, unit: "ml", calories: 300)
        cupItem.nutritionDataBasis = .direct
        cupItem.nutritionDataNote = "饮品知识库精确命中"

        var riceItem = AIParsedFoodItem(name: "米饭", amount: 200, unit: "g", calories: 260)
        riceItem.nutritionDataBasis = .direct
        riceItem.nutritionDataNote = "饮品知识库命中（不应该出现在真实数据里，仅测试单位分支）"

        var consumedUnitItem = AIParsedFoodItem(name: "奶茶（杯装）", amount: 1, unit: "杯", calories: 300)
        consumedUnitItem.nutritionDataBasis = .direct
        consumedUnitItem.nutritionDataNote = "饮品知识库命中"
        consumedUnitItem.consumedAmount = 500
        consumedUnitItem.consumedUnit = "ml"

        let total = AIChatDrinkLibraryResolver.waterAmount(from: [cupItem, riceItem, consumedUnitItem])
        XCTAssertEqual(total, 650 + 500, accuracy: 0.0001)
    }

    func testWaterAmountIgnoresItemsNotSourcedFromDrinkLibrary() {
        var item = AIParsedFoodItem(name: "手冲咖啡", amount: 300, unit: "ml", calories: 5)
        item.nutritionDataBasis = .estimated // not .direct, and no drink-library note
        XCTAssertEqual(AIChatDrinkLibraryResolver.waterAmount(from: [item]), 0)
    }
}
