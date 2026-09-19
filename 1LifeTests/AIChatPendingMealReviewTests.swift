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

    /// Macro split derived from the calorie figure so these fixtures stay self-consistent
    /// and never trip the macro-conflict gate on purpose.
    private func meal(_ type: MealType, calories: Double) -> AIParsedMeal {
        AIParsedMeal(
            mealType: type,
            items: [AIParsedFoodItem(
                name: "鸡蛋",
                amount: 1,
                unit: "个",
                calories: calories,
                protein: calories * 0.3 / 4,
                carbs: calories * 0.4 / 4,
                fat: calories * 0.3 / 9,
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

    func testRevokingADrinkMealAlsoRevokesItsHydration() throws {
        let (container, viewModel) = try makeViewModel()
        let drinkItem = AIParsedFoodItem(
            name: "Manner 冰美式（473ml）",
            amount: 473,
            unit: "ml",
            calories: 15,
            protein: 0,
            carbs: 0,
            fat: 0,
            nutritionDataBasis: .direct,
            nutritionDataNote: "数据来源：饮品知识库精确命中"
        )
        viewModel.beginMealReview(
            .addMeal(AIParsedMeal(mealType: .snack, items: [drinkItem], note: "")),
            originalText: "喝了杯冰美式",
            isLocal: true
        )
        viewModel.confirmPendingMeals()

        let meals = try container.mainContext.fetch(FetchDescriptor<Meal>())
        let water = try container.mainContext.fetch(FetchDescriptor<WaterLog>())
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(water.map(\.amount), [473])

        guard let toolMessage = viewModel.messages.last, let payload = toolMessage.decodedBubblePayload else {
            return XCTFail("expected a tool message carrying its bubble payload")
        }
        XCTAssertEqual(payload.linkedWaterLogIDs, water.map(\.id), "自动饮水必须记下关联 id")

        viewModel.undoMeal(message: toolMessage)

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Meal>()).count, 0)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<WaterLog>()).count, 0,
                       "撤销饮品餐食必须连带撤销自动生成的饮水")
        XCTAssertTrue(toolMessage.isLinkedDataDeleted)
    }

    func testRevokingAMealLeavesManuallyLoggedWaterAlone() throws {
        let (container, viewModel) = try makeViewModel()
        viewModel.beginMealReview(.addMeal(meal(.lunch, calories: 620)), originalText: "午餐", isLocal: true)
        viewModel.confirmPendingMeals()
        let unrelated = WaterLog(amount: 300)
        container.mainContext.insert(unrelated)
        try container.mainContext.save()

        guard let toolMessage = viewModel.messages.last else { return XCTFail("expected a tool message") }
        viewModel.undoMeal(message: toolMessage)

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<WaterLog>()).map(\.id), [unrelated.id],
                       "没有关联到该餐的手动饮水不能被误删")
    }

    func testConfirmIsBlockedWhenCaloriesAndMacrosContradict() throws {
        let (container, viewModel) = try makeViewModel()
        let conflicting = AIParsedFoodItem(
            name: "鸡胸肉", amount: 100, unit: "g", calories: 100,
            protein: 30, carbs: 30, fat: 30, nutritionDataBasis: .direct
        )
        viewModel.beginMealReview(
            .addMeal(AIParsedMeal(mealType: .lunch, items: [conflicting], note: "")),
            originalText: "午餐吃了鸡胸肉",
            isLocal: false
        )

        viewModel.confirmPendingMeals()

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Meal>()).count, 0,
                       "热量与宏量互相矛盾时不允许一键确认入库")
        XCTAssertEqual(viewModel.pendingMeals.count, 1, "被拦下后必须留在确认卡片上")
        XCTAssertTrue(viewModel.messages.last?.content.contains("手动编辑") ?? false)

        let corrected = AIParsedFoodItem(
            name: "鸡胸肉", amount: 100, unit: "g", calories: 100,
            protein: 20, carbs: 3, fat: 1.5, nutritionDataBasis: .direct
        )
        viewModel.applyManualMealEdit(AIParsedMeal(mealType: .lunch, items: [corrected], note: ""))
        viewModel.confirmPendingMeals()

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Meal>()).count, 1)
    }

    func testSavingAReviewAsATemplatePersistsIt() throws {
        let (container, viewModel) = try makeViewModel()
        viewModel.beginMealReview(.addMeal(meal(.lunch, calories: 620)), originalText: "午餐", isLocal: true)
        let parsed = try XCTUnwrap(viewModel.pendingMeals.first)

        XCTAssertTrue(viewModel.saveAsTemplate(parsed, name: "  健身房午餐  "))
        var templates = try container.mainContext.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(templates.map(\.name), ["健身房午餐"], "名称要修剪后再落库")
        XCTAssertEqual(templates.first?.foodItems.count, 1)
        XCTAssertEqual(templates.first?.foodItems.first?.calories ?? -1, 620, accuracy: 0.0001)

        XCTAssertFalse(viewModel.saveAsTemplate(parsed, name: "健身房午餐"), "重名不得静默新增第二份")
        XCTAssertFalse(viewModel.saveAsTemplate(parsed, name: "   "), "空名称不得创建模板")
        templates = try container.mainContext.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(templates.count, 1)
    }

    func testBatchResultsFlattenEveryMeal() {
        let workout = AIChatIntentResult.addWorkout(AIParsedWorkout(
            workoutType: .running, durationMinutes: 30, caloriesBurned: nil, intensity: .moderate, note: ""
        ))
        let results: [AIChatIntentResult] = [
            workout,
            .addMeal(meal(.lunch, calories: 620)),
            .addMeals([meal(.breakfast, calories: 150), meal(.dinner, calories: 800)])
        ]

        let meals = AIChatViewModel.meals(in: results)

        XCTAssertEqual(meals.map(\.mealType), [.lunch, .breakfast, .dinner], "batch 内的每一餐都要进入确认")
    }
}
