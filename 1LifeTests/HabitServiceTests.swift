import XCTest
@testable import OneLife

@MainActor
final class HabitServiceTests: XCTestCase {
    private let calendar = Calendar.current

    private func referenceDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 20
        return calendar.date(from: components)!
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date)!
    }

    private func makeHabit(frequency: HabitFrequencyType = .daily, frequencyCount: Int = 1, targetCount: Double? = nil) -> Habit {
        Habit(name: "Test", frequencyType: frequency, frequencyCount: frequencyCount, targetCount: targetCount)
    }

    func testDailyStreakCountsConsecutiveDaysIncludingToday() {
        let now = referenceDate()
        let habit = makeHabit()
        habit.logs = [
            HabitLog(date: day(0, from: now), value: 1),
            HabitLog(date: day(-1, from: now), value: 1),
            HabitLog(date: day(-2, from: now), value: 1)
        ]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 3)
    }

    func testDailyStreakBreaksOnGapBeforeToday() {
        let now = referenceDate()
        let habit = makeHabit()
        habit.logs = [
            HabitLog(date: day(0, from: now), value: 1),
            HabitLog(date: day(-2, from: now), value: 1) // gap at -1 breaks the backward scan
        ]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 1)
    }

    func testDailyStreakDoesNotCountTodayIfNotYetLogged() {
        let now = referenceDate()
        let habit = makeHabit()
        habit.logs = [
            HabitLog(date: day(-1, from: now), value: 1),
            HabitLog(date: day(-2, from: now), value: 1)
        ]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 2)
    }

    func testQuantityBasedHabitRequiresTargetSum() {
        let now = referenceDate()
        let habit = makeHabit(targetCount: 3)
        XCTAssertTrue(habit.isQuantityBased)
        habit.logs = [
            HabitLog(date: day(0, from: now), value: 1),
            HabitLog(date: day(0, from: now), value: 2) // sums to 3 today, meets target
        ]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 1)
    }

    func testWeeklyStreakCountsCompletedPriorWeeks() {
        let now = referenceDate()
        let habit = makeHabit(frequency: .weekly, frequencyCount: 3)
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let twoWeeksAgoStart = calendar.date(byAdding: .weekOfYear, value: -2, to: thisWeekStart)!

        func threeLogs(from weekStart: Date) -> [HabitLog] {
            [0, 1, 2].map { HabitLog(date: calendar.date(byAdding: .day, value: $0, to: weekStart)!, value: 1) }
        }

        habit.logs = threeLogs(from: lastWeekStart) + threeLogs(from: twoWeeksAgoStart)
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 2)
    }

    func testWeeklyStreakStopsAtFirstIncompleteWeek() {
        let now = referenceDate()
        let habit = makeHabit(frequency: .weekly, frequencyCount: 3)
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        // Only 1 day logged last week, short of the required 3, so the streak never starts.
        habit.logs = [HabitLog(date: lastWeekStart, value: 1)]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 0)
    }

    func testWeeklyStreakCountsLogLateOnTheLastDayOfWeek() {
        let now = referenceDate()
        let habit = makeHabit(frequency: .weekly, frequencyCount: 1)
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let lastDayOfPriorWeek = calendar.date(byAdding: .day, value: 6, to: lastWeekStart)!
        let lateNight = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: lastDayOfPriorWeek)!

        habit.logs = [HabitLog(date: lateNight, value: 1)]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 1)
    }

    func testWeeklyStreakCountsLogExactlyAtWeekStartMidnight() {
        let now = referenceDate()
        let habit = makeHabit(frequency: .weekly, frequencyCount: 1)
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!

        habit.logs = [HabitLog(date: lastWeekStart, value: 1)]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 1)
    }

    func testWeeklyStreakExcludesLogFromTheFollowingWeek() {
        let now = referenceDate()
        let habit = makeHabit(frequency: .weekly, frequencyCount: 1)
        let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        habit.logs = [HabitLog(date: thisWeekStart, value: 1)]
        XCTAssertEqual(HabitService.currentStreak(habit: habit, asOf: now), 0)
    }

    func testCompletionRateOverWindow() {
        let now = referenceDate()
        let habit = makeHabit()
        habit.logs = (0..<10).map { HabitLog(date: day(-$0, from: now), value: 1) }
        XCTAssertEqual(HabitService.completionRate(habit: habit, days: 30, asOf: now), 10.0 / 30.0, accuracy: 0.0001)
    }

    func testCompletedDaysZeroWhenNoLogs() {
        let now = referenceDate()
        let habit = makeHabit()
        habit.logs = []
        XCTAssertEqual(HabitService.completedDays(habit: habit, days: 30, asOf: now), 0)
    }
}
