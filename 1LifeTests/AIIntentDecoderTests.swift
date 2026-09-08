import XCTest
@testable import OneLife

@MainActor
final class AIIntentDecoderTests: XCTestCase {
    private let decoder = AIIntentDecoder()

    func testDecodesChatIntent() throws {
        let json = #"{"intent":"chat","response":"你好"}"#
        guard case .chat(let text) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected chat")
        }
        XCTAssertEqual(text, "你好")
    }

    func testDecodesAddWaterWithDefaultAmount() throws {
        let json = #"{"intent":"add_water"}"#
        guard case .addWater(let amount) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addWater")
        }
        XCTAssertEqual(amount, 250)
    }

    func testDecodesAddWaterWithExplicitAmount() throws {
        let json = #"{"intent":"add_water","amount":300}"#
        guard case .addWater(let amount) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addWater")
        }
        XCTAssertEqual(amount, 300)
    }

    func testDecodesAddJournalWithMoodAndTags() throws {
        let json = #"{"intent":"add_journal","content":"今天很好","mood":"happy","tags":["stress","work"]}"#
        guard case .addJournal(let content, let mood, let tags) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addJournal")
        }
        XCTAssertEqual(content, "今天很好")
        XCTAssertEqual(mood, .happy)
        XCTAssertEqual(tags, [.stress, .work])
    }

    func testDecodesAddHabitLog() throws {
        let json = #"{"intent":"add_habit_log","habit_name":"喝水","value":2}"#
        guard case .addHabitLog(let name, let value) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addHabitLog")
        }
        XCTAssertEqual(name, "喝水")
        XCTAssertEqual(value, 2)
    }

    func testDecodesAddWorkout() throws {
        let json = #"{"intent":"add_workout","workout_type":"running","duration_minutes":40,"calories_burned":350,"intensity":"high","note":"晨跑"}"#
        guard case .addWorkout(let workout) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addWorkout")
        }
        XCTAssertEqual(workout.workoutType, .running)
        XCTAssertEqual(workout.durationMinutes, 40)
        XCTAssertEqual(workout.caloriesBurned, 350)
        XCTAssertEqual(workout.intensity, .high)
        XCTAssertEqual(workout.note, "晨跑")
    }

    func testDecodesAddBodyMeasurement() throws {
        let json = #"{"intent":"add_body_measurement","weight_kg":68.2,"body_fat_percentage":18.5,"note":"早上称重"}"#
        guard case .addBodyMeasurement(let measurement) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addBodyMeasurement")
        }
        XCTAssertEqual(measurement.weightKg ?? -1, 68.2, accuracy: 0.0001)
        XCTAssertEqual(measurement.bodyFatPercentage ?? -1, 18.5, accuracy: 0.0001)
    }

    func testDecodesAddBowelLog() throws {
        let json = #"{"intent":"add_bowel_log","bristol_type":"soft","note":"正常"}"#
        guard case .addBowelLog(let log) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addBowelLog")
        }
        XCTAssertEqual(log.bristolType, .soft)
        XCTAssertEqual(log.note, "正常")
    }

    func testDecodesSingleMealWithSnakeCaseNutrientKeys() throws {
        let json = #"""
        {"intent":"add_meal","meal_type":"breakfast","note":"简单早餐","items":[
            {"name":"燕麦", "amount":50, "unit":"g", "calories":180, "protein":6, "vitamin_a":120, "tea_polyphenols":30, "nutrition_data_basis":"per100g"}
        ]}
        """#
        guard case .addMeal(let meal) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addMeal")
        }
        XCTAssertEqual(meal.mealType, .breakfast)
        let item = try XCTUnwrap(meal.items.first)
        XCTAssertEqual(item.name, "燕麦")
        XCTAssertEqual(item.calories, 180)
        XCTAssertEqual(item.vitaminA ?? -1, 120, accuracy: 0.0001)
        XCTAssertEqual(item.teaPolyphenols ?? -1, 30, accuracy: 0.0001)
        XCTAssertEqual(item.nutritionDataBasis, .per100g)
    }

    func testDecodesMultipleMealsArray() throws {
        let json = #"""
        {"intent":"add_meals","meals":[
            {"meal_type":"breakfast","items":[{"name":"燕麦","calories":180}]},
            {"meal_type":"lunch","items":[{"name":"鸡胸肉","calories":250}]}
        ]}
        """#
        guard case .addMeals(let meals) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addMeals")
        }
        XCTAssertEqual(meals.count, 2)
        XCTAssertEqual(meals.map(\.mealType), [.breakfast, .lunch])
    }

    func testSingleEntryMealsArrayCollapsesToAddMeal() throws {
        let json = #"""
        {"intent":"add_meals","meals":[
            {"meal_type":"dinner","items":[{"name":"米饭","calories":200}]}
        ]}
        """#
        guard case .addMeal(let meal) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected addMeal (collapsed from single-element array)")
        }
        XCTAssertEqual(meal.mealType, .dinner)
    }

    func testDecodesCreateTemplate() throws {
        let json = #"""
        {"intent":"create_template","template_name":"简单早餐","meal_type":"breakfast","items":[
            {"name":"燕麦","amount":50,"unit":"g","calories":180}
        ]}
        """#
        guard case .createTemplate(let name, let meal) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected createTemplate")
        }
        XCTAssertEqual(name, "简单早餐")
        XCTAssertEqual(meal.mealType, .breakfast)
        XCTAssertEqual(meal.items.first?.name, "燕麦")
    }

    func testCreateTemplateWithoutNameFails() {
        let json = #"""
        {"intent":"create_template","items":[{"name":"燕麦","calories":180}]}
        """#
        XCTAssertNil(decoder.decode(from: json))
    }

    func testDecodesBatchOfMultipleActions() throws {
        let json = #"""
        {"intent":"batch","actions":[
            {"intent":"add_water","amount":300},
            {"intent":"chat","response":"记好啦"}
        ]}
        """#
        guard case .batch(let actions) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected batch")
        }
        XCTAssertEqual(actions.count, 2)
    }

    func testSingleActionBatchCollapses() throws {
        let json = #"""
        {"intent":"batch","actions":[{"intent":"add_water","amount":300}]}
        """#
        guard case .addWater(let amount) = try XCTUnwrap(decoder.decode(from: json)) else {
            return XCTFail("expected the single batch action to collapse to addWater")
        }
        XCTAssertEqual(amount, 300)
    }

    func testDecodesFitnessQueryIntents() throws {
        guard case .fitnessSummary = try XCTUnwrap(decoder.decode(from: #"{"intent":"get_fitness_summary"}"#)) else {
            return XCTFail("expected fitnessSummary")
        }
        guard case .energyAnalysis = try XCTUnwrap(decoder.decode(from: #"{"intent":"get_energy_analysis"}"#)) else {
            return XCTFail("expected energyAnalysis")
        }
        guard case .postWorkoutNutritionAdvice = try XCTUnwrap(decoder.decode(from: #"{"intent":"get_post_workout_nutrition_advice"}"#)) else {
            return XCTFail("expected postWorkoutNutritionAdvice")
        }
    }

    func testUnknownIntentFallsBackToChatWithOriginalText() throws {
        let raw = #"{"intent":"do_something_unsupported"}"#
        guard case .chat(let text) = try XCTUnwrap(decoder.decode(from: raw)) else {
            return XCTFail("expected chat fallback")
        }
        XCTAssertEqual(text, raw)
    }

    func testExtractsJSONEmbeddedInSurroundingProse() throws {
        let text = #"这是结果：{"intent":"chat","response":"OK"} 谢谢"#
        guard case .chat(let reply) = try XCTUnwrap(decoder.decode(from: text)) else {
            return XCTFail("expected chat")
        }
        XCTAssertEqual(reply, "OK")
    }

    func testNonJSONTextReturnsNil() {
        XCTAssertNil(decoder.decode(from: "这不是 JSON"))
    }

    func testAddMealWithoutItemsReturnsNil() {
        let json = #"{"intent":"add_meal","meal_type":"breakfast"}"#
        XCTAssertNil(decoder.decode(from: json))
    }

    func testFoodItemWithoutNameIsFilteredOut() {
        let json = #"""
        {"intent":"add_meal","meal_type":"breakfast","items":[{"calories":100}]}
        """#
        XCTAssertNil(decoder.decode(from: json))
    }
}
