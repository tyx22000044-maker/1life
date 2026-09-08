import Foundation

enum HabitService {
    static func currentStreak(habit: Habit, asOf date: Date = .now) -> Int {
        let logs = habit.logs ?? []
        switch habit.frequencyType {
        case .daily:
            return dailyStreak(logs: logs, target: habit.targetCount ?? 1, asOf: date)
        case .weekly:
            return weeklyStreak(logs: logs, target: habit.targetCount ?? 1, requiredPerWeek: habit.frequencyCount, asOf: date)
        }
    }

    static func completionRate(habit: Habit, days: Int = 30, asOf date: Date = .now) -> Double {
        return days > 0 ? Double(completedDays(habit: habit, days: days, asOf: date)) / Double(days) : 0
    }

    static func completedDays(habit: Habit, days: Int = 30, asOf date: Date = .now) -> Int {
        let logs = habit.logs ?? []
        let cal = Calendar.current
        var completed = 0
        for offset in 0..<days {
            guard let day = cal.date(byAdding: .day, value: -offset, to: date) else { continue }
            let dayLogs = logs.filter { $0.date.isSameDay(as: day) }
            let total = dayLogs.reduce(0.0) { $0 + $1.value }
            if total >= (habit.targetCount ?? 1) { completed += 1 }
        }
        return completed
    }

    // MARK: - Daily Streak

    private static func dailyStreak(logs: [HabitLog], target: Double, asOf date: Date) -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.date(byAdding: .day, value: -1, to: date)!

        while true {
            let dayLogs = logs.filter { $0.date.isSameDay(as: checkDate) }
            let total = dayLogs.reduce(0.0) { $0 + $1.value }
            if total >= target {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        let todayLogs = logs.filter { $0.date.isSameDay(as: date) }
        if todayLogs.reduce(0.0, { $0 + $1.value }) >= target {
            streak += 1
        }

        return streak
    }

    // MARK: - Weekly Streak

    private static func weeklyStreak(logs: [HabitLog], target: Double, requiredPerWeek: Int, asOf date: Date) -> Int {
        let cal = Calendar.current
        var streak = 0
        var weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        weekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart)!

        while true {
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)!
            let weekLogs = logs.filter { log in
                log.date >= weekStart && log.date <= weekEnd
            }

            var daysCompleted = 0
            for dayOffset in 0...6 {
                let day = cal.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let dayTotal = weekLogs.filter { $0.date.isSameDay(as: day) }.reduce(0.0) { $0 + $1.value }
                if dayTotal >= target { daysCompleted += 1 }
            }

            if daysCompleted >= requiredPerWeek {
                streak += 1
                weekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
            } else {
                break
            }
        }

        return streak
    }
}
