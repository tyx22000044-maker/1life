import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func installDefaultsIfNeeded(
        settings: [UserSettings],
        context: ModelContext
    ) {
        if settings.isEmpty {
            context.insert(UserSettings(hasCompletedOnboarding: false))
        }
    }

    static func installDefaultNutritionGoalIfNeeded(
        goals: [NutritionGoal],
        context: ModelContext
    ) {
        if goals.isEmpty {
            context.insert(NutritionGoal())
        }
    }
}
