import XCTest
@testable import OneLife

@MainActor
final class BackupRecordsTests: XCTestCase {
    // MARK: - FoodItem round trip

    func testFoodItemRecordPreservesIdAndNutritionFieldsThroughModelReconstruction() throws {
        let original = FoodItem(name: "鸡胸肉", amount: 150, servingGrams: 150, calories: 250, protein: 45, carbs: 0, fat: 5)
        let record = FoodItemRecord(original)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(FoodItemRecord.self, from: data)
        let rebuilt = decoded.model()

        XCTAssertEqual(rebuilt.id, original.id)
        XCTAssertEqual(rebuilt.name, original.name)
        XCTAssertEqual(rebuilt.calories, original.calories)
        XCTAssertEqual(rebuilt.protein, original.protein)
    }

    // MARK: - Meal capture preserves nested food items

    func testMealRecordCapturesNestedFoodItems() {
        let meal = Meal(mealType: .lunch)
        meal.foodItems = [
            FoodItem(name: "米饭", amount: 200, servingGrams: 200, calories: 260),
            FoodItem(name: "青菜", amount: 100, servingGrams: 100, calories: 30)
        ]
        let record = MealRecord(meal)
        XCTAssertEqual(record.foodItems.count, 2)
        XCTAssertEqual(record.foodItems.map(\.name), ["米饭", "青菜"])
    }

    func testMealRecordModelPreservesTopLevelIdentity() throws {
        let meal = Meal(mealType: .dinner, note: "在家吃")
        let record = MealRecord(meal)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(MealRecord.self, from: data)
        let rebuilt = decoded.model()

        XCTAssertEqual(rebuilt.id, meal.id)
        XCTAssertEqual(rebuilt.mealType, .dinner)
        XCTAssertEqual(rebuilt.note, "在家吃")
    }

    // MARK: - Habit + HabitLog

    func testHabitRecordCapturesNestedLogs() {
        let habit = Habit(name: "喝水", frequencyType: .daily)
        habit.logs = [HabitLog(value: 1), HabitLog(value: 1)]
        let record = HabitRecord(habit)
        XCTAssertEqual(record.logs.count, 2)
    }

    func testHabitRecordModelPreservesIdentity() throws {
        let habit = Habit(name: "冥想", iconSymbol: "leaf", colorHex: "22AA55", targetCount: 10)
        let record = HabitRecord(habit)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HabitRecord.self, from: data)
        let rebuilt = decoded.model()

        XCTAssertEqual(rebuilt.id, habit.id)
        XCTAssertEqual(rebuilt.name, "冥想")
        XCTAssertEqual(rebuilt.targetCount, 10)
    }

    func testHabitLogRecordModelPreservesIdentity() throws {
        let log = HabitLog(value: 2)
        let record = HabitLogRecord(log)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HabitLogRecord.self, from: data)
        let rebuilt = decoded.model()

        XCTAssertEqual(rebuilt.id, log.id)
        XCTAssertEqual(rebuilt.value, 2)
    }

    // MARK: - WaterLog

    func testWaterRecordRoundTrip() throws {
        let log = WaterLog(amount: 300)
        let record = WaterRecord(log)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(WaterRecord.self, from: data)
        let rebuilt = decoded.model()

        XCTAssertEqual(rebuilt.id, log.id)
        XCTAssertEqual(rebuilt.amount, 300)
    }

    // MARK: - BackupFile envelope

    func testBackupFileEncodesAndDecodesTopLevelCounts() throws {
        let meal = Meal(mealType: .breakfast)
        let file = BackupFile(
            version: 2,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            settings: nil,
            nutritionGoals: [],
            meals: [MealRecord(meal)],
            waterLogs: [WaterRecord(WaterLog(amount: 250))],
            habits: [],
            journalEntries: [],
            workouts: [],
            bodyMeasurements: [],
            bowelLogs: [],
            userFoods: [],
            mealTemplates: [],
            chatMessages: []
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(BackupFile.self, from: data)

        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.exportedAt, file.exportedAt)
        XCTAssertEqual(decoded.meals.count, 1)
        XCTAssertEqual(decoded.waterLogs.count, 1)
        XCTAssertNil(decoded.settings)
    }

    func testBackupFileToleratesMissingOptionalArrayKeys() throws {
        // Older/partial payloads may omit array keys entirely; the custom decoder must default them to [].
        let json = #"{"version":2,"exportedAt":719258400}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BackupFile.self, from: data)

        XCTAssertEqual(decoded.version, 2)
        XCTAssertTrue(decoded.meals.isEmpty)
        XCTAssertTrue(decoded.habits.isEmpty)
        XCTAssertTrue(decoded.drinkRecords.isEmpty)
        XCTAssertTrue(decoded.supplementRecords.isEmpty)
        XCTAssertNil(decoded.settings)
    }

    // MARK: - DrinkRecord knowledge base

    func testDrinkRecordRoundTripPreservesLibraryFieldsAndTimestamps() throws {
        let original = DrinkRecord(
            brand: "喜茶",
            productName: "多肉葡萄",
            sizeML: 650,
            sugarLevel: "七分糖",
            toppings: "珍珠",
            calories: 320,
            protein: 3,
            carbs: 55,
            fat: 9,
            sugar: 44,
            sodium: 120,
            caffeine: 90,
            teaPolyphenols: 210,
            sourceNote: "官方小程序",
            sourceDate: Date(timeIntervalSince1970: 1_700_000_000),
            confidence: .high
        )
        let record = DrinkRecordBackupRecord(original)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(DrinkRecordBackupRecord.self, from: data)
        let rebuilt = decoded.model()

        XCTAssertEqual(rebuilt.id, original.id)
        XCTAssertEqual(rebuilt.brand, "喜茶")
        XCTAssertEqual(rebuilt.productName, "多肉葡萄")
        XCTAssertEqual(rebuilt.sizeML, 650)
        XCTAssertEqual(rebuilt.sugarLevel, "七分糖")
        XCTAssertEqual(rebuilt.toppings, "珍珠")
        XCTAssertEqual(rebuilt.calories, 320)
        XCTAssertEqual(rebuilt.sugar, 44)
        XCTAssertEqual(rebuilt.caffeine, 90)
        XCTAssertEqual(rebuilt.teaPolyphenols, 210)
        XCTAssertEqual(rebuilt.sourceNote, "官方小程序")
        XCTAssertEqual(rebuilt.sourceDate, original.sourceDate)
        XCTAssertEqual(rebuilt.confidence, .high)
        XCTAssertEqual(rebuilt.createdAt, original.createdAt)
        XCTAssertEqual(rebuilt.updatedAt, original.updatedAt)
    }

    func testBackupFileCarriesDrinkRecordsThroughEncodeDecode() throws {
        let drink = DrinkRecord(brand: "Manner", productName: "冰美式", sizeML: 473, calories: 15, caffeine: 190)
        let file = BackupFile(
            version: 8,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            settings: nil,
            nutritionGoals: [],
            meals: [],
            waterLogs: [],
            habits: [],
            journalEntries: [],
            workouts: [],
            bodyMeasurements: [],
            bowelLogs: [],
            userFoods: [],
            mealTemplates: [],
            chatMessages: [],
            drinkRecords: [DrinkRecordBackupRecord(drink)]
        )

        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(BackupFile.self, from: data)

        XCTAssertEqual(decoded.version, 8)
        XCTAssertEqual(decoded.drinkRecords.count, 1)
        XCTAssertEqual(decoded.drinkRecords.first?.model().displayName, "Manner 冰美式（473ml）")
    }
}
