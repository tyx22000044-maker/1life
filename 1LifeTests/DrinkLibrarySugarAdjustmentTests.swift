import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class DrinkLibrarySugarAdjustmentTests: XCTestCase {
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    func testSugarAdjustmentMovesCaloriesSugarAndCarbsTogether() throws {
        let (container, context) = try makeStore()
        context.insert(DrinkRecord(
            brand: "喜茶",
            productName: "纯茶",
            sizeML: 500,
            sugarLevel: "无糖",
            calories: 100,
            protein: 0,
            carbs: 25,
            fat: 0,
            sugar: 0,
            confidence: .high
        ))
        try context.save()
        DrinkLibraryIndex.shared.invalidate()
        defer { DrinkLibraryIndex.shared.invalidate() }

        guard case .addMeal(let meal)? = AIChatDrinkLibraryResolver.makeMealIntent(
            originalText: "喝了一杯喜茶纯茶五分糖",
            modelContext: context
        ), let item = meal.items.first else {
            return XCTFail("期望命中饮品知识库")
        }

        // 五分糖 baseline is +40…50 kcal, midpoint 45 → 11.25 g of sugar, which is carbohydrate.
        XCTAssertEqual(item.calories, 145, accuracy: 0.0001)
        XCTAssertEqual(item.sugar ?? -1, 11.25, accuracy: 0.0001)
        XCTAssertEqual(item.carbs ?? -1, 36.25, accuracy: 0.0001, "加了糖就要同步碳水")
        XCTAssertFalse(AIChatMealValidation.hasBlockingMacroConflict(item), "调整后的条目不能自相矛盾")
    }

    func testNoSugarRequestKeepsTheLibraryBaselineUntouched() throws {
        let (container, context) = try makeStore()
        context.insert(DrinkRecord(
            brand: "喜茶",
            productName: "纯茶",
            sizeML: 500,
            sugarLevel: "无糖",
            calories: 100,
            carbs: 25,
            sugar: 0,
            confidence: .high
        ))
        try context.save()
        DrinkLibraryIndex.shared.invalidate()
        defer { DrinkLibraryIndex.shared.invalidate() }

        guard case .addMeal(let meal)? = AIChatDrinkLibraryResolver.makeMealIntent(
            originalText: "喝了一杯喜茶纯茶无糖",
            modelContext: context
        ), let item = meal.items.first else {
            return XCTFail("期望命中饮品知识库")
        }

        XCTAssertEqual(item.calories, 100, accuracy: 0.0001)
        XCTAssertEqual(item.carbs ?? -1, 25, accuracy: 0.0001)
    }
}
