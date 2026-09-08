import XCTest
@testable import OneLife

@MainActor
final class AIParsedMealPersistenceMapperTests: XCTestCase {
    private func item(amount: Double, unit: String) -> AIParsedFoodItem {
        AIParsedFoodItem(name: "测试食物", amount: amount, unit: unit, calories: 100)
    }

    func testServingGramsPassesThroughForGrams() {
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: 150, unit: "g")), 150)
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: 150, unit: "克")), 150)
    }

    func testServingGramsConvertsKilogramsToGrams() {
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: 1.5, unit: "kg")), 1500)
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: 0.2, unit: "公斤")), 200)
    }

    func testServingGramsPassesThroughForMilliliters() {
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: 500, unit: "ml")), 500)
    }

    func testServingGramsFallsBackToHundredGramsPerUnitForUnknownUnits() {
        // A "serving"-style unit (e.g. 份/杯) is treated as ~100g per unit.
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: 2, unit: "份")), 200)
    }

    func testServingGramsClampsNegativeAmountsToZero() {
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: -50, unit: "g")), 0)
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: -1, unit: "kg")), 0)
        XCTAssertEqual(AIParsedMealPersistenceMapper.servingGrams(for: item(amount: -1, unit: "份")), 0)
    }

    func testFoodItemMappingPreservesNutritionFields() {
        var parsed = AIParsedFoodItem(name: "鸡胸肉", amount: 150, unit: "g", calories: 250, protein: 45, carbs: 0, fat: 5)
        parsed.nutritionDataBasis = .per100g
        parsed.nutritionDataNote = "来自包装标签"

        let foodItem = AIParsedMealPersistenceMapper.foodItem(from: parsed)
        XCTAssertEqual(foodItem.name, "鸡胸肉")
        XCTAssertEqual(foodItem.servingGrams, 150)
        XCTAssertEqual(foodItem.calories, 250)
        XCTAssertEqual(foodItem.protein ?? -1, 45, accuracy: 0.0001)
        XCTAssertEqual(foodItem.nutritionDataBasis, .per100g)
        XCTAssertEqual(foodItem.nutritionDataNote, "来自包装标签")
        XCTAssertEqual(foodItem.source, .ai)
    }

    func testTemplateFoodItemMappingPreservesBasisRawValue() {
        var parsed = AIParsedFoodItem(name: "燕麦", amount: 50, unit: "g", calories: 180)
        parsed.nutritionDataBasis = .estimated

        let templateItem = AIParsedMealPersistenceMapper.templateFoodItem(from: parsed)
        XCTAssertEqual(templateItem.name, "燕麦")
        XCTAssertEqual(templateItem.servingGrams, 50)
        XCTAssertEqual(templateItem.nutritionDataBasisRaw, NutritionDataBasis.estimated.rawValue)
    }
}
