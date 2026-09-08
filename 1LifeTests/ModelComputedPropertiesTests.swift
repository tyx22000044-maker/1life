import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class ModelComputedPropertiesTests: XCTestCase {
    // MARK: - Meal totals

    func testMealTotalsSumFoodItemsAndTreatAllNilAsNil() {
        let meal = Meal(mealType: .lunch)
        meal.foodItems = [
            FoodItem(name: "A", amount: 100, servingGrams: 100, calories: 100, protein: 10, carbs: 20, fat: nil),
            FoodItem(name: "B", amount: 100, servingGrams: 100, calories: 50, protein: 5, carbs: nil, fat: nil)
        ]
        XCTAssertEqual(meal.totalCalories, 150)
        XCTAssertEqual(meal.totalProtein ?? -1, 15, accuracy: 0.0001)
        XCTAssertEqual(meal.totalCarbs ?? -1, 20, accuracy: 0.0001)
        XCTAssertNil(meal.totalFat) // neither item provides fat
    }

    func testMealWithNoFoodItemsHasZeroCaloriesAndNilMacros() {
        let meal = Meal(mealType: .snack)
        XCTAssertEqual(meal.totalCalories, 0)
        XCTAssertNil(meal.totalProtein)
    }

    func testMealTypeSetterKeepsSortOrderInSync() {
        let meal = Meal(mealType: .breakfast)
        XCTAssertEqual(meal.mealTypeSortOrder, MealType.breakfast.sortOrder)
        meal.mealType = .supper
        XCTAssertEqual(meal.mealType, .supper)
        XCTAssertEqual(meal.mealTypeSortOrder, MealType.supper.sortOrder)
    }

    // MARK: - MealTemplate JSON round-trip

    func testMealTemplateFoodItemsRoundTripThroughJSON() {
        let items = [
            TemplateFoodItem(name: "鸡蛋", amount: 2, unit: "个", servingGrams: 100, calories: 140, protein: 12),
            TemplateFoodItem(name: "牛奶", amount: 250, unit: "ml", servingGrams: 250, calories: 130, protein: 7)
        ]
        let template = MealTemplate(name: "早餐模板", mealType: .breakfast, foodItems: items)

        XCTAssertEqual(template.foodItems.count, 2)
        XCTAssertEqual(template.foodItems.map(\.name), ["鸡蛋", "牛奶"])
        XCTAssertEqual(template.totalCalories, 270)

        template.incrementUseCount()
        XCTAssertEqual(template.useCount, 1)
        XCTAssertNotNil(template.lastUsedAt)
    }

    func testMealTemplateFoodItemsDefaultsToEmptyArray() {
        let template = MealTemplate(name: "空模板")
        XCTAssertTrue(template.foodItems.isEmpty)
        XCTAssertEqual(template.totalCalories, 0)
    }

    // MARK: - Habit

    func testQuantityBasedHabitRequiresTargetGreaterThanOne() {
        XCTAssertFalse(Habit(name: "喝水").isQuantityBased) // no target
        XCTAssertFalse(Habit(name: "喝水", targetCount: 1).isQuantityBased) // target of exactly 1 is not "quantity based"
        XCTAssertTrue(Habit(name: "喝水", targetCount: 8).isQuantityBased)
    }

    // MARK: - UserSettings raw-value backed computed properties fall back safely

    func testAppSettingsGenderAndActivityLevelAreNilWhenUnset() {
        let settings = UserSettings()
        XCTAssertNil(settings.gender)
        XCTAssertNil(settings.activityLevel)
        XCTAssertFalse(settings.hasBodyParameters)
    }

    func testAppSettingsLanguageFallsBackToSystemOnInvalidRawValue() {
        let settings = UserSettings()
        settings.languageRaw = "not-a-real-language"
        XCTAssertEqual(settings.language, .system)
    }

    // MARK: - DrinkRecord display helpers

    func testDrinkRecordDisplayNameIncludesSpecs() {
        let record = DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "七分糖", toppings: "波霸")
        XCTAssertEqual(record.displayName, "喜茶 多肉葡萄（650ml·七分糖·波霸）")
    }

    func testDrinkRecordDisplayNameOmitsEmptySpecs() {
        let record = DrinkRecord(brand: "瑞幸", productName: "美式")
        XCTAssertEqual(record.displayName, "瑞幸 美式")
    }

    func testDrinkRecordDedupeKeyIsStableForEquivalentSpecs() {
        let a = DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "七分糖")
        let b = DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "七分糖")
        XCTAssertEqual(a.dedupeKey, b.dedupeKey)

        let different = DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "无糖")
        XCTAssertNotEqual(a.dedupeKey, different.dedupeKey)
    }
}
