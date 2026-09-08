import Foundation

struct DailyWorkoutSummary {
    var date: Date
    var workouts: [WorkoutLog]

    var trainingWorkouts: [WorkoutLog] {
        workouts.filter { !$0.isRestDay }
    }

    var restDayLogs: [WorkoutLog] {
        workouts.filter(\.isRestDay)
    }

    var isTrainingDay: Bool {
        !trainingWorkouts.isEmpty
    }

    var isRestDay: Bool {
        !isTrainingDay && !restDayLogs.isEmpty
    }

    var totalDurationMinutes: Double {
        trainingWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalCaloriesBurned: Double {
        trainingWorkouts.reduce(0) { $0 + ($1.caloriesBurned ?? 0) }
    }

    var activeMinutes: Double {
        trainingWorkouts.reduce(0) { total, workout in
            total + (workout.intensity == .low ? workout.durationMinutes * 0.75 : workout.durationMinutes)
        }
    }

    var primaryType: WorkoutType? {
        trainingWorkouts.first?.workoutType
    }
}

struct WeeklyWorkoutSummary {
    var weekStart: Date
    var workouts: [WorkoutLog]
    var targetCount: Int
    var targetMinutes: Int

    var trainingWorkouts: [WorkoutLog] {
        workouts.filter { !$0.isRestDay }
    }

    var completedCount: Int {
        trainingWorkouts.count
    }

    var totalMinutes: Double {
        trainingWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalCalories: Double {
        trainingWorkouts.reduce(0) { $0 + ($1.caloriesBurned ?? 0) }
    }

    var countProgress: Double {
        guard targetCount > 0 else { return 0 }
        return Double(completedCount) / Double(targetCount)
    }

    var minuteProgress: Double {
        guard targetMinutes > 0 else { return 0 }
        return totalMinutes / Double(targetMinutes)
    }

    var isTargetMet: Bool {
        completedCount >= targetCount || totalMinutes >= Double(targetMinutes)
    }
}

enum WorkoutService {
    static func dailySummary(workouts: [WorkoutLog], for date: Date) -> DailyWorkoutSummary {
        DailyWorkoutSummary(
            date: date,
            workouts: workouts
                .filter { $0.startDate.isSameDay(as: date) }
                .sorted { $0.startDate < $1.startDate }
        )
    }

    static func adjustedProteinTarget(base: Double, workoutSummary: DailyWorkoutSummary) -> Double {
        if workoutSummary.isTrainingDay { return base * 1.10 }
        if workoutSummary.isRestDay { return base * 0.95 }
        return base
    }

    static func adjustedCarbsTarget(base: Double, workoutSummary: DailyWorkoutSummary) -> Double {
        if workoutSummary.isTrainingDay { return base * 1.08 }
        if workoutSummary.isRestDay { return base * 0.95 }
        return base
    }

    static func postWorkoutProteinGap(currentProtein: Double, targetProtein: Double, workoutSummary: DailyWorkoutSummary) -> Double {
        guard workoutSummary.isTrainingDay else { return 0 }
        return max(targetProtein - currentProtein, 0)
    }

    static func postWorkoutCarbSuggestion(workoutSummary: DailyWorkoutSummary) -> String {
        guard workoutSummary.isTrainingDay else { return "今天没有训练记录，按日常碳水目标执行。" }
        if workoutSummary.totalDurationMinutes >= 75 || workoutSummary.totalCaloriesBurned >= 500 {
            return "训练量偏高，训练后可优先补充一份主食或水果。"
        }
        return "训练后保持正常正餐节奏即可，优先保证蛋白质和水分。"
    }

    static func weeklySummary(workouts: [WorkoutLog], asOf date: Date = .now, targetCount: Int, targetMinutes: Int) -> WeeklyWorkoutSummary {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let start = interval?.start ?? date.startOfDay
        let end = interval?.end ?? date.endOfDay
        return WeeklyWorkoutSummary(
            weekStart: start,
            workouts: workouts.filter { $0.startDate >= start && $0.startDate < end },
            targetCount: targetCount,
            targetMinutes: targetMinutes
        )
    }

    static func trainingStreak(workouts: [WorkoutLog], asOf date: Date = .now) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = date
        while true {
            let hasTraining = workouts.contains { !$0.isRestDay && $0.startDate.isSameDay(as: cursor) }
            guard hasTraining else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func consistencyScore(workouts: [WorkoutLog], days: Int = 28, asOf date: Date = .now) -> Int {
        let calendar = Calendar.current
        let trainingDays = (0..<days).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return false }
            return workouts.contains { !$0.isRestDay && $0.startDate.isSameDay(as: day) }
        }.count
        return min(Int(Double(trainingDays) / Double(days) * 100), 100)
    }

    static func preWorkoutMealTimingSuggestion(nextWorkout: WorkoutLog?, now: Date = .now) -> String {
        guard let nextWorkout, !nextWorkout.isRestDay else {
            return "今天没有未来训练安排，按正常餐次吃。"
        }
        let minutes = nextWorkout.startDate.timeIntervalSince(now) / 60
        if minutes < 0 { return "训练已开始或已结束，训练后优先补水和蛋白质。" }
        if minutes <= 60 { return "距离训练较近，可选择少量易消化碳水。"}
        if minutes <= 180 { return "距离训练 1-3 小时，适合正常一餐，避免过油。"}
        return "训练还早，维持正常餐次即可。"
    }

    static func hydrationRecommendation(workoutSummary: DailyWorkoutSummary, currentWaterMl: Double, baseTargetMl: Double) -> String {
        let extra = workoutSummary.totalDurationMinutes >= 60 ? 500.0 : (workoutSummary.totalDurationMinutes > 0 ? 300.0 : 0)
        let target = baseTargetMl + extra
        let gap = max(target - currentWaterMl, 0)
        if extra == 0 { return "今日按基础饮水目标执行。" }
        return "训练日建议饮水目标约 \(Int(target))ml，还差 \(Int(gap))ml。"
    }

    static func weeklyReportText(weekly: WeeklyWorkoutSummary) -> String {
        let countText = "\(weekly.completedCount)/\(weekly.targetCount) 次"
        let minuteText = "\(Int(weekly.totalMinutes))/\(weekly.targetMinutes) 分钟"
        if weekly.isTargetMet {
            return "本周训练已达标：\(countText)，\(minuteText)。"
        }
        return "本周训练进度：\(countText)，\(minuteText)，还可以补一次低到中强度训练。"
    }
}
