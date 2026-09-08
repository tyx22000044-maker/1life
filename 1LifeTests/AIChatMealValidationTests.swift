import XCTest
@testable import OneLife

final class AIChatMealValidationTests: XCTestCase {
    private func item(
        name: String = "测试食物",
        calories: Double,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        confidence: String? = nil,
        nutritionDataBasis: NutritionDataBasis = .estimated,
        nutritionDataNote: String? = nil,
        amount: Double = 100
    ) -> AIParsedFoodItem {
        var draft = AIParsedFoodItem(name: name, amount: amount, unit: "g", calories: calories, protein: protein, carbs: carbs, fat: fat)
        draft.confidence = confidence
        draft.nutritionDataBasis = nutritionDataBasis
        draft.nutritionDataNote = nutritionDataNote
        return draft
    }

    // MARK: - applySanityReview: macro/calorie consistency

    func testConsistentMacrosAreLeftUnflagged() {
        // 30g protein + 40g carbs + 10g fat ≈ 370 kcal, close enough to the stated 350 kcal.
        let meal = AIParsedMeal(mealType: .lunch, items: [item(calories: 350, protein: 30, carbs: 40, fat: 10)], note: "")
        let reviewed = AIChatMealValidation.applySanityReview(to: meal)
        let result = reviewed.items[0]
        XCTAssertNotEqual(result.confidence, "low")
        XCTAssertNil(result.caloriesMin)
        XCTAssertNil(result.caloriesMax)
    }

    func testGrosslyInconsistentMacrosAreFlaggedLowConfidence() {
        // 50g protein + 50g carbs + 50g fat ≈ 850 kcal vs a stated 100 kcal — way off.
        let meal = AIParsedMeal(mealType: .lunch, items: [item(calories: 100, protein: 50, carbs: 50, fat: 50)], note: "")
        let reviewed = AIChatMealValidation.applySanityReview(to: meal)
        let result = reviewed.items[0]
        XCTAssertEqual(result.confidence, "low")
        XCTAssertEqual(result.caloriesMin ?? -1, 100, accuracy: 0.0001)
        XCTAssertEqual(result.caloriesMax ?? -1, 850, accuracy: 0.0001)
        XCTAssertTrue(result.nutritionDataNote?.contains("AI 自检") == true)
    }

    func testItemsMissingAnyMacroSkipTheSanityCheck() {
        let meal = AIParsedMeal(mealType: .lunch, items: [item(calories: 500, protein: nil, carbs: 40, fat: 10)], note: "")
        let reviewed = AIChatMealValidation.applySanityReview(to: meal)
        XCTAssertNil(reviewed.items[0].caloriesMin)
    }

    // MARK: - applySanityReview: unverified official-source note sanitization

    func testUnverifiedOfficialSourceClaimIsDowngradedToEstimate() {
        let meal = AIParsedMeal(
            mealType: .snack,
            items: [item(calories: 0, confidence: "high", nutritionDataBasis: .estimated, nutritionDataNote: "官方产品信息：官网数据")],
            note: ""
        )
        let reviewed = AIChatMealValidation.applySanityReview(to: meal)
        let result = reviewed.items[0]
        XCTAssertEqual(result.confidence, "medium")
        XCTAssertEqual(result.nutritionDataBasis, .estimated)
        XCTAssertEqual(result.nutritionDataNote, "数据来源：AI估算")
    }

    func testTrustedLocalSourceNoteIsNotSanitized() {
        let originalNote = "数据来源：饮品知识库（官方数据）"
        let meal = AIParsedMeal(
            mealType: .snack,
            items: [item(calories: 0, confidence: "high", nutritionDataBasis: .direct, nutritionDataNote: originalNote)],
            note: ""
        )
        let reviewed = AIChatMealValidation.applySanityReview(to: meal)
        let result = reviewed.items[0]
        XCTAssertEqual(result.confidence, "high")
        XCTAssertEqual(result.nutritionDataNote, originalNote)
    }

    // MARK: - normalizePhotoMealResult

    func testVerifiedHighConfidencePhotoItemIsLeftAsIs() {
        let verifiedItem = item(calories: 200, confidence: "high", nutritionDataBasis: .direct, amount: 100)
        let result = AIChatIntentResult.addMeal(AIParsedMeal(mealType: .lunch, items: [verifiedItem], note: "已核实"))
        guard case .addMeal(let meal) = AIChatMealValidation.normalizePhotoMealResult(result) else {
            return XCTFail("expected addMeal")
        }
        let normalized = meal.items[0]
        XCTAssertEqual(normalized.confidence, "high")
        XCTAssertNil(normalized.amountMin)
        XCTAssertNil(normalized.caloriesMin)
    }

    func testUnverifiedPhotoItemGetsPortionUncertaintyRange() {
        let unverifiedItem = item(calories: 300, confidence: nil, nutritionDataBasis: .estimated, amount: 200)
        let result = AIChatIntentResult.addMeal(AIParsedMeal(mealType: .lunch, items: [unverifiedItem], note: ""))
        guard case .addMeal(let meal) = AIChatMealValidation.normalizePhotoMealResult(result) else {
            return XCTFail("expected addMeal")
        }
        XCTAssertTrue(meal.note.contains("估算区间"))

        let normalized = meal.items[0]
        XCTAssertEqual(normalized.confidence, "low")
        XCTAssertEqual(normalized.amountMin ?? -1, 150, accuracy: 0.0001)
        XCTAssertEqual(normalized.amountMax ?? -1, 250, accuracy: 0.0001)
        XCTAssertEqual(normalized.caloriesMin ?? -1, 225, accuracy: 0.0001)
        XCTAssertEqual(normalized.caloriesMax ?? -1, 375, accuracy: 0.0001)
        XCTAssertTrue(normalized.nutritionDataNote?.contains("份量未由图片证实") == true)
    }

    func testNonMealIntentPassesThroughNormalizationUnchanged() {
        let result = AIChatIntentResult.chat("你好")
        guard case .chat(let text) = AIChatMealValidation.normalizePhotoMealResult(result) else {
            return XCTFail("expected chat to pass through unchanged")
        }
        XCTAssertEqual(text, "你好")
    }
}
