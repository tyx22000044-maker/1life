import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class AIChatInsightReplyBuilderTests: XCTestCase {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    private func record(intake calories: Double, in context: ModelContext) {
        let meal = Meal(date: .now, mealType: .lunch)
        context.insert(meal)
        let item = FoodItem(name: "午餐", amount: 1, unit: "份", servingGrams: 1, calories: calories)
        item.meal = meal
        context.insert(item)
        try? context.save()
    }

    func testMissingBodyParametersReportsTargetDifferenceInsteadOfFakeExpenditure() throws {
        let (container, context) = try makeContext()
        let settings = UserSettings(hasCompletedOnboarding: true)
        container.mainContext.insert(settings)
        context.insert(NutritionGoal(dailyCalories: 1600))
        record(intake: 1200, in: context)

        let text = AIChatInsightReplyBuilder.energyAnalysis(modelContext: context, settings: settings)

        XCTAssertFalse(text.contains("消耗估算"), "没有身体参数时不得给出消耗结论")
        XCTAssertTrue(text.contains("摄入目标 1600"), text)
        XCTAssertTrue(text.contains("相对目标差值 -400"), text)
        XCTAssertTrue(text.contains("补齐身高"), text)
    }

    func testMaintenanceEstimateIsUsedAndDietTargetIsNot() throws {
        let (container, context) = try makeContext()
        let settings = UserSettings(
            dietGoalMode: .fatLoss,
            genderRaw: Gender.male.rawValue,
            age: 30,
            heightCm: 175,
            weightKg: 75,
            activityLevelRaw: ActivityLevel.moderatelyActive.rawValue
        )
        container.mainContext.insert(settings)
        // Mifflin: 1698.75 BMR × 1.55 = 2633 kcal maintenance; the fat-loss target is 2106.
        record(intake: 2700, in: context)

        let text = AIChatInsightReplyBuilder.energyAnalysis(modelContext: context, settings: settings)

        XCTAssertTrue(text.contains("消耗估算 2633"), text)
        XCTAssertFalse(text.contains("2106"), "减脂摄入目标不能被当成消耗")
        // Against the real maintenance figure this is maintenance-level intake; the old
        // code compared 2700 to the 2106 diet target and called it a surplus.
        XCTAssertTrue(text.contains("接近维持"), text)
    }

    func testWorkoutCaloriesAreNotDoubleCountedIntoTheBalance() throws {
        let (container, context) = try makeContext()
        let settings = UserSettings(
            genderRaw: Gender.male.rawValue,
            age: 30,
            heightCm: 175,
            weightKg: 75,
            activityLevelRaw: ActivityLevel.moderatelyActive.rawValue
        )
        container.mainContext.insert(settings)
        record(intake: 2700, in: context)
        context.insert(WorkoutLog(
            workoutType: .running,
            startDate: .now,
            durationMinutes: 40,
            caloriesBurned: 400,
            intensity: .moderate,
            source: .manual
        ))
        try context.save()

        let text = AIChatInsightReplyBuilder.energyAnalysis(modelContext: context, settings: settings)

        XCTAssertTrue(text.contains("消耗估算 2633"), text)
        XCTAssertTrue(text.contains("不重复叠加"), text)
        XCTAssertTrue(text.contains("额外 400 kcal"), text)
    }
}
