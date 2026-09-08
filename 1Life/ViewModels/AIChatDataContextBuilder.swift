import Foundation
import SwiftData

@MainActor
struct AIChatDataContextBuilder {
    static func build(modelContext: ModelContext?, settings: UserSettings?) async -> AIDataContext {
        guard let modelContext else {
            return empty(settings: settings)
        }

        let calendar = Calendar.current
        let today = Date.now
        let dayStart = calendar.startOfDay(for: today)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? today
        let recentStart = calendar.date(byAdding: .day, value: -2, to: dayStart) ?? dayStart

        // AI context only needs today's data plus the previous two days. Loading
        // the complete food history here made every AI request grow with the
        // user's lifetime records.
        let recentMealPredicate = #Predicate<Meal> { meal in
            meal.date >= recentStart && meal.date < nextDayStart
        }
        let meals = (try? modelContext.fetch(FetchDescriptor<Meal>(predicate: recentMealPredicate))) ?? []

        let recentWaterPredicate = #Predicate<WaterLog> { log in
            log.date >= recentStart && log.date < nextDayStart
        }
        let waterLogs = (try? modelContext.fetch(FetchDescriptor<WaterLog>(predicate: recentWaterPredicate))) ?? []

        let activeHabitPredicate = #Predicate<Habit> { habit in
            !habit.isArchived
        }
        let habits = (try? modelContext.fetch(FetchDescriptor<Habit>(predicate: activeHabitPredicate))) ?? []

        var journalDescriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        journalDescriptor.fetchLimit = 5
        let journals = (try? modelContext.fetch(journalDescriptor)) ?? []

        let todayWorkoutPredicate = #Predicate<WorkoutLog> { workout in
            workout.startDate >= dayStart && workout.startDate < nextDayStart
        }
        let workouts = (try? modelContext.fetch(FetchDescriptor<WorkoutLog>(predicate: todayWorkoutPredicate))) ?? []

        var goalDescriptor = FetchDescriptor<NutritionGoal>(
            sortBy: [SortDescriptor(\.effectiveDate, order: .reverse)]
        )
        goalDescriptor.fetchLimit = 1
        let goals = (try? modelContext.fetch(goalDescriptor)) ?? []
        let templates = fetchMealTemplates(modelContext: modelContext)

        let summary = NutritionService.dailySummary(meals: meals, waterLogs: waterLogs, for: today)
        let goal = goals.first
        let healthTDEE: Double? = (settings?.useHealthKitForDynamicTDEE == true)
            ? (try? await HealthKitService.shared.energySummary(for: today, settings: settings))?.tdeeKcal
            : nil
        let target = settings?.effectiveTarget(healthTDEE: healthTDEE, goal: goal) ?? EffectiveNutritionTarget.fallback
        let mealSummaries = NutritionService.mealSummaries(meals: meals, for: today)
            .filter { $0.totalCalories > 0 }
            .map { "\($0.mealType.displayName) \(Int($0.totalCalories))kcal" }

        return AIDataContext(
            todayCalories: summary.totalCalories,
            todayProtein: summary.totalProtein,
            todayCarbs: summary.totalCarbs,
            todayFat: summary.totalFat,
            calorieTarget: target.calories,
            dietGoalMode: settings?.dietGoalMode.displayName ?? "均衡",
            mealSummaries: mealSummaries,
            recentDaysSummaries: recentDaySummaries(meals: meals, waterLogs: waterLogs, today: today),
            habitSummaries: habitSummaries(habits: habits, workouts: workouts, date: today),
            recentStatusSummaries: recentStatusSummaries(journals: journals),
            mealTemplateSummaries: mealTemplateSummaries(templates: templates)
        )
    }

    private static func empty(settings: UserSettings?) -> AIDataContext {
        AIDataContext(
            todayCalories: 0,
            todayProtein: nil,
            todayCarbs: nil,
            todayFat: nil,
            calorieTarget: 2000,
            dietGoalMode: settings?.dietGoalMode.displayName ?? "均衡",
            mealSummaries: [],
            recentDaysSummaries: [],
            habitSummaries: [],
            recentStatusSummaries: [],
            mealTemplateSummaries: []
        )
    }

    private static func fetchMealTemplates(modelContext: ModelContext) -> [MealTemplate] {
        var descriptor = FetchDescriptor<MealTemplate>(
            sortBy: [SortDescriptor(\.useCount, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 12
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func mealTemplateSummaries(templates: [MealTemplate]) -> [String] {
        templates.prefix(12).map { template in
            let items = template.foodItems.prefix(4).map { "\($0.name) \($0.amount.nutritionDecimal)\($0.unit) \(Int($0.calories))kcal" }.joined(separator: "、")
            return "「\(template.name)」\(template.mealType.displayName)：\(items)，合计\(Int(template.totalCalories))kcal"
        }
    }

    private static func recentDaySummaries(meals: [Meal], waterLogs: [WaterLog], today: Date) -> [String] {
        let calendar = Calendar.current
        return (0..<3).compactMap { offset -> String? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let summary = NutritionService.dailySummary(meals: meals, waterLogs: waterLogs, for: date)
            guard summary.totalCalories > 0 || summary.totalWaterMl > 0 else { return nil }
            return "\(date.dayDisplay) \(Int(summary.totalCalories))kcal 饮水\(Int(summary.totalWaterMl))ml"
        }
    }

    private static func habitSummaries(habits: [Habit], workouts: [WorkoutLog], date: Date) -> [String] {
        var summaries = habits.prefix(8).map { habit in
            let dayLogs = (habit.logs ?? []).filter { $0.date.isSameDay(as: date) }
            let current = dayLogs.reduce(0.0) { $0 + $1.value }
            let target = habit.targetCount ?? 1
            let status = current >= target ? "已完成" : "未完成"
            if habit.isQuantityBased {
                let unit = habit.unitName ?? "次"
                return "\(habit.name) \(Int(current))/\(Int(target))\(unit) \(status)"
            }
            return "\(habit.name) \(status)"
        }
        if hasCompletedExerciseHabit(habits: habits, date: date) {
            summaries.append("运动日：蛋白目标上调10%作为当日参考")
        }
        let workoutSummary = WorkoutService.dailySummary(workouts: workouts, for: date)
        if workoutSummary.isTrainingDay {
            summaries.append("训练：\(Int(workoutSummary.totalDurationMinutes))分钟，消耗\(Int(workoutSummary.totalCaloriesBurned))kcal")
        } else if workoutSummary.isRestDay {
            summaries.append("今天标记为休息日")
        }
        return summaries
    }

    private static func hasCompletedExerciseHabit(habits: [Habit], date: Date) -> Bool {
        habits.contains { habit in
            let isExercise = ["运动", "跑步", "健身", "训练", "拉伸"].contains { habit.name.contains($0) }
            guard isExercise else { return false }
            let current = (habit.logs ?? [])
                .filter { $0.date.isSameDay(as: date) }
                .reduce(0.0) { $0 + $1.value }
            return current >= (habit.targetCount ?? 1)
        }
    }

    private static func recentStatusSummaries(journals: [JournalEntry]) -> [String] {
        journals.prefix(5).map { entry in
            let mood = entry.mood.map { $0.displayName } ?? "未标心情"
            let tags = entry.activityTags.map(\.displayName).prefix(4).joined(separator: "/")
            let tagText = tags.isEmpty ? "" : " \(tags)"
            let content = entry.content.count > 36 ? String(entry.content.prefix(36)) + "..." : entry.content
            return "\(entry.date.dayDisplay) \(mood)\(tagText): \(content)"
        }
    }
}
