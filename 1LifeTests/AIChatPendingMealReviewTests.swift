import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class AIChatPendingMealReviewTests: XCTestCase {
    private func makeViewModel() throws -> (ModelContainer, AIChatViewModel) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let settings = UserSettings(hasCompletedOnboarding: true)
        container.mainContext.insert(settings)
        try container.mainContext.save()

        let viewModel = AIChatViewModel()
        viewModel.configure(modelContext: container.mainContext, settings: settings)
        return (container, viewModel)
    }

    private func meal(_ type: MealType, calories: Double) -> AIParsedMeal {
        AIParsedMeal(
            mealType: type,
            items: [AIParsedFoodItem(
                name: "鸡蛋",
                amount: 1,
                unit: "个",
                calories: calories,
                protein: 12,
                carbs: 2,
                fat: 8,
                nutritionDataBasis: .direct
            )],
            note: ""
        )
    }

    func testMultiMealResultBecomesVisibleReviewState() throws {
        let (_, viewModel) = try makeViewModel()
        let meals = [meal(.breakfast, calories: 150), meal(.lunch, calories: 620)]

        viewModel.beginMealReview(.addMeals(meals), originalText: "记录早餐鸡蛋和午餐牛肉饭", isLocal: false)

        XCTAssertEqual(viewModel.pendingMeals.count, 2)
        guard case .meals(let pending)? = viewModel.pendingConfirmation?.identificationType else {
            return XCTFail("多餐结果必须进入可见的确认卡片状态")
        }
        XCTAssertEqual(pending.count, 2)
    }

    func testConfirmingWritesEveryPendingMeal() throws {
        let (container, viewModel) = try makeViewModel()
        viewModel.beginMealReview(
            .addMeals([meal(.breakfast, calories: 150), meal(.lunch, calories: 620), meal(.dinner, calories: 500)]),
            originalText: "三餐",
            isLocal: false
        )

        viewModel.confirmPendingMeals()

        let stored = try container.mainContext.fetch(FetchDescriptor<Meal>())
        XCTAssertEqual(stored.count, 3, "确认必须写入全部三餐，而不是只写第一餐")
        XCTAssertEqual(Set(stored.map(\.mealType)), [.breakfast, .lunch, .dinner])
        XCTAssertTrue(viewModel.pendingMeals.isEmpty)
        XCTAssertNil(viewModel.pendingConfirmation)
    }

    func testSingleMealReviewKeepsSingleMealShape() throws {
        let (container, viewModel) = try makeViewModel()
        viewModel.beginMealReview(.addMeal(meal(.supper, calories: 300)), originalText: "夜宵", isLocal: true)

        guard case .meal(let confirmation)? = viewModel.pendingConfirmation?.identificationType else {
            return XCTFail("单餐应保持单餐确认形态")
        }
        XCTAssertEqual(confirmation.mealType, .supper)

        viewModel.confirmPendingMeals()
        let stored = try container.mainContext.fetch(FetchDescriptor<Meal>())
        XCTAssertEqual(stored.map(\.mealType), [.supper])
    }

    func testCancellingClearsEveryPendingMeal() throws {
        let (container, viewModel) = try makeViewModel()
        viewModel.beginMealReview(.addMeals([meal(.breakfast, calories: 150), meal(.lunch, calories: 620)]), originalText: "两餐", isLocal: false)

        viewModel.cancelMeal()

        XCTAssertTrue(viewModel.pendingMeals.isEmpty)
        XCTAssertNil(viewModel.pendingConfirmation)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Meal>()).count, 0)
    }

    func testManualEditKeepsTheOtherPendingMeals() throws {
        let (container, viewModel) = try makeViewModel()
        viewModel.beginMealReview(.addMeals([meal(.breakfast, calories: 150), meal(.lunch, calories: 620)]), originalText: "两餐", isLocal: false)

        viewModel.applyManualMealEdit(meal(.breakfast, calories: 220))

        XCTAssertEqual(viewModel.pendingMeals.count, 2, "编辑一餐后不得静默丢掉其余餐")
        XCTAssertEqual(viewModel.pendingMeals.first?.items.first?.calories, 220)
        guard case .meals(let meals)? = viewModel.pendingConfirmation?.identificationType else {
            return XCTFail("编辑后仍需保留可见确认卡片")
        }
        XCTAssertEqual(meals.count, 2)

        viewModel.confirmPendingMeals()
        let stored = try container.mainContext.fetch(FetchDescriptor<Meal>())
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(stored.compactMap { $0.foodItems?.first?.calories }.sorted(), [220, 620])
    }

    func testMealMissingCoreNutritionCannotBeConfirmed() throws {
        let (container, viewModel) = try makeViewModel()
        let lazyItem = AIParsedFoodItem(
            name: "未知食物",
            amount: 1,
            unit: "份",
            calories: 0,
            nutritionDataBasis: .estimated
        )
        viewModel.beginMealReview(
            .addMeals([AIParsedMeal(mealType: .lunch, items: [lazyItem], note: "")]),
            originalText: "午饭",
            isLocal: false
        )

        viewModel.confirmPendingMeals()

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Meal>()).count, 0)
        XCTAssertEqual(viewModel.pendingMeals.count, 1, "被拦下的餐食必须留在确认卡片上")
        XCTAssertTrue(viewModel.messages.last?.content.contains("缺少关键营养字段") ?? false)
    }
}
