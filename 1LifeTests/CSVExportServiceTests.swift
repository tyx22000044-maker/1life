import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class CSVExportServiceTests: XCTestCase {
    private let calendar = Calendar.current

    private func referenceDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = 8
        return calendar.date(from: components)!
    }

    func testDetailCSVIncludesHeaderAndEscapesCommaInName() {
        let date = referenceDate()
        let meal = Meal(date: date, mealType: .breakfast)
        let item = FoodItem(name: "苹果,红富士", amount: 1, unit: "个", servingGrams: 150, calories: 80, protein: 0.5)
        meal.foodItems = [item]

        let csv = CSVExportService.exportCSV(
            settings: nil,
            meals: [meal],
            waterLogs: [],
            workouts: [],
            bodyMeasurements: [],
            bowelLogs: [],
            granularity: .detail
        )

        XCTAssertTrue(csv.contains("日期,时间,餐次,食物名称"))
        XCTAssertTrue(csv.contains("\"苹果,红富士\""))
        XCTAssertTrue(csv.contains("早餐"))
    }

    func testDailySummaryCSVAggregatesAcrossSources() {
        let date = referenceDate()
        let settings = UserSettings()
        settings.heightCm = 175

        let meal = Meal(date: date, mealType: .lunch)
        meal.foodItems = [
            FoodItem(name: "米饭", amount: 200, servingGrams: 200, calories: 100, protein: 10),
            FoodItem(name: "鸡胸肉", amount: 100, servingGrams: 100, calories: 50, protein: 5)
        ]

        let waterLogs = [WaterLog(date: date, amount: 250), WaterLog(date: date, amount: 250)]
        let training = WorkoutLog(startDate: date, durationMinutes: 30, caloriesBurned: 200)
        let restDay = WorkoutLog(startDate: date, isRestDay: true)
        let measurement = BodyMeasurement(date: date, weightKg: 70)
        let bowel = BowelLog(date: date, bristolType: .normal)

        let csv = CSVExportService.exportCSV(
            settings: settings,
            meals: [meal],
            waterLogs: waterLogs,
            workouts: [training, restDay],
            bodyMeasurements: [measurement],
            bowelLogs: [bowel],
            granularity: .dailySummary
        )

        XCTAssertTrue(csv.contains("总热量"))
        // Total calories (150), total protein (15), water (500ml)
        XCTAssertTrue(csv.contains(",150,15,"))
        XCTAssertTrue(csv.contains(",500,"))
        // BMI = 70 / 1.75^2 ≈ 22.86
        XCTAssertTrue(csv.contains("22.86"))
    }

    func testCSVFieldEscapesEmbeddedQuotes() {
        let date = referenceDate()
        let meal = Meal(date: date, mealType: .snack)
        meal.foodItems = [FoodItem(name: "\"特级\"苹果", amount: 1, servingGrams: 100, calories: 50)]

        let csv = CSVExportService.exportCSV(
            settings: nil,
            meals: [meal],
            waterLogs: [],
            workouts: [],
            bodyMeasurements: [],
            bowelLogs: [],
            granularity: .detail
        )

        XCTAssertTrue(csv.contains("\"\"\"特级\"\"苹果\""))
    }
}
