import XCTest
@testable import OneLife

@MainActor
final class WorkoutServiceTests: XCTestCase {
    private let calendar = Calendar.current

    private func referenceDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 18 // a Wednesday, arbitrary
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func minutes(_ value: Int, from date: Date) -> Date {
        calendar.date(byAdding: .minute, value: value, to: date)!
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date)!
    }

    // MARK: - Daily summary & macro adjustments

    func testAdjustedTargetsOnTrainingDay() {
        let now = referenceDate()
        let summary = WorkoutService.dailySummary(
            workouts: [WorkoutLog(workoutType: .running, startDate: now, durationMinutes: 40)],
            for: now
        )
        XCTAssertTrue(summary.isTrainingDay)
        XCTAssertEqual(WorkoutService.adjustedProteinTarget(base: 100, workoutSummary: summary), 110, accuracy: 0.0001)
        XCTAssertEqual(WorkoutService.adjustedCarbsTarget(base: 100, workoutSummary: summary), 108, accuracy: 0.0001)
    }

    func testAdjustedTargetsOnRestDay() {
        let now = referenceDate()
        let summary = WorkoutService.dailySummary(
            workouts: [WorkoutLog(startDate: now, isRestDay: true)],
            for: now
        )
        XCTAssertTrue(summary.isRestDay)
        XCTAssertEqual(WorkoutService.adjustedProteinTarget(base: 100, workoutSummary: summary), 95, accuracy: 0.0001)
        XCTAssertEqual(WorkoutService.adjustedCarbsTarget(base: 100, workoutSummary: summary), 95, accuracy: 0.0001)
    }

    func testAdjustedTargetsUnchangedWithNoWorkoutData() {
        let now = referenceDate()
        let summary = WorkoutService.dailySummary(workouts: [], for: now)
        XCTAssertFalse(summary.isTrainingDay)
        XCTAssertFalse(summary.isRestDay)
        XCTAssertEqual(WorkoutService.adjustedProteinTarget(base: 100, workoutSummary: summary), 100, accuracy: 0.0001)
    }

    func testPostWorkoutProteinGapOnlyAppliesOnTrainingDays() {
        let now = referenceDate()
        let trainingSummary = WorkoutService.dailySummary(workouts: [WorkoutLog(startDate: now)], for: now)
        XCTAssertEqual(WorkoutService.postWorkoutProteinGap(currentProtein: 50, targetProtein: 120, workoutSummary: trainingSummary), 70, accuracy: 0.0001)

        let restSummary = WorkoutService.dailySummary(workouts: [], for: now)
        XCTAssertEqual(WorkoutService.postWorkoutProteinGap(currentProtein: 50, targetProtein: 120, workoutSummary: restSummary), 0)
    }

    func testPostWorkoutCarbSuggestionThresholds() {
        let now = referenceDate()
        let noTraining = WorkoutService.dailySummary(workouts: [], for: now)
        XCTAssertEqual(WorkoutService.postWorkoutCarbSuggestion(workoutSummary: noTraining), "今天没有训练记录，按日常碳水目标执行。")

        let heavy = WorkoutService.dailySummary(workouts: [WorkoutLog(startDate: now, durationMinutes: 80)], for: now)
        XCTAssertEqual(WorkoutService.postWorkoutCarbSuggestion(workoutSummary: heavy), "训练量偏高，训练后可优先补充一份主食或水果。")

        let light = WorkoutService.dailySummary(workouts: [WorkoutLog(startDate: now, durationMinutes: 30)], for: now)
        XCTAssertEqual(WorkoutService.postWorkoutCarbSuggestion(workoutSummary: light), "训练后保持正常正餐节奏即可，优先保证蛋白质和水分。")
    }

    // MARK: - Weekly summary

    func testWeeklySummaryAggregatesTrainingWorkoutsOnly() {
        let now = referenceDate()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let workouts = [
            WorkoutLog(startDate: calendar.date(byAdding: .day, value: 0, to: weekStart)!, durationMinutes: 45, caloriesBurned: 300),
            WorkoutLog(startDate: calendar.date(byAdding: .day, value: 1, to: weekStart)!, durationMinutes: 30, caloriesBurned: 200),
            WorkoutLog(startDate: calendar.date(byAdding: .day, value: 2, to: weekStart)!, isRestDay: true)
        ]
        let summary = WorkoutService.weeklySummary(workouts: workouts, asOf: now, targetCount: 3, targetMinutes: 100)
        XCTAssertEqual(summary.completedCount, 2)
        XCTAssertEqual(summary.totalMinutes, 75, accuracy: 0.0001)
        XCTAssertEqual(summary.totalCalories, 500, accuracy: 0.0001)
        XCTAssertEqual(summary.minuteProgress, 0.75, accuracy: 0.0001)
        XCTAssertFalse(summary.isTargetMet)
    }

    func testWeeklySummaryTargetMetByMinutesEvenIfCountShort() {
        let now = referenceDate()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let workouts = [WorkoutLog(startDate: weekStart, durationMinutes: 200)]
        let summary = WorkoutService.weeklySummary(workouts: workouts, asOf: now, targetCount: 3, targetMinutes: 150)
        XCTAssertTrue(summary.isTargetMet)
        XCTAssertEqual(WorkoutService.weeklyReportText(weekly: summary), "本周训练已达标：1/3 次，200/150 分钟。")
    }

    // MARK: - Streaks

    func testTrainingStreakCountsConsecutiveDaysBackward() {
        let now = referenceDate()
        let workouts = [
            WorkoutLog(startDate: now),
            WorkoutLog(startDate: day(-1, from: now)),
            WorkoutLog(startDate: day(-3, from: now)) // gap at -2
        ]
        XCTAssertEqual(WorkoutService.trainingStreak(workouts: workouts, asOf: now), 2)
    }

    func testConsistencyScoreCapsAt100() {
        let now = referenceDate()
        let workouts = (0..<28).map { WorkoutLog(startDate: day(-$0, from: now)) }
        XCTAssertEqual(WorkoutService.consistencyScore(workouts: workouts, days: 28, asOf: now), 100)
    }

    // MARK: - Timing suggestions

    func testPreWorkoutMealTimingSuggestionBuckets() {
        let now = referenceDate()
        XCTAssertEqual(WorkoutService.preWorkoutMealTimingSuggestion(nextWorkout: nil, now: now), "今天没有未来训练安排，按正常餐次吃。")

        let alreadyStarted = WorkoutLog(startDate: minutes(-10, from: now))
        XCTAssertEqual(WorkoutService.preWorkoutMealTimingSuggestion(nextWorkout: alreadyStarted, now: now), "训练已开始或已结束，训练后优先补水和蛋白质。")

        let soon = WorkoutLog(startDate: minutes(30, from: now))
        XCTAssertEqual(WorkoutService.preWorkoutMealTimingSuggestion(nextWorkout: soon, now: now), "距离训练较近，可选择少量易消化碳水。")

        let later = WorkoutLog(startDate: minutes(120, from: now))
        XCTAssertEqual(WorkoutService.preWorkoutMealTimingSuggestion(nextWorkout: later, now: now), "距离训练 1-3 小时，适合正常一餐，避免过油。")

        let farOff = WorkoutLog(startDate: minutes(300, from: now))
        XCTAssertEqual(WorkoutService.preWorkoutMealTimingSuggestion(nextWorkout: farOff, now: now), "训练还早，维持正常餐次即可。")
    }

    func testHydrationRecommendationScalesWithDuration() {
        let now = referenceDate()
        let noWorkout = WorkoutService.dailySummary(workouts: [], for: now)
        XCTAssertEqual(WorkoutService.hydrationRecommendation(workoutSummary: noWorkout, currentWaterMl: 500, baseTargetMl: 2000), "今日按基础饮水目标执行。")

        let longWorkout = WorkoutService.dailySummary(workouts: [WorkoutLog(startDate: now, durationMinutes: 90)], for: now)
        XCTAssertEqual(WorkoutService.hydrationRecommendation(workoutSummary: longWorkout, currentWaterMl: 1000, baseTargetMl: 2000), "训练日建议饮水目标约 2500ml，还差 1500ml。")
    }
}
