import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class UserFoodServingProfileTests: XCTestCase {
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    private func makeFood() -> UserFood {
        UserFood(
            name: "希腊酸奶",
            defaultAmount: 2,
            defaultUnit: "份",
            defaultServingGrams: 170,
            caloriesPer100g: 59,
            servingNutrition: ["calories": 100, "protein": 10],
            carbsPer100g: 4
        )
    }

    func testServingValuesWinAndAreScaledByTheDefaultAmount() {
        let profile = makeFood().servingProfile()

        XCTAssertEqual(profile.calories, 200, accuracy: 0.0001)
        XCTAssertEqual(profile.nutrients[.protein] ?? -1, 20, accuracy: 0.0001)
    }

    func testLegacyPer100ColumnsAreUsedOnlyForKeysWithoutServingData() {
        let profile = makeFood().servingProfile()

        // carbs has no per-serving entry: 4 g/100 g × (170 g / 100) × 2 份 = 13.6 g
        XCTAssertEqual(profile.nutrients[.carbs] ?? -1, 13.6, accuracy: 0.0001)
        XCTAssertNil(profile.nutrients[.calcium])
    }

    func testFoodPageAndAIChatProduceTheSameNumbers() throws {
        let (container, context) = try makeStore()
        let food = UserFood(
            name: "可乐",
            defaultAmount: 1,
            defaultUnit: "罐",
            defaultServingGrams: 330,
            caloriesPer100g: 44,
            servingNutrition: ["calories": 145, "carbs": 35],
            proteinPer100g: 0.3
        )
        let meal = Meal(date: .now, mealType: .snack)
        context.insert(meal)
        try context.save()

        FoodTimelineMealWriter.addUserFood(food, mealType: .snack, date: .now, existingMeal: meal, modelContext: context)
        guard let written = (try context.fetch(FetchDescriptor<FoodItem>())).first else {
            return XCTFail("expected a FoodItem from the food page")
        }

        let parser = LocalAIIntentParser(userFoods: [food])
        guard case .addMeal(let parsed)? = parser.parse("喝了可乐"), let chatItem = parsed.items.first else {
            return XCTFail("expected the AI chat path to match 可乐")
        }

        XCTAssertEqual(written.calories, chatItem.calories, accuracy: 0.0001)
        XCTAssertEqual(written.carbs ?? -1, chatItem.carbs ?? -1, accuracy: 0.0001)
        XCTAssertEqual(written.protein ?? -1, chatItem.protein ?? -1, accuracy: 0.0001)
        XCTAssertEqual(written.calories, 145, accuracy: 0.0001, "每份值优先，不再按 per-100g 估算")
    }

    func testTemplateCreatedFromMyFoodCarriesEveryNutrient() {
        let food = UserFood(
            name: "牛奶",
            defaultAmount: 1,
            defaultUnit: "盒",
            defaultServingGrams: 250,
            caloriesPer100g: 66,
            servingNutrition: ["calories": 165, "protein": 8.5, "calcium": 300]
        )
        let profile = food.servingProfile()

        XCTAssertEqual(profile.calories, 165, accuracy: 0.0001)
        XCTAssertEqual(profile.nutrients[.calcium] ?? -1, 300, accuracy: 0.0001, "矿物质不能再从模板里丢掉")
    }
}
