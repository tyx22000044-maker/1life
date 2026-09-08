import XCTest
@testable import OneLife

@MainActor
final class NutritionServiceTests: XCTestCase {
    private let calendar = Calendar.current

    private func referenceDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 20
        components.hour = 13
        return calendar.date(from: components)!
    }

    private func makeMeal(date: Date, type: MealType, items: [FoodItem], createdAt: Date? = nil) -> Meal {
        let meal = Meal(date: date, mealType: type)
        meal.foodItems = items
        return meal
    }

    private func makeFoodItem(name: String, calories: Double, protein: Double? = nil) -> FoodItem {
        FoodItem(name: name, amount: 100, servingGrams: 100, calories: calories, protein: protein)
    }

    func testDailySummaryAggregatesOnlyMatchingDay() {
        let today = referenceDate()
        let yesterday = day(-1, from: today)

        let todayMeal = makeMeal(date: today, type: .lunch, items: [
            makeFoodItem(name: "Rice", calories: 200, protein: 5),
            makeFoodItem(name: "Chicken", calories: 300, protein: 30)
        ])
        let yesterdayMeal = makeMeal(date: yesterday, type: .dinner, items: [makeFoodItem(name: "Old", calories: 999)])

        let waterToday = WaterLog(date: today, amount: 250)
        let waterYesterday = WaterLog(date: yesterday, amount: 500)

        let summary = NutritionService.dailySummary(meals: [todayMeal, yesterdayMeal], waterLogs: [waterToday, waterYesterday], for: today)

        XCTAssertEqual(summary.totalCalories, 500, accuracy: 0.0001)
        XCTAssertEqual(summary.totalProtein ?? -1, 35, accuracy: 0.0001)
        XCTAssertEqual(summary.mealCount, 1)
        XCTAssertEqual(summary.foodItemCount, 2)
        XCTAssertEqual(summary.totalWaterMl, 250, accuracy: 0.0001)
    }

    func testDailySummaryNutrientIsNilWhenNoItemProvidesIt() {
        let today = referenceDate()
        let meal = makeMeal(date: today, type: .breakfast, items: [makeFoodItem(name: "Mystery", calories: 100, protein: nil)])
        let summary = NutritionService.dailySummary(meals: [meal], waterLogs: [], for: today)
        XCTAssertNil(summary.totalProtein)
    }

    func testDailySummaryPreservesOptionalNutrientsAcrossMixedItems() {
        let today = referenceDate()
        let meal = makeMeal(date: today, type: .breakfast, items: [
            makeFoodItem(name: "Known", calories: 100, protein: 10),
            makeFoodItem(name: "Partial", calories: 50, protein: nil)
        ])

        let summary = NutritionService.dailySummary(meals: [meal], waterLogs: [], for: today)

        XCTAssertEqual(summary.totalCalories, 150, accuracy: 0.0001)
        XCTAssertEqual(summary.totalProtein ?? -1, 10, accuracy: 0.0001)
    }

    func testMealSummariesSortByMealTypeThenCreation() {
        let today = referenceDate()
        let dinner = makeMeal(date: today, type: .dinner, items: [makeFoodItem(name: "D", calories: 100)])
        let breakfast = makeMeal(date: today, type: .breakfast, items: [makeFoodItem(name: "B", calories: 50)])
        let lunch = makeMeal(date: today, type: .lunch, items: [makeFoodItem(name: "L", calories: 75)])

        let summaries = NutritionService.mealSummaries(meals: [dinner, breakfast, lunch], for: today)
        XCTAssertEqual(summaries.map(\.mealType), [.breakfast, .lunch, .dinner])
    }

    func testBMRFormulasDifferByGender() {
        let male = NutritionService.bmr(gender: .male, weightKg: 70, heightCm: 175, age: 30)
        XCTAssertEqual(male, 10 * 70 + 6.25 * 175 - 5 * 30 + 5, accuracy: 0.0001)

        let female = NutritionService.bmr(gender: .female, weightKg: 60, heightCm: 165, age: 28)
        XCTAssertEqual(female, 10 * 60 + 6.25 * 165 - 5 * 28 - 161, accuracy: 0.0001)
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date)!
    }
}
