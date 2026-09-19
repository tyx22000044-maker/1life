import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class SettingsDataCoordinatorTests: XCTestCase {
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    private func seed(_ context: ModelContext) throws -> UserSettings {
        let settings = UserSettings(nickname: "小明", hasCompletedOnboarding: true)
        settings.isHealthKitEnabled = true
        settings.isAIConfigured = true
        context.insert(settings)

        let meal = Meal(date: .now, mealType: .lunch)
        context.insert(meal)
        let item = FoodItem(name: "米饭", amount: 200, servingGrams: 200, calories: 230)
        item.meal = meal
        context.insert(item)
        context.insert(WaterLog(amount: 250))
        context.insert(DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, calories: 320))
        context.insert(SupplementRecord(brand: "X", productName: "鱼油", form: "胶囊", calories: 20))
        context.insert(UserFood(name: "牛奶", caloriesPer100g: 66))
        context.insert(MealTemplate(name: "健身餐", mealType: .lunch))
        let habit = Habit(name: "走路", frequencyType: .daily)
        context.insert(habit)
        let log = HabitLog(date: .now, value: 1)
        log.habit = habit
        context.insert(log)
        let entry = JournalEntry(date: .now, content: "今天还行")
        context.insert(entry)
        let photo = JournalPhoto(photoData: Data([0xFF]), thumbnailData: Data([0xF0]))
        photo.journalEntry = entry
        context.insert(photo)
        context.insert(WorkoutLog(workoutType: .running, durationMinutes: 30))
        context.insert(BodyMeasurement(weightKg: 70))
        context.insert(BowelLog())
        context.insert(NutritionGoal())
        context.insert(AIChatMessage(role: "user", content: "喝了杯水"))
        try context.save()
        return settings
    }

    func testClearAllDataRemovesEveryEntityIncludingTheDrinkLibrary() throws {
        let (container, context) = try makeStore()
        let settings = try seed(context)

        let summary = try SettingsDataCoordinator.clearAllData(modelContext: context, currentSettings: settings)

        XCTAssertGreaterThanOrEqual(summary.totalRecords, 14, "清空统计必须覆盖每一类实体")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DrinkRecord>()), 0, "「清空所有数据」不能漏掉饮品知识库")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SupplementRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WaterLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserFood>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealTemplate>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalPhoto>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyMeasurement>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BowelLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<NutritionGoal>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AIChatMessage>()), 0)

        // The settings row itself is reset, not deleted, per the documented behaviour.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserSettings>()), 1)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertFalse(settings.isHealthKitEnabled)
        XCTAssertFalse(settings.isAIConfigured)
    }

    func testClearingInvalidatesTheInMemoryLibraryIndexes() throws {
        let (container, context) = try makeStore()
        let settings = try seed(context)

        DrinkLibraryIndex.shared.rebuildIfNeeded(using: context)
        XCTAssertEqual(DrinkLibraryIndex.shared.count, 1)

        _ = try SettingsDataCoordinator.clearAllData(modelContext: context, currentSettings: settings)

        DrinkLibraryIndex.shared.rebuildIfNeeded(using: context)
        XCTAssertEqual(DrinkLibraryIndex.shared.count, 0, "清空后同一会话不得再返回旧饮品条目")

        SupplementLibraryIndex.shared.rebuildIfNeeded(using: context)
        XCTAssertEqual(SupplementLibraryIndex.shared.count, 0)
    }

    func testClearSummaryNamesWhatWasDeleted() throws {
        let (container, context) = try makeStore()
        let settings = try seed(context)

        let summary = try SettingsDataCoordinator.clearAllData(modelContext: context, currentSettings: settings)

        XCTAssertTrue(summary.detailText.contains("饮品库 1"), summary.detailText)
        XCTAssertTrue(summary.detailText.contains("餐食 1"), summary.detailText)
    }
}
