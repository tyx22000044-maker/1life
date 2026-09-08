import Foundation
import SwiftData

@MainActor
struct AIChatInsightReplyBuilder {
    static func fitnessSummary(modelContext: ModelContext?, settings: UserSettings?) -> String {
        guard let modelContext else { return "现在还没有可用训练数据。" }
        let workouts = ((try? modelContext.fetch(FetchDescriptor<WorkoutLog>())) ?? [])
        let targetCount = settings?.weeklyWorkoutTargetCount ?? 3
        let targetMinutes = settings?.weeklyWorkoutTargetMinutes ?? 150
        let weekly = WorkoutService.weeklySummary(workouts: workouts, targetCount: targetCount, targetMinutes: targetMinutes)
        let streak = WorkoutService.trainingStreak(workouts: workouts)
        let score = WorkoutService.consistencyScore(workouts: workouts)
        return "\(WorkoutService.weeklyReportText(weekly: weekly)) 当前连续训练 \(streak) 天，近 28 天稳定度 \(score)。"
    }

    static func energyAnalysis(modelContext: ModelContext?, settings: UserSettings?) -> String {
        guard let modelContext else { return "现在还没有可用数据。" }
        let meals = (try? modelContext.fetch(FetchDescriptor<Meal>())) ?? []
        let waterLogs = (try? modelContext.fetch(FetchDescriptor<WaterLog>())) ?? []
        let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>())) ?? []
        let goals = ((try? modelContext.fetch(FetchDescriptor<NutritionGoal>())) ?? []).sorted { $0.effectiveDate > $1.effectiveDate }
        let today = Date.now
        let nutrition = NutritionService.dailySummary(meals: meals, waterLogs: waterLogs, for: today)
        let workout = WorkoutService.dailySummary(workouts: workouts, for: today)
        let effectiveTarget = settings?.effectiveTarget(healthTDEE: nil, goal: goals.first) ?? EffectiveNutritionTarget.fallback
        let expenditure = effectiveTarget.calories + workout.totalCaloriesBurned
        let balance = nutrition.totalCalories - expenditure
        let status = balance < -150 ? "热量缺口" : (balance > 150 ? "热量盈余" : "接近维持")
        return "今天摄入 \(Int(nutrition.totalCalories)) kcal，估算消耗 \(Int(expenditure)) kcal，差值 \(Int(balance)) kcal，属于\(status)。训练 \(Int(workout.totalDurationMinutes)) 分钟。"
    }

    static func postWorkoutNutrition(modelContext: ModelContext?, settings: UserSettings?) -> String {
        guard let modelContext else { return "现在还没有可用训练数据。" }
        let meals = (try? modelContext.fetch(FetchDescriptor<Meal>())) ?? []
        let waterLogs = (try? modelContext.fetch(FetchDescriptor<WaterLog>())) ?? []
        let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>())) ?? []
        let goals = ((try? modelContext.fetch(FetchDescriptor<NutritionGoal>())) ?? []).sorted { $0.effectiveDate > $1.effectiveDate }
        let today = Date.now
        let nutrition = NutritionService.dailySummary(meals: meals, waterLogs: waterLogs, for: today)
        let workout = WorkoutService.dailySummary(workouts: workouts, for: today)
        let proteinTarget = (settings?.effectiveTarget(healthTDEE: nil, goal: goals.first) ?? EffectiveNutritionTarget.fallback).protein
        let proteinGap = WorkoutService.postWorkoutProteinGap(currentProtein: nutrition.totalProtein ?? 0, targetProtein: proteinTarget, workoutSummary: workout)
        let hydration = WorkoutService.hydrationRecommendation(workoutSummary: workout, currentWaterMl: nutrition.totalWaterMl, baseTargetMl: settings?.dailyWaterGoalMl ?? 2000)
        return "训练后建议：蛋白缺口约 \(Int(proteinGap))g。\(WorkoutService.postWorkoutCarbSuggestion(workoutSummary: workout)) \(hydration)"
    }
}
