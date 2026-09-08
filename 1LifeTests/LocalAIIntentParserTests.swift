import XCTest
@testable import OneLife

@MainActor
final class LocalAIIntentParserTests: XCTestCase {
    func testParsesWorkoutWithDurationAndCalories() throws {
        let parser = LocalAIIntentParser()
        let result = parser.parse("今天跑步跑了35分钟，消耗300千卡")
        guard case .addWorkout(let workout) = try XCTUnwrap(result) else {
            return XCTFail("expected addWorkout")
        }
        XCTAssertEqual(workout.workoutType, .running)
        XCTAssertEqual(workout.durationMinutes, 35)
        XCTAssertEqual(workout.caloriesBurned, 300)
        XCTAssertEqual(workout.intensity, .moderate)
    }

    func testWorkoutKeywordWithoutActionVerbDoesNotMatch() {
        let parser = LocalAIIntentParser()
        XCTAssertNil(parser.parse("跑步鞋很贵"))
    }

    func testFitnessSummaryQueryFallsThroughFromWorkoutCheck() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("本周训练情况如何"))
        guard case .fitnessSummary = result else {
            return XCTFail("expected fitnessSummary, got \(result)")
        }
    }

    func testParsesBowelLog() throws {
        let parser = LocalAIIntentParser()
        let result = parser.parse("今天拉了，比较稀")
        guard case .addBowelLog(let log) = try XCTUnwrap(result) else {
            return XCTFail("expected addBowelLog")
        }
        XCTAssertEqual(log.bristolType, .loose)
    }

    func testParsesBodyMeasurementWeightOnly() throws {
        let parser = LocalAIIntentParser()
        let result = parser.parse("今天称了体重是65.5kg")
        guard case .addBodyMeasurement(let measurement) = try XCTUnwrap(result) else {
            return XCTFail("expected addBodyMeasurement")
        }
        XCTAssertEqual(measurement.weightKg ?? -1, 65.5, accuracy: 0.0001)
        XCTAssertNil(measurement.bodyFatPercentage)
    }

    func testParsesPlainWaterCup() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("喝了一杯水"))
        guard case .addWater(let amount) = result else {
            return XCTFail("expected addWater, got \(result)")
        }
        XCTAssertEqual(amount, 250)
    }

    func testParsesWaterBottle() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("喝了一瓶水"))
        guard case .addWater(let amount) = result else {
            return XCTFail("expected addWater, got \(result)")
        }
        XCTAssertEqual(amount, 500)
    }

    func testParsesExplicitWaterVolume() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("喝了500ml水"))
        guard case .addWater(let amount) = result else {
            return XCTFail("expected addWater, got \(result)")
        }
        XCTAssertEqual(amount, 500)
    }

    func testBeverageTextIsNotTreatedAsPlainWater() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("喝了一杯奶茶"))
        guard case .addMeal(let meal) = result else {
            return XCTFail("expected addMeal for a beverage, got \(result)")
        }
        XCTAssertEqual(meal.mealType, .snack)
        XCTAssertEqual(meal.items.first?.name, "奶茶")
    }

    func testMealTemplateMatchByName() throws {
        let template = MealTemplate(name: "健身餐", mealType: .lunch, foodItems: [
            TemplateFoodItem(name: "鸡胸肉", amount: 150, unit: "g", servingGrams: 150, calories: 250, protein: 45)
        ])
        let parser = LocalAIIntentParser(mealTemplates: [template])
        let result = try XCTUnwrap(parser.parse("用了健身餐模板"))
        guard case .addMeal(let meal) = result else {
            return XCTFail("expected addMeal, got \(result)")
        }
        XCTAssertEqual(meal.mealType, .lunch)
        XCTAssertEqual(meal.items.count, 1)
        XCTAssertEqual(meal.items.first?.name, "鸡胸肉")
        XCTAssertEqual(meal.items.first?.calories, 250)
        XCTAssertTrue(meal.note.contains("健身餐"))
    }

    func testTemplateCreationRequestsAreNotInterceptedLocally() {
        let parser = LocalAIIntentParser()
        XCTAssertNil(parser.parse("帮我建一个早餐模板：鸡蛋2个+牛奶250ml"))
    }

    func testParsesMealUsingKnownUserFood() throws {
        let userFood = UserFood(name: "鸡胸肉", caloriesPer100g: 165, proteinPer100g: 31)
        let parser = LocalAIIntentParser(userFoods: [userFood])
        let result = try XCTUnwrap(parser.parse("午餐吃了鸡胸肉"))
        guard case .addMeal(let meal) = result else {
            return XCTFail("expected addMeal, got \(result)")
        }
        XCTAssertEqual(meal.mealType, .lunch)
        let item = try XCTUnwrap(meal.items.first)
        XCTAssertEqual(item.name, "鸡胸肉")
        XCTAssertEqual(item.calories, 165, accuracy: 0.0001)
        XCTAssertEqual(item.protein ?? -1, 31, accuracy: 0.0001)
        XCTAssertEqual(item.nutritionDataNote, "数据来源：我的食物")
    }

    func testParsesMealWithUnknownFoodAsZeroCalorieStub() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("早餐吃了三明治"))
        guard case .addMeal(let meal) = result else {
            return XCTFail("expected addMeal, got \(result)")
        }
        XCTAssertEqual(meal.mealType, .breakfast)
        XCTAssertEqual(meal.items.first?.name, "三明治")
        XCTAssertEqual(meal.items.first?.calories, 0)
    }

    func testJournalWithoutRecognizedMoodOrTags() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("心情不好"))
        guard case .addJournal(let content, let mood, let tags) = result else {
            return XCTFail("expected addJournal, got \(result)")
        }
        XCTAssertEqual(content, "心情不好")
        XCTAssertNil(mood)
        XCTAssertEqual(tags, [.other])
    }

    func testJournalDetectsHappyMood() throws {
        let parser = LocalAIIntentParser()
        let result = try XCTUnwrap(parser.parse("今天心情很好，很开心"))
        guard case .addJournal(_, let mood, _) = result else {
            return XCTFail("expected addJournal, got \(result)")
        }
        XCTAssertEqual(mood, .happy)
    }

    func testEmptyInputReturnsNil() {
        let parser = LocalAIIntentParser()
        XCTAssertNil(parser.parse("   "))
    }
}
