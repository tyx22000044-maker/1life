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
        let intakeTarget = settings?.effectiveTarget(healthTDEE: nil, goal: goals.first) ?? EffectiveNutritionTarget.fallback
        let trainingBurn = workout.totalCaloriesBurned
        let trainingText = "训练 \(Int(workout.totalDurationMinutes)) 分钟、额外 \(Int(trainingBurn)) kcal。"

        // The intake target is not an expenditure: with a fat-loss multiplier it sits far
        // below maintenance, so using it as the baseline inverted the sign of the "balance".
        guard let maintenance = settings?.estimatedTDEE else {
            let differenceFromTarget = nutrition.totalCalories - intakeTarget.calories
            return "今天摄入 \(Int(nutrition.totalCalories)) kcal，摄入目标 \(Int(intakeTarget.calories)) kcal（估算参考值），"
                + "相对目标差值 \(Int(differenceFromTarget)) kcal。补齐身高、体重、年龄和活动等级后才能估算消耗。"
                + trainingText
        }

        let balance = nutrition.totalCalories - maintenance
        let status = balance < -150 ? "热量缺口" : (balance > 150 ? "热量盈余" : "接近维持")
        return "今天摄入 \(Int(nutrition.totalCalories)) kcal，消耗估算 \(Int(maintenance)) kcal（按身体参数推算，非医疗测量），"
            + "差值 \(Int(balance)) kcal，属于\(status)。\(trainingText)"
            + "训练消耗已含在活动水平里，不重复叠加。"
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
