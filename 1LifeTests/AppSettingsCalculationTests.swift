import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class AppSettingsCalculationTests: XCTestCase {
    private func makeSettings(
        dietGoalMode: DietGoalMode = .balanced,
        gender: Gender? = .male,
        age: Int? = 30,
        heightCm: Double? = 175,
        weightKg: Double? = 70,
        activityLevel: ActivityLevel? = .moderatelyActive
    ) -> UserSettings {
        let settings = UserSettings(dietGoalMode: dietGoalMode)
        settings.genderRaw = gender?.rawValue
        settings.age = age
        settings.heightCm = heightCm
        settings.weightKg = weightKg
        settings.activityLevelRaw = activityLevel?.rawValue
        return settings
    }

    func testEstimatedBMRAndTDEENilWithoutBodyParameters() {
        let settings = makeSettings(gender: nil, age: nil, heightCm: nil, weightKg: nil, activityLevel: nil)
        XCTAssertNil(settings.estimatedBMR)
        XCTAssertNil(settings.estimatedTDEE)
        XCTAssertFalse(settings.hasBodyParameters)
    }

    func testEstimatedBMRAndTDEEForMale() {
        let settings = makeSettings()
        let expectedBMR: Double = 10 * 70 + 6.25 * 175 - 5 * 30 + 5
        XCTAssertEqual(settings.estimatedBMR ?? -1, expectedBMR, accuracy: 0.0001)
        XCTAssertEqual(settings.estimatedTDEE ?? -1, expectedBMR * ActivityLevel.moderatelyActive.multiplier, accuracy: 0.0001)
        XCTAssertTrue(settings.hasBodyParameters)
    }

    func testCalorieTargetMultiplierUsesCustomWhenEnabled() {
        let settings = makeSettings()
        XCTAssertEqual(settings.calorieTargetMultiplier, DietGoalMode.balanced.calorieMultiplier, accuracy: 0.0001)

        settings.useCustomCalorieMultiplier = true
        settings.customCalorieMultiplier = 0.75
        XCTAssertEqual(settings.calorieTargetMultiplier, 0.75, accuracy: 0.0001)

        // Custom multiplier is clamped to a sane floor.
        settings.customCalorieMultiplier = 0
        XCTAssertEqual(settings.calorieTargetMultiplier, 0.1, accuracy: 0.0001)
    }

    func testCalorieTargetFallsBackTo2000WhenNoTDEEAvailable() {
        let settings = makeSettings(gender: nil, age: nil, heightCm: nil, weightKg: nil, activityLevel: nil)
        XCTAssertEqual(settings.calorieTarget(from: nil), 2000 * settings.calorieTargetMultiplier, accuracy: 0.0001)
        XCTAssertEqual(settings.calorieTarget(from: 1800), 1800 * settings.calorieTargetMultiplier, accuracy: 0.0001)
    }

    func testRecommendedMacroTargetsUsesRatioStrategyByDefault() {
        let macros = UserSettings.recommendedMacroTargets(
            calories: 2000,
            weightKg: 70,
            dietGoalMode: .balanced,
            proteinTargetStrategy: .macroRatio,
            proteinTargetMultiplier: 1.2
        )
        XCTAssertEqual(macros.protein, 2000 * 0.15 / 4, accuracy: 0.0001)
        XCTAssertEqual(macros.carbs, 2000 * 0.60 / 4, accuracy: 0.0001)
        XCTAssertEqual(macros.fat, 2000 * 0.25 / 9, accuracy: 0.0001)
    }

    func testRecommendedMacroTargetsUsesBodyWeightStrategyWhenAvailable() {
        let macros = UserSettings.recommendedMacroTargets(
            calories: 2000,
            weightKg: 70,
            dietGoalMode: .balanced,
            proteinTargetStrategy: .bodyWeight,
            proteinTargetMultiplier: 1.2
        )
        let expectedProtein = 70.0 * 1.2
        XCTAssertEqual(macros.protein, expectedProtein, accuracy: 0.0001)
        let remaining = 2000 - expectedProtein * 4
        let carbShare = 0.60 / (0.60 + 0.25)
        let fatShare = 0.25 / (0.60 + 0.25)
        XCTAssertEqual(macros.carbs, remaining * carbShare / 4, accuracy: 0.0001)
        XCTAssertEqual(macros.fat, remaining * fatShare / 9, accuracy: 0.0001)
    }

    func testRecommendedMacroTargetsFallsBackToRatioWhenWeightMissingDespiteBodyWeightStrategy() {
        let macros = UserSettings.recommendedMacroTargets(
            calories: 2000,
            weightKg: nil,
            dietGoalMode: .balanced,
            proteinTargetStrategy: .bodyWeight,
            proteinTargetMultiplier: 1.2
        )
        XCTAssertEqual(macros.protein, 2000 * 0.15 / 4, accuracy: 0.0001)
    }

    func testEffectiveTargetUsesGoalWhenNotDynamic() {
        let settings = makeSettings()
        settings.useHealthKitForDynamicTDEE = false
        let goal = NutritionGoal(dailyCalories: 1800, dailyProtein: 120, dailyCarbs: 150, dailyFat: 60, dailyFiber: 30)

        let target = settings.effectiveTarget(healthTDEE: nil, goal: goal)
        XCTAssertFalse(target.isDynamic)
        XCTAssertEqual(target.calories, 1800, accuracy: 0.0001)
        XCTAssertEqual(target.protein, 120, accuracy: 0.0001)
        XCTAssertEqual(target.fiber, 30, accuracy: 0.0001)
    }

    func testEffectiveTargetIsDynamicWhenHealthKitTDEEProvided() {
        let settings = makeSettings()
        settings.useHealthKitForDynamicTDEE = true
        let goal = NutritionGoal(dailyCalories: 1800, dailyProtein: 120, dailyCarbs: 150, dailyFat: 60)

        let target = settings.effectiveTarget(healthTDEE: 2500, goal: goal)
        XCTAssertTrue(target.isDynamic)
        XCTAssertEqual(target.calories, 2500 * settings.calorieTargetMultiplier, accuracy: 0.0001)
        // Dynamic mode only changes calories; saved macro goals remain stable.
        XCTAssertEqual(target.protein, 120, accuracy: 0.0001)
        XCTAssertEqual(target.carbs, 150, accuracy: 0.0001)
        XCTAssertEqual(target.fat, 60, accuracy: 0.0001)
    }

    func testEffectiveTargetValueForKeyMatchesFields() {
        let settings = makeSettings()
        let target = settings.effectiveTarget(healthTDEE: nil, goal: nil)
        XCTAssertEqual(target.value(for: .protein), target.protein)
        XCTAssertEqual(target.value(for: .vitaminC), target.vitaminC)
    }

    // MARK: - Calorie target provenance

    func testTargetWithoutBodyParametersIsLabelledGenericReference() {
        let settings = UserSettings(hasCompletedOnboarding: true)
        let target = settings.effectiveTarget(healthTDEE: nil, goal: NutritionGoal())

        XCTAssertEqual(target.calories, 2000, accuracy: 0.0001)
        XCTAssertEqual(target.caloriesProvenance, .genericReference)
        XCTAssertTrue(target.caloriesProvenance.isGenericReference)
    }

    func testStoredGoalIsReportedAndMissingGoalFallsBackToTheEstimate() {
        let settings = UserSettings(
            genderRaw: Gender.male.rawValue, age: 30, heightCm: 175, weightKg: 75,
            activityLevelRaw: ActivityLevel.moderatelyActive.rawValue
        )

        let withGoal = settings.effectiveTarget(healthTDEE: nil, goal: NutritionGoal(dailyCalories: 2000))
        XCTAssertEqual(withGoal.caloriesProvenance, .savedGoal)
        XCTAssertEqual(withGoal.calories, 2000, accuracy: 0.0001)

        let withoutGoal = settings.effectiveTarget(healthTDEE: nil, goal: nil)
        XCTAssertEqual(withoutGoal.caloriesProvenance, .bodyParameterEstimate)
        XCTAssertEqual(withoutGoal.calories, settings.recommendedCalories, accuracy: 0.0001)
    }

    func testExplicitlyEditedGoalIsReportedAsSavedGoal() {
        let settings = UserSettings(
            genderRaw: Gender.male.rawValue, age: 30, heightCm: 175, weightKg: 75,
            activityLevelRaw: ActivityLevel.moderatelyActive.rawValue
        )
        let goal = NutritionGoal(dailyCalories: 3200)
        let target = settings.effectiveTarget(healthTDEE: nil, goal: goal)

        XCTAssertEqual(target.caloriesProvenance, .savedGoal)
        XCTAssertEqual(target.calories, 3200, accuracy: 0.0001)
    }

    func testHealthKitDynamicTdeeWinsAndIsLabelled() {
        let settings = UserSettings(
            genderRaw: Gender.male.rawValue, age: 30, heightCm: 175, weightKg: 75,
            activityLevelRaw: ActivityLevel.moderatelyActive.rawValue
        )
        settings.useCustomCalorieMultiplier = false
        let target = settings.effectiveTarget(healthTDEE: 2600, goal: NutritionGoal())
        _ = target
        settings.useHealthKitForDynamicTDEE = true
        let dynamic = settings.effectiveTarget(healthTDEE: 2600, goal: NutritionGoal())

        XCTAssertEqual(dynamic.caloriesProvenance, .healthKitDynamic)
        XCTAssertTrue(dynamic.isDynamic)
    }
}
