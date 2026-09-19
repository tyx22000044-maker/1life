import SwiftUI
import SwiftData

struct MyLifeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appViewModel
    @Query(filter: #Predicate<Habit> { !$0.isArchived })
    private var activeHabits: [Habit]
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)])
    private var journalEntries: [JournalEntry]
    @Query private var workouts: [WorkoutLog]
    @Query private var allMeals: [Meal]
    @Query private var allWaterLogs: [WaterLog]
    @Query(sort: [SortDescriptor(\BodyMeasurement.date, order: .reverse)])
    private var bodyMeasurements: [BodyMeasurement]
    @Query(sort: [SortDescriptor(\NutritionGoal.effectiveDate, order: .reverse)])
    private var nutritionGoals: [NutritionGoal]
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\BowelLog.date, order: .reverse)])
    private var bowelLogs: [BowelLog]

    @State private var isPreparingContent = true

    private var completedHabitsToday: Int {
        activeHabits.filter { habit in
            let dayLogs = (habit.logs ?? []).filter { $0.date.isSameDay(as: Date.now) }
            let total = dayLogs.reduce(0) { $0 + $1.value }
            return total >= (habit.targetCount ?? 1)
        }.count
    }

    private var latestJournal: JournalEntry? {
        journalEntries.first
    }

    private var todayWorkoutSummary: DailyWorkoutSummary {
        WorkoutService.dailySummary(workouts: workouts, for: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if isPreparingContent {
                            MyLifeLoadingPanel()
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                MyLifeSummaryCard(
                                    completedHabits: completedHabitsToday,
                                    totalHabits: activeHabits.count,
                                    journalCount: journalEntries.count,
                                    workoutMinutes: todayWorkoutSummary.totalDurationMinutes,
                                    latestJournal: latestJournal
                                )

                                ReviewSummaryPanel(
                                    meals: allMeals,
                                    waterLogs: allWaterLogs,
                                    habits: activeHabits,
                                    journals: journalEntries,
                                    workouts: workouts,
                                    measurements: bodyMeasurements,
                                    nutritionGoals: nutritionGoals,
                                    settings: settings.first,
                                    bowelLogs: bowelLogs
                                )

                                BodyMetricsCard(
                                    measurements: bodyMeasurements,
                                    settings: settings.first,
                                    modelContext: modelContext
                                )

                                BowelTrackerCard(logs: bowelLogs, modelContext: modelContext)

                                HabitTrackerView(date: Date.now)
                                    .id(MyLifeFocus.habits)

                                JournalListView()
                                    .id(MyLifeFocus.journal)

                                WorkoutTimelineView()
                                    .id(MyLifeFocus.workouts)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)
                    .padding(.top, 0)
                    .padding(.bottom, AppSpacing.pageBottom)
                }
                .scrollIndicators(.hidden)
                .onChange(of: appViewModel.myLifeFocus) { _, focus in
                    scrollToRequestedFocus(focus, proxy: proxy)
                }
                .onChange(of: isPreparingContent) { _, isPreparing in
                    if !isPreparing {
                        scrollToRequestedFocus(appViewModel.myLifeFocus, proxy: proxy)
                    }
                }
                .onAppear {
                    scrollToRequestedFocus(appViewModel.myLifeFocus, proxy: proxy)
                }
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("回顾")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                isPreparingContent = true
                try? await Task.sleep(for: .milliseconds(160))
                isPreparingContent = false
            }
        }
    }

    private func scrollToRequestedFocus(_ focus: MyLifeFocus?, proxy: ScrollViewProxy) {
        guard let focus, !isPreparingContent else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.snappy(duration: 0.34)) {
                proxy.scrollTo(focus, anchor: .top)
            }
            appViewModel.myLifeFocus = nil
        }
    }
}

private struct MyLifeLoadingPanel: View {
    var body: some View {
        SystemPanel(title: "正在整理", detail: "正在准备习惯、身体和阶段回顾") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(FamilyUI.accent)
                Text("正在载入回顾数据")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct ReviewSummaryPanel: View {
    let meals: [Meal]
    let waterLogs: [WaterLog]
    let habits: [Habit]
    let journals: [JournalEntry]
    let workouts: [WorkoutLog]
    let measurements: [BodyMeasurement]
    let nutritionGoals: [NutritionGoal]
    let settings: UserSettings?
    let bowelLogs: [BowelLog]

    @State private var selectedPeriod: ReviewPeriod = .week
    @State private var isPreparing = false
    @State private var healthTDEEByDay: [Date: Double] = [:]

    var body: some View {
        SystemPanel(title: "阶段回顾", detail: "默认展示本周，可切换月、季、年") {
            Picker("回顾周期", selection: $selectedPeriod) {
                ForEach(ReviewPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPeriod) { _, period in
                Task {
                    await preparePeriodChange()
                    await refreshHealthTDEE(for: period)
                }
            }

            ZStack(alignment: .topLeading) {
                ReviewInsightDashboard(snapshot: periodSnapshot(for: selectedPeriod))
                    .opacity(isPreparing ? 0 : 1)

                if isPreparing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(FamilyUI.accent)
                        Text("正在整理\(selectedPeriod.title)数据")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isPreparing)
        }
        .task {
            await refreshHealthTDEE(for: selectedPeriod)
        }
    }

    private func periodSnapshot(for period: ReviewPeriod) -> ReviewPeriodSnapshot {
        let ranges = bucketRanges(for: period)
        let fallbackStart = startDate(for: period)
        let start = ranges.first?.start ?? fallbackStart
        let end = ranges.last?.end ?? Date.now
        let periodMeals = meals.filter { isWithin($0.date, start: start, end: end) }
        let periodWater = waterLogs.filter { isWithin($0.date, start: start, end: end) }
        let periodWorkouts = workouts.filter { isWithin($0.startDate, start: start, end: end) }
        let periodJournals = journals.filter { isWithin($0.date, start: start, end: end) }
        let periodBowels = bowelLogs.filter { isWithin($0.date, start: start, end: end) }
        let totalCalories = periodMeals.reduce(0) { $0 + $1.totalCalories }
        let totalWater = periodWater.reduce(0) { $0 + $1.amount }
        let activeNutritionDays = activeDayCount(dates: periodMeals.map(\.date))
        let daySpan = max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? period.dayCount, 1)
        let targetMinutes = period.workoutTargetMinutes(settings: settings)
        let workoutMinutes = periodWorkouts.reduce(0) { $0 + $1.durationMinutes }
        let normalBowels = periodBowels.filter { $0.bristolType == .normal }.count
        let averageTDEE = averageDailyTDEE(start: start, end: end)

        return ReviewPeriodSnapshot(
            period: period,
            startDate: start,
            endDate: end,
            buckets: ranges.enumerated().map { index, range in
                bucketSummary(
                    period: period,
                    index: index,
                    start: range.start,
                    end: range.end,
                    meals: periodMeals,
                    waterLogs: periodWater,
                    workouts: periodWorkouts,
                    journals: periodJournals,
                    bowelLogs: periodBowels
                )
            },
            nutritionActiveDays: activeNutritionDays,
            mealCount: periodMeals.count,
            averageCalories: activeNutritionDays > 0 ? totalCalories / Double(activeNutritionDays) : 0,
            averageTDEE: averageTDEE,
            averageWaterMl: totalWater / Double(daySpan),
            workoutMinutes: workoutMinutes,
            workoutCount: periodWorkouts.filter { !$0.isRestDay }.count,
            workoutTargetMinutes: targetMinutes,
            habitCompletionRate: habitCompletionRate(start: start, end: end),
            journalCount: periodJournals.count,
            weightDelta: weightDeltaValue(start: start, end: end),
            latestWeightKg: latestWeight(before: end),
            bowelCount: periodBowels.count,
            normalBowelRatio: periodBowels.isEmpty ? nil : Double(normalBowels) / Double(periodBowels.count)
        )
    }

    private func activeDayCount(dates: [Date]) -> Int {
        let calendar = Calendar.current
        return Set(dates.map { calendar.startOfDay(for: $0) }).count
    }

    private func bucketRanges(for period: ReviewPeriod) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)

        switch period {
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return (0..<7).compactMap { offset in
                guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: start),
                      let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart) else { return nil }
                return (bucketStart, bucketEnd)
            }
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return (0..<30).compactMap { offset in
                guard let bucketStart = calendar.date(byAdding: .day, value: offset, to: start),
                      let bucketEnd = calendar.date(byAdding: .day, value: 1, to: bucketStart) else { return nil }
                return (bucketStart, bucketEnd)
            }
        case .quarter:
            let weekday = calendar.component(.weekday, from: today)
            let weekStart = calendar.date(byAdding: .day, value: 1 - weekday, to: today) ?? today
            let start = calendar.date(byAdding: .weekOfYear, value: -12, to: weekStart) ?? weekStart
            return (0..<13).compactMap { offset in
                guard let bucketStart = calendar.date(byAdding: .weekOfYear, value: offset, to: start),
                      let bucketEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: bucketStart) else { return nil }
                return (bucketStart, bucketEnd)
            }
        case .year:
            let components = calendar.dateComponents([.year, .month], from: today)
            let monthStart = calendar.date(from: components) ?? today
            let start = calendar.date(byAdding: .month, value: -11, to: monthStart) ?? monthStart
            return (0..<12).compactMap { offset in
                guard let bucketStart = calendar.date(byAdding: .month, value: offset, to: start),
                      let bucketEnd = calendar.date(byAdding: .month, value: 1, to: bucketStart) else { return nil }
                return (bucketStart, bucketEnd)
            }
        }
    }

    private func bucketSummary(
        period: ReviewPeriod,
        index: Int,
        start: Date,
        end: Date,
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        journals: [JournalEntry],
        bowelLogs: [BowelLog]
    ) -> ReviewBucketSummary {
        let bucketMeals = meals.filter { isWithin($0.date, start: start, end: end) }
        let bucketWater = waterLogs.filter { isWithin($0.date, start: start, end: end) }
        let bucketWorkouts = workouts.filter { isWithin($0.startDate, start: start, end: end) }
        let bucketJournals = journals.filter { isWithin($0.date, start: start, end: end) }
        let bucketBowels = bowelLogs.filter { isWithin($0.date, start: start, end: end) }
        let habitProgress = completedHabitSlots(start: start, end: end)

        return ReviewBucketSummary(
            startDate: start,
            endDate: end,
            label: bucketLabel(period: period, index: index, start: start),
            dayCount: dayStarts(start: start, end: end).count,
            calories: bucketMeals.reduce(0) { $0 + $1.totalCalories },
            tdee: averageDailyTDEE(start: start, end: end),
            hasMeal: !bucketMeals.isEmpty,
            waterMl: bucketWater.reduce(0) { $0 + $1.amount },
            workoutMinutes: bucketWorkouts.reduce(0) { $0 + $1.durationMinutes },
            workoutCount: bucketWorkouts.filter { !$0.isRestDay }.count,
            completedHabitSlots: habitProgress.completed,
            totalHabitSlots: habitProgress.total,
            journalCount: bucketJournals.count,
            weightKg: latestWeight(start: start, end: end),
            bowelCount: bucketBowels.count
        )
    }

    private func bucketLabel(period: ReviewPeriod, index: Int, start: Date) -> String {
        let calendar = Calendar.current
        switch period {
        case .week:
            let symbols = ["日", "一", "二", "三", "四", "五", "六"]
            let index = min(max(0, calendar.component(.weekday, from: start) - 1), symbols.count - 1)
            return symbols[index]
        case .month:
            return "\(calendar.component(.day, from: start))"
        case .quarter:
            return "\(index + 1)"
        case .year:
            return "\(calendar.component(.month, from: start))月"
        }
    }

    private func averageDailyTDEE(start: Date, end: Date) -> Double {
        let values = dayStarts(start: start, end: end).map(dailyTDEE(for:))
        guard !values.isEmpty else { return fallbackTDEE }
        return values.reduce(0, +) / Double(values.count)
    }

    private func dailyTDEE(for date: Date) -> Double {
        let day = Calendar.current.startOfDay(for: date)
        return healthTDEEByDay[day] ?? fallbackTDEE
    }

    private var fallbackTDEE: Double {
        settings?.estimatedTDEE ?? 2000
    }

    @MainActor
    private func refreshHealthTDEE(for period: ReviewPeriod) async {
        guard settings?.useHealthKitForDynamicTDEE == true,
              settings?.isHealthKitEnabled == true else {
            healthTDEEByDay = [:]
            return
        }

        let days = Array(Set(bucketRanges(for: period).flatMap { dayStarts(start: $0.start, end: $0.end) })).sorted()
        var nextValues: [Date: Double] = [:]

        for day in days {
            guard let tdee = try? await HealthKitService.shared.energySummary(for: day, settings: settings).tdeeKcal else { continue }
            nextValues[Calendar.current.startOfDay(for: day)] = tdee
        }

        guard !Task.isCancelled, period == selectedPeriod else { return }
        healthTDEEByDay = nextValues
    }

    private func dayStarts(start: Date, end: Date) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        while cursor < endDay {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates.isEmpty ? [calendar.startOfDay(for: start)] : dates
    }

    private func isWithin(_ date: Date, start: Date, end: Date) -> Bool {
        date >= start && date < end
    }

    private func habitCompletionRate(start: Date, end: Date) -> Double? {
        let progress = completedHabitSlots(start: start, end: end)
        guard progress.total > 0 else { return nil }
        return Double(progress.completed) / Double(progress.total)
    }

    private func completedHabitSlots(start: Date, end: Date) -> (completed: Int, total: Int) {
        guard !habits.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        var valuesByHabitDay: [UUID: [Date: Double]] = [:]
        for habit in habits {
            var dayValues: [Date: Double] = [:]
            for log in habit.logs ?? [] where isWithin(log.date, start: start, end: end) {
                let day = calendar.startOfDay(for: log.date)
                dayValues[day, default: 0] += log.value
            }
            valuesByHabitDay[habit.id] = dayValues
        }

        var completed = 0
        var total = 0
        var dayStart = calendar.startOfDay(for: start)

        while dayStart < end {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            for habit in habits {
                let target = habit.targetCount ?? 1
                let value = valuesByHabitDay[habit.id]?[dayStart] ?? 0
                completed += value >= target ? 1 : 0
                total += 1
            }
            dayStart = dayEnd
        }

        return (completed, total)
    }

    private func startDate(for period: ReviewPeriod) -> Date {
        Calendar.current.date(byAdding: period.component, value: period.value, to: Date.now) ?? Date.now
    }

    private func preparePeriodChange() async {
        withAnimation(.easeInOut(duration: 0.2)) { isPreparing = true }
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.easeInOut(duration: 0.25)) { isPreparing = false }
    }

    private func latestWeight(start: Date, end: Date) -> Double? {
        measurements
            .filter { measurement in
                isWithin(measurement.date, start: start, end: end) && measurement.weightKg != nil
            }
            .max { $0.date < $1.date }?
            .weightKg
    }

    private func latestWeight(before end: Date) -> Double? {
        measurements
            .filter { $0.date < end && $0.weightKg != nil }
            .max { $0.date < $1.date }?
            .weightKg
    }

    private func weightDeltaValue(start: Date, end: Date) -> Double? {
        var earliest: BodyMeasurement?
        var latest: BodyMeasurement?

        for measurement in measurements where isWithin(measurement.date, start: start, end: end) && measurement.weightKg != nil {
            if earliest == nil || measurement.date < earliest!.date {
                earliest = measurement
            }
            if latest == nil || measurement.date > latest!.date {
                latest = measurement
            }
        }

        guard let first = earliest?.weightKg, let last = latest?.weightKg else { return nil }
        return last - first
    }
}

private struct ReviewPeriodSnapshot {
    let period: ReviewPeriod
    let startDate: Date
    let endDate: Date
    let buckets: [ReviewBucketSummary]
    let nutritionActiveDays: Int
    let mealCount: Int
    let averageCalories: Double
    let averageTDEE: Double
    let averageWaterMl: Double
    let workoutMinutes: Double
    let workoutCount: Int
    let workoutTargetMinutes: Int
    let habitCompletionRate: Double?
    let journalCount: Int
    let weightDelta: Double?
    let latestWeightKg: Double?
    let bowelCount: Int
    let normalBowelRatio: Double?

    var activityCoverage: Double {
        guard !buckets.isEmpty else { return 0 }
        let active = buckets.filter(\.hasAnyRecord).count
        return Double(active) / Double(buckets.count)
    }

    var workoutProgress: Double {
        guard workoutTargetMinutes > 0 else { return 0 }
        return min(workoutMinutes / Double(workoutTargetMinutes), 1)
    }

    var conclusion: String {
        if mealCount == 0 && workoutMinutes == 0 && journalCount == 0 && bowelCount == 0 {
            return "这个周期还没有足够记录，先从饮食或习惯补齐节奏。"
        }
        if activityCoverage >= 0.7 && workoutProgress >= 1 {
            return "\(period.title)记录覆盖稳定，训练目标已达成。"
        }
        if nutritionActiveDays > 0 && workoutMinutes == 0 {
            return "\(period.title)饮食有记录，训练曲线还空着。"
        }
        if activityCoverage < 0.35 {
            return "\(period.title)记录断点较多，先观察哪些天容易漏记。"
        }
        return "\(period.title)已有清晰节奏，可继续看热量、训练和身体变化。"
    }

    var calorieDeltaText: String {
        guard nutritionActiveDays > 0 else { return "暂无饮食记录" }
        let delta = averageCalories - averageTDEE
        if abs(delta) < 80 { return "接近TDEE" }
        return delta > 0 ? "日均高于TDEE \(Int(delta)) kcal" : "日均低于TDEE \(Int(abs(delta))) kcal"
    }

    var weightDeltaText: String {
        guard let weightDelta else { return "--" }
        if abs(weightDelta) < 0.05 { return "持平" }
        return String(format: "%@%.1fkg", weightDelta > 0 ? "+" : "", weightDelta)
    }

    var normalBowelText: String {
        guard let normalBowelRatio else { return "暂无排便记录" }
        return "正常 \(Int(normalBowelRatio * 100))%"
    }
}

private struct ReviewBucketSummary: Identifiable {
    var id: Date { startDate }

    let startDate: Date
    let endDate: Date
    let label: String
    let dayCount: Int
    let calories: Double
    let tdee: Double
    let hasMeal: Bool
    let waterMl: Double
    let workoutMinutes: Double
    let workoutCount: Int
    let completedHabitSlots: Int
    let totalHabitSlots: Int
    let journalCount: Int
    let weightKg: Double?
    let bowelCount: Int

    var hasHabitProgress: Bool { completedHabitSlots > 0 }
    var hasWorkout: Bool { workoutMinutes > 0 || workoutCount > 0 }
    var hasJournal: Bool { journalCount > 0 }
    var hasRecoveryRecord: Bool { weightKg != nil || bowelCount > 0 || waterMl > 0 }
    var hasAnyRecord: Bool { hasMeal || hasHabitProgress || hasWorkout || hasJournal || hasRecoveryRecord }
    var averageCaloriesPerDay: Double { calories / Double(max(dayCount, 1)) }

    var habitCompletionRatio: Double {
        guard totalHabitSlots > 0 else { return 0 }
        return Double(completedHabitSlots) / Double(totalHabitSlots)
    }

    var rhythmScore: Int {
        [hasMeal, hasHabitProgress, hasWorkout, hasJournal].filter { $0 }.count
    }
}

private struct ReviewInsightDashboard: View {
    let snapshot: ReviewPeriodSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(snapshot.period.title)趋势")
                        .font(.headline.weight(.black))
                    Text(snapshot.conclusion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SystemStatusBadge(text: snapshot.period.badgeTitle, tone: .neutral)
            }

            ReviewOverviewStrip(snapshot: snapshot)

            ReviewEnergyChart(snapshot: snapshot)

            ReviewRhythmHeatmap(snapshot: snapshot)

            ReviewRecoveryPanel(snapshot: snapshot)
        }
    }
}

private struct ReviewOverviewStrip: View {
    let snapshot: ReviewPeriodSnapshot

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ReviewMetricTile(
                title: "记录覆盖",
                value: "\(Int(snapshot.activityCoverage * 100))%",
                detail: "\(snapshot.buckets.filter(\.hasAnyRecord).count)/\(snapshot.buckets.count) 个周期点"
            )
            ReviewMetricTile(
                title: "日均热量",
                value: snapshot.nutritionActiveDays > 0 ? "\(Int(snapshot.averageCalories))" : "--",
                detail: snapshot.calorieDeltaText
            )
            ReviewMetricTile(
                title: "训练完成",
                value: "\(Int(snapshot.workoutProgress * 100))%",
                detail: "\(Int(snapshot.workoutMinutes))/\(snapshot.workoutTargetMinutes) 分"
            )
            ReviewMetricTile(
                title: "身体恢复",
                value: snapshot.weightDeltaText,
                detail: snapshot.bowelCount > 0 ? "排便 \(snapshot.bowelCount) 次 / \(snapshot.normalBowelText)" : "等待更多记录"
            )
        }
    }
}

private struct ReviewMetricTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(10)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }
}

private struct ReviewEnergyChart: View {
    let snapshot: ReviewPeriodSnapshot

    private var maxValue: Double {
        let bucketMax = snapshot.buckets.map(\.averageCaloriesPerDay).max() ?? 0
        let targetMax = snapshot.buckets.map(\.tdee).max() ?? 0
        return max(max(bucketMax, targetMax), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReviewChartHeader(
                title: "能量趋势",
                value: snapshot.nutritionActiveDays > 0 ? "\(snapshot.nutritionActiveDays) 天有记录" : "暂无记录"
            )

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .bottom, spacing: snapshot.period.barSpacing) {
                        ForEach(snapshot.buckets) { bucket in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: bucket))
                                .frame(height: barHeight(for: bucket, chartHeight: proxy.size.height))
                                .frame(maxWidth: .infinity, alignment: .bottom)
                                .accessibilityLabel("\(bucket.label) 日均 \(Int(bucket.averageCaloriesPerDay)) kcal")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    targetLine(in: proxy.size)
                }
            }
            .frame(height: 116)

            HStack {
                Label("TDEE均值 \(Int(snapshot.averageTDEE)) kcal", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text(snapshot.calorieDeltaText)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private func targetLine(in size: CGSize) -> some View {
        let buckets = snapshot.buckets
        return ZStack(alignment: .topLeading) {
            Path { path in
                for index in buckets.indices {
                    let point = targetPoint(index: index, size: size)
                    if index == buckets.startIndex {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(FamilyUI.accent.opacity(0.78), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            ForEach(Array(buckets.indices), id: \.self) { index in
                Circle()
                    .fill(FamilyUI.panelBackground)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(FamilyUI.accent, lineWidth: 1.5))
                    .position(targetPoint(index: index, size: size))
            }
        }
        .accessibilityLabel("TDEE折线")
    }

    private func targetPoint(index: Int, size: CGSize) -> CGPoint {
        let count = max(snapshot.buckets.count, 1)
        let slotWidth = size.width / CGFloat(count)
        let x = slotWidth * CGFloat(index) + slotWidth / 2
        let target = snapshot.buckets[index].tdee
        let y = size.height * (1 - CGFloat(min(target / maxValue, 1)))
        return CGPoint(x: x, y: y)
    }

    private func barHeight(for bucket: ReviewBucketSummary, chartHeight: CGFloat) -> CGFloat {
        guard bucket.hasMeal, maxValue > 0 else { return 8 }
        let ratio = min(bucket.averageCaloriesPerDay / maxValue, 1)
        return max(10, chartHeight * ratio)
    }

    private func barColor(for bucket: ReviewBucketSummary) -> Color {
        guard bucket.hasMeal else { return Color(.systemGray4).opacity(0.55) }
        let delta = bucket.averageCaloriesPerDay - bucket.tdee
        if delta > 250 { return FamilyUI.warning }
        if abs(delta) < 120 { return FamilyUI.success }
        return FamilyUI.accent
    }
}

private struct ReviewRhythmHeatmap: View {
    let snapshot: ReviewPeriodSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReviewChartHeader(
                title: "生活节奏",
                value: snapshot.habitCompletionRate.map { "\(Int(snapshot.activityCoverage * 100))% 覆盖 / 习惯 \(Int($0 * 100))%" }
                    ?? "\(Int(snapshot.activityCoverage * 100))% 覆盖"
            )

            LazyVGrid(columns: snapshot.period.heatmapColumns, spacing: 5) {
                ForEach(snapshot.buckets) { bucket in
                    ReviewRhythmCell(bucket: bucket)
                }
            }

            HStack(spacing: 10) {
                ReviewRhythmLegend(color: FamilyUI.accent, text: "饮食")
                ReviewRhythmLegend(color: FamilyUI.success, text: "习惯")
                ReviewRhythmLegend(color: FamilyUI.warning, text: "训练")
                ReviewRhythmLegend(color: Color(hex: "8b3a8b"), text: "状态")
            }
        }
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }
}

private struct ReviewRhythmCell: View {
    let bucket: ReviewBucketSummary

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .fill(cellFill)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder.opacity(0.7), lineWidth: 1)
                )

            HStack(spacing: 1.5) {
                marker(bucket.hasMeal, color: FamilyUI.accent)
                marker(bucket.hasHabitProgress, color: FamilyUI.success)
                marker(bucket.hasWorkout, color: FamilyUI.warning)
                marker(bucket.hasJournal, color: Color(hex: "8b3a8b"))
            }
            .padding(.bottom, 4)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(bucket.label) 节奏 \(bucket.rhythmScore)")
    }

    private var cellFill: Color {
        switch bucket.rhythmScore {
        case 4: return FamilyUI.accent.opacity(0.32)
        case 3: return FamilyUI.accent.opacity(0.24)
        case 2: return FamilyUI.accent.opacity(0.16)
        case 1: return FamilyUI.accent.opacity(0.09)
        default: return FamilyUI.panelBackground
        }
    }

    private func marker(_ isActive: Bool, color: Color) -> some View {
        Circle()
            .fill(isActive ? color : Color.clear)
            .frame(width: 3.5, height: 3.5)
    }
}

private struct ReviewRhythmLegend: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReviewRecoveryPanel: View {
    let snapshot: ReviewPeriodSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReviewChartHeader(
                title: "身体与恢复",
                value: snapshot.latestWeightKg.map { String(format: "%.1fkg", $0) } ?? "--"
            )

            HStack(alignment: .center, spacing: 12) {
                ReviewWeightSparkline(buckets: snapshot.buckets)
                    .frame(height: 72)

                VStack(alignment: .leading, spacing: 8) {
                    ReviewCompactMetric(title: "体重变化", value: snapshot.weightDeltaText)
                    ReviewCompactMetric(title: "饮水", value: "\(Int(snapshot.averageWaterMl)) ml")
                    ReviewCompactMetric(title: "排便", value: snapshot.bowelCount > 0 ? "\(snapshot.bowelCount) 次" : "--")
                    ReviewCompactMetric(title: "Bristol", value: snapshot.normalBowelText)
                }
                .frame(maxWidth: 128, alignment: .leading)
            }

            ReviewHydrationBowelTrendChart(buckets: snapshot.buckets)
        }
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }
}

private struct ReviewHydrationBowelTrendChart: View {
    let buckets: [ReviewBucketSummary]

    var body: some View {
        VStack(spacing: 8) {
            ReviewRecoveryTrendRow(
                title: "饮水趋势",
                value: waterSummary,
                color: FamilyUI.accent,
                values: buckets.map(\.waterMl)
            )
            ReviewRecoveryTrendRow(
                title: "排便趋势",
                value: bowelSummary,
                color: FamilyUI.success,
                values: buckets.map { Double($0.bowelCount) }
            )
        }
    }

    private var waterSummary: String {
        let active = buckets.filter { $0.waterMl > 0 }
        guard !active.isEmpty else { return "暂无饮水" }
        let average = active.reduce(0) { $0 + $1.waterMl } / Double(active.count)
        return "均 \(Int(average)) ml"
    }

    private var bowelSummary: String {
        let total = buckets.reduce(0) { $0 + $1.bowelCount }
        return total > 0 ? "\(total) 次" : "暂无排便"
    }
}

private struct ReviewRecoveryTrendRow: View {
    let title: String
    let value: String
    let color: Color
    let values: [Double]

    private var maxValue: Double {
        max(values.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(value > 0 ? color.opacity(0.78) : Color(.systemGray4).opacity(0.45))
                            .frame(height: barHeight(value, chartHeight: proxy.size.height))
                            .frame(maxWidth: .infinity, alignment: .bottom)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 44)
        }
    }

    private func barHeight(_ value: Double, chartHeight: CGFloat) -> CGFloat {
        guard value > 0 else { return 5 }
        return max(7, chartHeight * CGFloat(min(value / maxValue, 1)))
    }
}

private struct ReviewWeightSparkline: View {
    let buckets: [ReviewBucketSummary]

    private var points: [Double] {
        buckets.compactMap(\.weightKg)
    }

    var body: some View {
        GeometryReader { proxy in
            if points.count >= 2 {
                let minWeight = points.min() ?? 0
                let maxWeight = points.max() ?? 1
                let span = max(maxWeight - minWeight, 0.5)

                Path { path in
                    for index in points.indices {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                        let y = proxy.size.height * (1 - CGFloat((points[index] - minWeight) / span))
                        if index == points.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(FamilyUI.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.bold))
                    Text("等待体重趋势")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ReviewCompactMetric: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct ReviewChartHeader: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            Text(value)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private enum ReviewPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "周"
        case .month: return "月"
        case .quarter: return "季"
        case .year: return "年"
        }
    }

    var badgeTitle: String {
        switch self {
        case .week: return "本周"
        case .month: return "近一月"
        case .quarter: return "近一季"
        case .year: return "近一年"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .week: return .day
        case .month, .quarter: return .month
        case .year: return .year
        }
    }

    var value: Int {
        switch self {
        case .week: return -6
        case .month: return -1
        case .quarter: return -3
        case .year: return -1
        }
    }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    var barSpacing: CGFloat {
        switch self {
        case .week: return 8
        case .month: return 3
        case .quarter: return 5
        case .year: return 6
        }
    }

    var heatmapColumns: [GridItem] {
        let count: Int
        switch self {
        case .week: count = 7
        case .month: count = 10
        case .quarter: count = 7
        case .year: count = 6
        }
        return Array(repeating: GridItem(.flexible(), spacing: 5), count: count)
    }

    func workoutTargetMinutes(settings: UserSettings?) -> Int {
        let weekly = settings?.weeklyWorkoutTargetMinutes ?? 150
        switch self {
        case .week: return weekly
        case .month: return weekly * 4
        case .quarter: return weekly * 13
        case .year: return weekly * 52
        }
    }
}

private struct BodyMetricsCard: View {
    let measurements: [BodyMeasurement]
    let settings: UserSettings?
    let modelContext: ModelContext

    @State private var isShowingEditor = false
    @State private var bannerCenter = GlobalBannerCenter.shared

    private var latest: BodyMeasurement? { measurements.first }
    private var previous: BodyMeasurement? { measurements.dropFirst().first }
    private var bmiText: String? {
        guard let weight = latest?.weightKg ?? settings?.weightKg,
              let heightCm = settings?.heightCm,
              heightCm > 0 else { return nil }
        let heightM = heightCm / 100
        return String(format: "BMI %.1f", weight / (heightM * heightM))
    }

    var body: some View {
        SystemPanel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SystemStatusBadge(text: "身体数据", tone: latest == nil ? .warning : .accent)
                    Text(summaryTitle)
                        .font(.title3.weight(.black))
                    if let latest {
                        Text("最近记录：\(latest.date.dayDisplay)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("记录体重和体脂变化，也可以从 Apple Health 导入。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    isShowingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("新增身体测量")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }

            HStack(spacing: 10) {
                metricPill(
                    title: "体重",
                    value: latest?.weightKg.map { String(format: "%.1fkg", $0) } ?? "--",
                    delta: deltaText(current: latest?.weightKg, previous: previous?.weightKg, suffix: "kg"),
                    badge: bmiText
                )
                metricPill(
                    title: "体脂",
                    value: latest?.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? "--",
                    delta: deltaText(current: latest?.bodyFatPercentage, previous: previous?.bodyFatPercentage, suffix: "%")
                )
            }

            HStack(spacing: 8) {
                Button {
                    Task { await importFromHealth() }
                } label: {
                    Label("导入 Apple Health", systemImage: "heart.text.square.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FamilyUI.panelMutedBackground)
                        .foregroundStyle(FamilyUI.success)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }

            if !measurements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(measurements.prefix(5)) { measurement in
                        HStack {
                            Text(measurement.date.dayDisplay)
                                .font(.caption.weight(.medium))
                            Spacer()
                            if let weightKg = measurement.weightKg {
                                Text(String(format: "%.1fkg", weightKg))
                                    .font(.caption.weight(.semibold))
                            }
                            if let bodyFat = measurement.bodyFatPercentage {
                                Text(String(format: "%.1f%%", bodyFat))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(measurement.source.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            BodyMeasurementEditorSheet(modelContext: modelContext)
        }
    }

    private var summaryTitle: String {
        if let latestWeight = latest?.weightKg {
            return "当前体重 \(String(format: "%.1f", latestWeight)) kg"
        }
        if let latestBodyFat = latest?.bodyFatPercentage {
            return "当前体脂 \(String(format: "%.1f", latestBodyFat))%"
        }
        return "开始记录体重和体脂变化"
    }

    private func metricPill(title: String, value: String, delta: String, badge: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FamilyUI.accent)
                }
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(delta)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private func deltaText(current: Double?, previous: Double?, suffix: String) -> String {
        guard let current, let previous else { return "等待更多记录" }
        let delta = current - previous
        if abs(delta) < 0.05 { return "较上次无明显变化" }
        return String(format: "较上次 %@%.1f%@", delta > 0 ? "+" : "", delta, suffix)
    }

    private func importFromHealth() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            try? await HealthKitService.shared.requestActivityDetailAuthorization()
            guard let snapshot = try await HealthKitService.shared.latestBodyMeasurement() else {
                bannerCenter.show(title: "暂无可导入数据", message: "Apple Health 中暂无体重或体脂记录。", tone: .warning)
                return
            }
            if let existing = measurements.first(where: { $0.source == .appleHealth && $0.date.isSameDay(as: snapshot.date) }) {
                existing.weightKg = snapshot.weightKg
                existing.bodyFatPercentage = snapshot.bodyFatPercentage
                existing.updatedAt = .now
            } else {
                let measurement = BodyMeasurement(
                    date: snapshot.date,
                    weightKg: snapshot.weightKg,
                    bodyFatPercentage: snapshot.bodyFatPercentage,
                    source: .appleHealth,
                    syncedToAppleHealth: true,
                    note: "由 Apple Health 导入"
                )
                modelContext.insert(measurement)
            }
            if let weight = snapshot.weightKg {
                settings?.weightKg = weight
            }
            if let height = snapshot.heightCm {
                settings?.heightCm = height
            }
            settings?.updatedAt = .now
            try modelContext.save()
            HapticEngine.success()
            bannerCenter.show(title: "导入完成", message: "已同步 \(snapshot.date.dayDisplay) 的身体数据。", tone: .success)
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "导入失败", message: error.localizedDescription, tone: .error)
        }
    }
}

private struct BodyMeasurementEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext

    @State private var date = Date.now
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var syncToHealth = false
    @State private var note = ""
    @State private var bannerCenter = GlobalBannerCenter.shared

    private var canSave: Bool {
        Double(weightText) != nil || Double(bodyFatText) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "身体数据",
                        title: "记录身体数据",
                        detail: "手动记录体重和体脂，也可以同步到 Apple Health。"
                    )

                    SystemPanel {
                        editorHeader("测量数据", value: canSave ? "可保存" : "未填写")
                        DatePicker("时间", selection: $date, displayedComponents: [.date, .hourAndMinute])

                        SystemPanelDivider()
                        metricField("体重", text: $weightText, unit: "kg")
                        SystemPanelDivider()
                        metricField("体脂", text: $bodyFatText, unit: "%")
                    }

                    SystemPanel {
                        editorHeader("同步", value: syncToHealth ? "Apple Health" : "本机")
                        Toggle("同时写入 Apple Health", isOn: $syncToHealth)
                            .font(.subheadline.weight(.semibold))
                        Text("开启后会把本次体重/体脂记录同步写入 Apple Health。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SystemPanel {
                        editorHeader("备注", value: note.isEmpty ? "未填写" : "已填写")
                        TextField("例如：晨起空腹、训练后", text: $note, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("记录身体数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func editorHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value.uppercased(), tone: .neutral)
        }
    }

    private func metricField(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField(unit, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: 96)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func save() async {
        let weight = BodyMeasurementLimits.validatedWeight(Double(weightText))
        let bodyFat = BodyMeasurementLimits.validatedBodyFat(Double(bodyFatText))
        if let notice = BodyMeasurementLimits.outOfRangeNotice(
            weight: Double(weightText), height: nil, age: nil, bodyFat: Double(bodyFatText)
        ) {
            HapticEngine.warning()
            bannerCenter.show(title: "数值超出合理范围", message: notice, tone: .error)
            return
        }
        let measurement = BodyMeasurement(
            date: date,
            weightKg: weight,
            bodyFatPercentage: bodyFat,
            source: .manual,
            syncedToAppleHealth: syncToHealth,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(measurement)

        do {
            try modelContext.save()
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "保存失败", message: error.localizedDescription, tone: .error)
            return
        }

        if syncToHealth {
            do {
                try await HealthKitService.shared.requestAuthorization(needsWriteAccess: true)
                try await HealthKitService.shared.saveBodyMeasurement(weightKg: weight, bodyFatPercentage: bodyFat, date: date)
                measurement.syncedToAppleHealth = true
                measurement.updatedAt = .now
                try modelContext.save()
            } catch {
                HapticEngine.warning()
                bannerCenter.show(title: "同步 Apple Health 失败", message: "本地已保存，写入 Apple Health 失败：\(error.localizedDescription)", tone: .warning)
                return
            }
        }

        HapticEngine.success()
        bannerCenter.show(title: "保存完成", message: syncToHealth ? "身体数据已保存，并已尝试同步到 Apple Health。" : "身体数据已保存到本机。", tone: .success)
        dismiss()
    }
}

private struct MyLifeSummaryCard: View {
    let completedHabits: Int
    let totalHabits: Int
    let journalCount: Int
    let workoutMinutes: Double
    let latestJournal: JournalEntry?

    var body: some View {
        SystemPanel {
            VStack(alignment: .leading, spacing: 4) {
                SystemStatusBadge(text: "MY LIFE", tone: .accent)
                Text(summaryTitle)
                    .font(.title3.weight(.black))
                Text(summarySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                SummaryPill(title: "今日习惯", value: "\(completedHabits)/\(totalHabits)")
                SummaryPill(title: "今日训练", value: workoutMinutes > 0 ? "\(Int(workoutMinutes)) 分钟" : "未记录")
                SummaryPill(title: "状态记录", value: latestJournal?.date.isSameDay(as: .now) == true ? "今日已记" : "\(journalCount) 条")
            }
        }
    }

    private var summaryTitle: String {
        if totalHabits == 0 && journalCount == 0 { return "开始记录你的生活节奏" }
        if workoutMinutes > 0 { return "今天训练 \(Int(workoutMinutes)) 分钟" }
        if completedHabits == totalHabits && totalHabits > 0 { return "今天的习惯完成得不错" }
        return "持续追踪习惯和状态"
    }

    private var summarySubtitle: String {
        if let latestJournal {
            return "最近状态：\(latestJournal.date.dayDisplay)"
        }
        return "记录影响饮食和健康的每日状态。"
    }
}

private struct SummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }
}

private struct BowelTrackerCard: View {
    let logs: [BowelLog]
    let modelContext: ModelContext

    @State private var showAddSheet = false

    var body: some View {
        let todayLogs = logs.filter { $0.date.isSameDay(as: .now) }

        SystemPanel(title: "排便记录", detail: "今日排便记录") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todayLogs.isEmpty ? "今日暂无记录" : "今日排便 \(todayLogs.count) 次")
                        .font(.title3.weight(.black))
                    if let last = todayLogs.first {
                        Text("最近：\(last.bristolType.emoji) \(last.bristolType.displayName)  \(last.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("点击右侧按钮快速记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("新增排便记录")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }

            if !todayLogs.isEmpty {
                SystemPanelDivider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(todayLogs) { log in
                        HStack(spacing: 8) {
                            Text(log.bristolType.emoji)
                                .font(.body)
                            Text(log.bristolType.displayName)
                                .font(.caption.weight(.semibold))
                            if !log.note.isEmpty {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(log.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(log.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            BowelLogEditorSheet(modelContext: modelContext)
        }
    }
}

struct BowelLogEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext

    @State private var date: Date
    @State private var selectedType: BristolStoolType = .normal
    @State private var note = ""

    init(modelContext: ModelContext, initialDate: Date = .now) {
        self.modelContext = modelContext
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "排便记录",
                        title: "记录排便",
                        detail: "记录排便状态，追踪肠道健康规律。"
                    )

                    SystemPanel {
                        HStack {
                            Text("时间")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                            Spacer()
                        }
                        DatePicker("时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }

                    SystemPanel {
                        HStack {
                            Text("排便状态")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                            Spacer()
                            SystemStatusBadge(text: selectedType.displayName, tone: .accent)
                        }

                        VStack(spacing: 8) {
                            ForEach(BristolStoolType.allCases) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(type.emoji)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(type.displayName)
                                                .font(.subheadline.weight(.semibold))
                                            Text(type.bristolDescription)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedType == type {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(FamilyUI.accent)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selectedType == type ? FamilyUI.accent.opacity(0.08) : FamilyUI.panelMutedBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                            .stroke(selectedType == type ? FamilyUI.accent.opacity(0.4) : FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SystemPanel {
                        HStack {
                            Text("备注")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                            Spacer()
                        }
                        TextField("例如：饭后排便、腹部不适…", text: $note, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("排便记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func save() {
        let log = BowelLog(date: date, bristolType: selectedType, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(log)
        try? modelContext.save()
        HapticEngine.success()
        dismiss()
    }
}
