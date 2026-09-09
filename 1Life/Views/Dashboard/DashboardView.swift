import SwiftUI
import SwiftData
import HealthKit
import Combine

private struct DashboardDaySnapshot {
    let nutrition: DailyNutritionSummary
    let mealSummaries: [MealNutritionSummary]
    let workout: DailyWorkoutSummary
    let bowelLogs: [BowelLog]
    let completedHabitIDs: Set<UUID>
    let hasCompletedExerciseHabit: Bool

    var completedHabitsCount: Int { completedHabitIDs.count }
}

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\NutritionGoal.effectiveDate, order: .reverse)])
    private var nutritionGoals: [NutritionGoal]
    @Query private var allMeals: [Meal]
    @Query private var allWaterLogs: [WaterLog]
    @Query(filter: #Predicate<Habit> { !$0.isArchived })
    private var activeHabits: [Habit]
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)])
    private var journalEntries: [JournalEntry]
    @Query private var workouts: [WorkoutLog]
    @Query(sort: [SortDescriptor(\BowelLog.date, order: .reverse)])
    private var bowelLogs: [BowelLog]

    @State private var showNutritionDetails = false
    @State private var isShowingBowelEditor = false
    @State private var pendingWaterUndoLog: WaterLog?
    @State private var pendingWaterUndoMessage = ""
    @State private var waterUndoTask: Task<Void, Never>?
    @State private var healthEnergySummary: HealthEnergySummary?
    @State private var healthActivitySummary: HealthActivitySummary?
    @State private var sleepHours: Double?
    @State private var daylightMinutes: Double?
    @State private var isRefreshingHealth = false
    @Environment(\.scenePhase) private var scenePhase

    private let waterAmountOptions: [Double] = [50, 100, 150, 200, 250, 300, 500, 750, 1000]

    private var selectedDate: Date {
        appViewModel.selectedDate
    }

    private var selectedDateTitle: String {
        if selectedDate.isToday { return "今日" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "昨天" }
        return selectedDate.dayDisplay
    }

    private var selectedDateScopeLabel: String {
        selectedDate.isToday ? "今日" : "当日"
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { appViewModel.selectedDate },
            set: { appViewModel.selectedDate = min($0, Date.now) }
        )
    }

    private var currentSettings: UserSettings? { settings.first }
    private var currentGoal: NutritionGoal? { nutritionGoals.first }
    private var isBalancedMode: Bool { currentSettings?.dietGoalMode == .balanced }
    private var healthTDEE: Double? { healthEnergySummary?.tdeeKcal }

    private var todayJournal: JournalEntry? {
        journalEntries.first { $0.date.isSameDay(as: selectedDate) }
    }

    private var selectedDateBowelLogs: [BowelLog] {
        bowelLogs
            .filter { $0.date.isSameDay(as: selectedDate) }
    }

    private var effectiveTarget: EffectiveNutritionTarget {
        currentSettings?.effectiveTarget(healthTDEE: healthTDEE, goal: currentGoal)
            ?? EffectiveNutritionTarget.fallback
    }

    private var effectiveCalorieTarget: Double { effectiveTarget.calories }

    private func effectiveProteinTarget(workout: DailyWorkoutSummary, hasCompletedExerciseHabit: Bool) -> Double {
        let base = effectiveTarget.protein
        if workout.isTrainingDay { return WorkoutService.adjustedProteinTarget(base: base, workoutSummary: workout) }
        if hasCompletedExerciseHabit { return base * 1.10 }
        if workout.isRestDay { return WorkoutService.adjustedProteinTarget(base: base, workoutSummary: workout) }
        return base
    }

    private func effectiveCarbsTarget(workout: DailyWorkoutSummary) -> Double {
        WorkoutService.adjustedCarbsTarget(
            base: effectiveTarget.carbs,
            workoutSummary: workout
        )
    }

    private var effectiveFatTarget: Double { effectiveTarget.fat }

    var body: some View {
        let workout = WorkoutService.dailySummary(workouts: workouts, for: selectedDate)
        let completedHabitIDs = Set(activeHabits.filter { isHabitCompleted($0) }.map(\.id))
        let snapshot = DashboardDaySnapshot(
            nutrition: NutritionService.dailySummary(meals: allMeals, waterLogs: allWaterLogs, for: selectedDate),
            mealSummaries: NutritionService.mealTypeSummaries(meals: allMeals, for: selectedDate),
            workout: workout,
            bowelLogs: selectedDateBowelLogs,
            completedHabitIDs: completedHabitIDs,
            hasCompletedExerciseHabit: activeHabits.contains { habit in
                ["运动", "跑步", "健身", "训练", "拉伸"].contains { habit.name.contains($0) }
                    && completedHabitIDs.contains(habit.id)
            }
        )

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    dateSelectorPanel
                    heroCard(snapshot: snapshot)
                    mealStatusPanel(mealSummaries: snapshot.mealSummaries)
                    nutritionDetailsSection(snapshot: snapshot)
                    healthMetricsRow(workout: snapshot.workout)
                    waterCard(nutrition: snapshot.nutrition)
                    bowelCard(logs: snapshot.bowelLogs)
                    quickStatusRow(snapshot: snapshot)
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 0)
                .padding(.bottom, AppSpacing.pageBottom)
            }
            .scrollIndicators(.hidden)
            .background(FamilyUI.pageBackground)
            .navigationTitle(selectedDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if pendingWaterUndoLog != nil {
                    waterUndoBar
                        .padding(.horizontal, AppSpacing.pageHorizontal)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: selectedDate) {
                await refreshHealthData()
            }
            .sheet(isPresented: $isShowingBowelEditor) {
                BowelLogEditorSheet(modelContext: modelContext, initialDate: bowelLogDate())
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshHealthData() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthEnergyDidUpdate).receive(on: RunLoop.main)) { _ in
                Task { await refreshHealthData() }
            }
        }
    }

    private var dateSelectorPanel: some View {
        SystemPanel(title: "日期选择", detail: "切换查看某一天的热量、营养、饮水与生活记录") {
            DaySelectorView(selectedDate: selectedDateBinding)
        }
    }

    // MARK: - Hero Card

    private func heroCard(snapshot: DashboardDaySnapshot) -> some View {
        let calorieTarget = effectiveCalorieTarget
        let progress = calorieTarget > 0 ? snapshot.nutrition.totalCalories / calorieTarget : 0
        let remainingCalories = Int((calorieTarget - snapshot.nutrition.totalCalories).rounded())
        let targetLabel = isBalancedMode ? "参考目标" : "\(selectedDateScopeLabel)目标"

        return SystemPanel(title: "\(selectedDateScopeLabel)摄入", detail: "\(selectedDateTitle)摄入、目标差值与宏量营养执行情况") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("总摄入")
                        .font(FamilyTypography.sectionLabel)
                        .tracking(1)
                        .foregroundStyle(FamilyUI.inkSoft)
                    Spacer()
                    Text("\(Int(max(progress * 100, 0)))%")
                        .font(.custom("Archivo-Bold", size: 11))
                        .monospacedDigit()
                        .foregroundStyle(FamilyUI.inkSoft)
                    Text(targetLabel)
                        .font(FamilyTypography.sectionLabel)
                        .tracking(1)
                        .foregroundStyle(FamilyUI.inkSoft)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(snapshot.nutrition.totalCalories))")
                        .font(FamilyTypography.hero)
                        .monospacedDigit()
                    Text("/ \(Int(calorieTarget)) kcal")
                        .font(.custom("Archivo-SemiBold", size: 16))
                        .monospacedDigit()
                        .foregroundStyle(FamilyUI.inkSoft)
                    Spacer()
                }

                // Ledger tick: hairline track, single accent fill.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(FamilyUI.hairlineSubtle)
                        Rectangle()
                            .fill(progressColor(progress))
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 2)

                HStack(spacing: 8) {
                    SystemStatusBadge(
                        text: remainingCalories >= 0 ? "剩余 \(remainingCalories)" : "超出 \(abs(remainingCalories))",
                        tone: remainingCalories >= 0 ? .accent : .danger
                    )
                    if currentSettings?.useHealthKitForDynamicTDEE == true, healthTDEE != nil {
                        SystemStatusBadge(text: "动态", tone: .neutral)
                    }
                    if isBalancedMode {
                        SystemStatusBadge(text: "参考", tone: .neutral)
                    }
                }
            }

            SystemPanelDivider()

            HStack(spacing: 12) {
                MetricStrip(title: targetLabel, value: "\(Int(calorieTarget)) kcal", tone: .neutral)
                MetricStrip(title: "餐次", value: "\(snapshot.mealSummaries.filter { $0.totalCalories > 0 }.count)", tone: .accent)
                MetricStrip(title: "饮水", value: "\(Int(snapshot.nutrition.totalWaterMl)) ml", tone: .success)
            }

            SystemPanelDivider()

            spotlightNutrientGrid(snapshot: snapshot)
        }
    }

    private func spotlightNutrientGrid(snapshot: DashboardDaySnapshot) -> some View {
        let keys = currentSettings?.spotlightNutrientKeys ?? [.protein, .carbs, .fat, .fiber, .sodium]
        return VStack(spacing: 0) {
            ForEach(Array(keys.enumerated()), id: \.element.id) { index, key in
                let nv = nutrientValue(for: key, snapshot: snapshot)
                MacroProgressRow(
                    name: key.shortDisplayName,
                    current: nv.current,
                    target: nv.target,
                    color: key.spotlightColor,
                    unit: key.unit
                )
                if index < keys.count - 1 {
                    SystemPanelDivider()
                }
            }
        }
    }

    private func progressColor(_ progress: Double) -> Color {
        if isBalancedMode { return FamilyUI.accent }
        if progress > 1.0 { return FamilyUI.danger }
        if progress > 0.8 { return FamilyUI.warning }
        return FamilyUI.accent
    }

    private func mealStatusPanel(mealSummaries: [MealNutritionSummary]) -> some View {
        SystemPanel(title: "餐食快照", detail: "\(selectedDateTitle)各餐次是否已记录，以及每餐热量概览。点击餐次可到饮食页补记。") {
            VStack(spacing: 0) {
                ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, type in
                    let meal = mealSummaries.first { $0.mealType == type }
                    let hasMeal = meal != nil

                    Button {
                        if hasMeal {
                            appViewModel.navigateToExistingMeal(type)
                        } else {
                            appViewModel.navigateToFood(mealType: type)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(hasMeal ? FamilyUI.ink : Color.clear)
                                .frame(width: 8, height: 8)
                                .overlay(Rectangle().stroke(hasMeal ? FamilyUI.ink : FamilyUI.ink, lineWidth: 1))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.custom("Archivo-SemiBold", size: 13.5))
                                    .foregroundStyle(FamilyUI.ink)
                                Text(mealMetaLabel(meal))
                                    .font(.custom("Archivo-Regular", size: 10.5))
                                    .foregroundStyle(FamilyUI.inkSoft)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(mealCalorieLabel(meal))
                                    .font(.custom("Archivo-Bold", size: 13.5))
                                    .monospacedDigit()
                                    .foregroundStyle(hasMeal ? FamilyUI.ink : FamilyUI.inkSoft)
                                SystemStatusBadge(text: hasMeal ? "已记录" : "可补记", tone: hasMeal ? .neutral : .accent)
                            }
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < MealType.allCases.count - 1 {
                        SystemPanelDivider()
                    }
                }
            }
        }
    }

    private func mealMetaLabel(_ meal: MealNutritionSummary?) -> String {
        guard let meal else { return "尚未记录" }
        if meal.mealCount > 1 { return "\(meal.mealCount) 份 · \(meal.foodItemCount) 项" }
        return "\(meal.foodItemCount) 项"
    }

    private func mealCalorieLabel(_ meal: MealNutritionSummary?) -> String {
        guard let meal, meal.totalCalories > 0 else { return "—" }
        return "\(Int(meal.totalCalories)) kcal"
    }

    private func nutrientValue(for key: NutrientKey, snapshot: DashboardDaySnapshot) -> NutrientValue {
        let target = effectiveTarget
        switch key {
        case .protein: return NutrientValue(key: key, current: snapshot.nutrition.totalProtein, target: effectiveProteinTarget(workout: snapshot.workout, hasCompletedExerciseHabit: snapshot.hasCompletedExerciseHabit))
        case .carbs: return NutrientValue(key: key, current: snapshot.nutrition.totalCarbs, target: effectiveCarbsTarget(workout: snapshot.workout))
        case .fat: return NutrientValue(key: key, current: snapshot.nutrition.totalFat, target: effectiveTarget.fat)
        default: return NutrientValue(key: key, current: summaryValue(for: key, nutrition: snapshot.nutrition), target: target.value(for: key))
        }
    }

    private func summaryValue(for key: NutrientKey, nutrition: DailyNutritionSummary) -> Double? {
        switch key {
        case .protein: return nutrition.totalProtein
        case .carbs: return nutrition.totalCarbs
        case .fat: return nutrition.totalFat
        case .fiber: return nutrition.totalFiber
        case .sodium: return nutrition.totalSodium
        case .sugar: return nutrition.totalSugar
        case .cholesterol: return nutrition.totalCholesterol
        case .caffeine: return nutrition.totalCaffeine
        case .teaPolyphenols: return nutrition.totalTeaPolyphenols
        case .calcium: return nutrition.totalCalcium
        case .magnesium: return nutrition.totalMagnesium
        case .potassium: return nutrition.totalPotassium
        case .iron: return nutrition.totalIron
        case .zinc: return nutrition.totalZinc
        case .vitaminA: return nutrition.totalVitaminA
        case .vitaminC: return nutrition.totalVitaminC
        case .vitaminD: return nutrition.totalVitaminD
        case .vitaminE: return nutrition.totalVitaminE
        case .vitaminB1: return nutrition.totalVitaminB1
        case .vitaminB2: return nutrition.totalVitaminB2
        case .niacin: return nutrition.totalNiacin
        case .vitaminB6: return nutrition.totalVitaminB6
        case .folate: return nutrition.totalFolate
        case .vitaminB12: return nutrition.totalVitaminB12
        }
    }

    // MARK: - Nutrition Details

    private func nutritionDetailsSection(snapshot: DashboardDaySnapshot) -> some View {
        SystemPanel(title: "营养素", detail: "展开查看完整营养素执行情况") {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showNutritionDetails.toggle() }
            } label: {
                HStack {
                    Text(showNutritionDetails ? "收起营养素明细" : "查看全部营养素")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showNutritionDetails ? -180 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
            .buttonStyle(.plain)

            if showNutritionDetails, currentGoal != nil {
                SystemPanelDivider()

                VStack(spacing: 6) {
                    ForEach(NutrientDefinitions.dashboardGroups) { definition in
                        NutrientGroupBlock(
                            title: definition.group.displayName,
                            values: definition.keys.map { nutrientValue(for: $0, snapshot: snapshot) }
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showNutritionDetails)
    }

    // MARK: - Health Metrics Row

    private func healthMetricsRow(workout: DailyWorkoutSummary) -> some View {
        SystemPanel(title: "健康指标", detail: "步数、睡眠、训练与日照摘要") {
            HStack(spacing: 0) {
                HealthMetricItem(
                    icon: "figure.walk",
                    label: "步数",
                    value: healthActivitySummary.map { "\(Int($0.stepCount))" } ?? "—",
                    color: FamilyUI.ink
                )
                HealthMetricItem(
                    icon: "bed.double.fill",
                    label: "睡眠",
                    value: sleepHours.map { String(format: "%.1fh", $0) } ?? "—",
                    color: FamilyUI.ink
                )
                HealthMetricItem(
                    icon: "figure.run",
                    label: "运动",
                    value: "\(Int(workout.totalDurationMinutes))分",
                    color: FamilyUI.ink
                )
                HealthMetricItem(
                    icon: "sun.max.fill",
                    label: "日照",
                    value: daylightMinutes.map { "\(Int($0))分" } ?? "—",
                    color: FamilyUI.ink
                )
            }

            SystemPanelDivider()

            Button {
                Task { await refreshHealthData() }
            } label: {
                HStack(spacing: 8) {
                    if isRefreshingHealth {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FamilyUI.accent)
                    }
                    Text(isRefreshingHealth ? "读取中…" : "点击从 Apple Health 同步")
                        .font(.caption)
                        .foregroundStyle(isRefreshingHealth ? .secondary : .primary)
                    Spacer()
                    if let tdee = healthTDEE {
                        SystemStatusBadge(text: "TDEE \(Int(tdee)) kcal", tone: .neutral)
                    } else if currentSettings?.isHealthKitEnabled != true {
                        SystemStatusBadge(text: "未授权", tone: .neutral)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(currentSettings?.isHealthKitEnabled != true || isRefreshingHealth)
        }
    }

    // MARK: - Water Card

    private func waterCard(nutrition: DailyNutritionSummary) -> some View {
        let target = currentSettings?.dailyWaterGoalMl ?? 2000
        let current = nutrition.totalWaterMl
        let progress = target > 0 ? current / target : 0

        return SystemPanel(title: "饮水", detail: "当天饮水进度与快捷记录") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(waterProgressText(current: current, target: target))
                        .font(.custom("Archivo-Black", size: 28))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(progress >= 1 ? "已达到饮水目标" : "还差 \(Int(max(target - current, 0))) ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    ForEach(waterAmountOptions, id: \.self) { amount in
                        Button("\(Int(amount)) ml") {
                            addWater(amount)
                        }
                    }
                } label: {
                    Text("+ 记录饮水")
                        .font(.custom("Archivo-Bold", size: 14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(FamilyUI.ink)
                        .foregroundStyle(FamilyUI.pageBackground)
                }
            }

            ProgressView(value: min(progress, 1.0))
                .tint(FamilyUI.accent)
        }
    }

    // MARK: - Bowel Card

    private func bowelCard(logs: [BowelLog]) -> some View {
        return SystemPanel(title: "排便", detail: "\(selectedDateTitle)排便记录与补记") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(logs.isEmpty ? "\(selectedDateTitle)暂无记录" : "\(selectedDateTitle)排便 \(logs.count) 次")
                        .font(.title3.weight(.black))
                    if let last = logs.first {
                        Text("最近：\(last.bristolType.emoji) \(last.bristolType.displayName)  \(last.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("可通过上方日期选择补记过去某一天")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    HapticEngine.tap()
                    isShowingBowelEditor = true
                } label: {
                    Label("记录", systemImage: "plus")
                        .font(.custom("Archivo-Bold", size: 14))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(FamilyUI.ink)
                        .foregroundStyle(FamilyUI.pageBackground)
                }
            }

            if !logs.isEmpty {
                SystemPanelDivider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(logs.prefix(4)) { log in
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
    }

    private var waterUndoBar: some View {
        HStack(spacing: 10) {
            Text(pendingWaterUndoMessage)
                .font(.caption)
                .foregroundStyle(FamilyUI.pageBackground)
            Spacer()
            Button("撤销") {
                undoLastWaterLog()
            }
            .font(.custom("Archivo-Bold", size: 12))
            .foregroundStyle(FamilyUI.pageBackground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FamilyUI.ink)
    }

    private func addWater(_ amount: Double) {
        HapticEngine.tap()
        let log = WaterLog(date: waterLogDate(), amount: amount)
        modelContext.insert(log)
        pendingWaterUndoLog = log
        pendingWaterUndoMessage = "已追加 \(Int(amount)) ml"

        waterUndoTask?.cancel()
        waterUndoTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    pendingWaterUndoLog = nil
                    pendingWaterUndoMessage = ""
                }
            }
        }
    }

    private func waterProgressText(current: Double, target: Double) -> String {
        if current >= 1000 || target >= 1000 {
            return "\(formatLiters(current)) / \(formatLiters(target)) L"
        }
        return "\(Int(current)) / \(Int(target)) ml"
    }

    private func formatLiters(_ ml: Double) -> String {
        let liters = ml / 1000
        if abs(liters.rounded() - liters) < 0.01 {
            return "\(Int(liters.rounded()))"
        }
        return String(format: "%.1f", liters)
    }

    private func undoLastWaterLog() {
        guard let log = pendingWaterUndoLog else { return }
        HapticEngine.warning()
        waterUndoTask?.cancel()
        modelContext.delete(log)
        withAnimation {
            pendingWaterUndoLog = nil
            pendingWaterUndoMessage = ""
        }
    }

    private func waterLogDate() -> Date {
        if selectedDate.isToday { return .now }
        let calendar = Calendar.current
        let current = calendar.dateComponents([.hour, .minute], from: Date.now)
        return calendar.date(bySettingHour: current.hour ?? 12, minute: current.minute ?? 0, second: 0, of: selectedDate) ?? selectedDate
    }

    private func bowelLogDate() -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDate)
        if selectedDate.isToday {
            return .now
        }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    @MainActor
    private func refreshHealthData() async {
        guard currentSettings?.isHealthKitEnabled == true else {
            healthEnergySummary = nil
            healthActivitySummary = nil
            sleepHours = nil
            daylightMinutes = nil
            return
        }
        isRefreshingHealth = true
        defer { isRefreshingHealth = false }
        let hs = HealthKitService.shared
        async let energySummary = try? await hs.energySummary(for: selectedDate, settings: currentSettings)
        async let activitySummary = try? await hs.activitySummary(for: selectedDate)
        async let sleepHours = try? await hs.sleepHours(for: selectedDate)
        async let daylightMinutes = try? await hs.daylightMinutes(for: selectedDate)

        let (nextEnergySummary, nextActivitySummary, nextSleepHours, nextDaylightMinutes) = await (
            energySummary,
            activitySummary,
            sleepHours,
            daylightMinutes
        )
        healthEnergySummary = nextEnergySummary
        healthActivitySummary = nextActivitySummary
        self.sleepHours = nextSleepHours
        self.daylightMinutes = nextDaylightMinutes
        syncDynamicGoalIfNeeded()
    }

    private func syncDynamicGoalIfNeeded() {
        guard selectedDate.isToday,
              let settings = currentSettings,
              settings.useHealthKitForDynamicTDEE,
              let goal = currentGoal,
              let tdee = healthEnergySummary?.tdeeKcal else { return }

        let calories = settings.calorieTarget(from: tdee)
        goal.dailyCalories = calories
        goal.updatedAt = .now
    }

    // MARK: - Quick Status Row

    private func quickStatusRow(snapshot: DashboardDaySnapshot) -> some View {
        SystemPanel(title: "生活记录", detail: "习惯、训练与日记摘要，点击对应区域进入") {
            HStack {
                HStack(spacing: 8) {
                    SystemStatusBadge(
                        text: activeHabits.isEmpty ? "无习惯" : "\(snapshot.completedHabitsCount)/\(activeHabits.count) 习惯",
                        tone: activeHabits.isEmpty ? .neutral : .success
                    )
                    if snapshot.workout.totalDurationMinutes > 0 {
                        SystemStatusBadge(text: "已训练", tone: .accent)
                    }
                }
                Spacer()
            }

            if !activeHabits.isEmpty {
                SystemPanelDivider()

                Button {
                    openMyLife(.habits)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(FamilyUI.success)
                            Text("每日习惯")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("\(snapshot.completedHabitsCount)/\(activeHabits.count) 完成")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            ForEach(activeHabits.prefix(8)) { habit in
                                let done = snapshot.completedHabitIDs.contains(habit.id)
                                VStack(spacing: 2) {
                                    Image(systemName: habit.iconSymbol)
                                        .font(.caption2)
                                        .foregroundStyle(done ? Color(hex: habit.colorHex) : Color(.systemGray4))
                                        .frame(width: 26, height: 26)
                                        .background(done ? Color(hex: habit.colorHex).opacity(0.12) : Color(.systemGray6))
                                    Text(String(habit.name.prefix(2)))
                                        .font(.custom("Archivo-Regular", size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            SystemPanelDivider()

            Button {
                openMyLife(.workouts)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.caption)
                        .foregroundStyle(FamilyUI.accent)
                    if snapshot.workout.totalDurationMinutes > 0 {
                        Text("训练 \(Int(snapshot.workout.totalDurationMinutes))分钟")
                            .font(.caption)
                        if snapshot.workout.totalCaloriesBurned > 0 {
                            Text("· 消耗 \(Int(snapshot.workout.totalCaloriesBurned)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if snapshot.workout.isRestDay {
                        Text("休息日")
                            .font(.caption)
                            .foregroundStyle(FamilyUI.inkSoft)
                    } else {
                        Text("\(selectedDateTitle)还没有训练")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if let journal = todayJournal {
                SystemPanelDivider()

                Button {
                    openMyLife(.journal)
                } label: {
                    HStack(spacing: 8) {
                        if let mood = journal.mood {
                            Text(mood.emoji)
                                .font(.body)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(journal.content)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if !journal.activityTags.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(journal.activityTags.prefix(3)) { tag in
                                        Text(tag.displayName)
                                            .font(.custom("Archivo-Medium", size: 10))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .foregroundStyle(FamilyUI.inkSoft)
                                            .overlay(
                                                Rectangle().stroke(FamilyUI.hairlineRegular, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                SystemPanelDivider()

                Button {
                    openMyLife(.journal)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("记录\(selectedDateTitle)的状态和心情")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openMyLife(_ focus: MyLifeFocus) {
        HapticEngine.tap()
        withAnimation(.snappy(duration: 0.28)) {
            appViewModel.myLifeFocus = focus
            appViewModel.selectedTab = .myLife
        }
    }

    // MARK: - Helpers

    private func isHabitCompleted(_ habit: Habit) -> Bool {
        let dayLogs = (habit.logs ?? []).filter { $0.date.isSameDay(as: selectedDate) }
        let total = dayLogs.reduce(0) { $0 + $1.value }
        return total >= (habit.targetCount ?? 1)
    }
}

// MARK: - Sub Components

private struct HealthMetricItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("Archivo-Medium", size: 11))
                .monospacedDigit()
                .foregroundStyle(value == "—" ? .tertiary : .primary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }
}

private struct MacroProgressRow: View {
    let name: String
    let current: Double?
    let target: Double
    let color: Color
    let unit: String

    var body: some View {
        let progress = (target > 0 && current != nil) ? current! / target : 0
        HStack(spacing: 10) {
            Text(name)
                .font(FamilyTypography.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(FamilyUI.inkSoft)
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(FamilyUI.hairlineSubtle)
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 3)

            Text(current.map { "\(Int($0)) / \(Int(target))\(unit)" } ?? "— / \(Int(target))\(unit)")
                .font(.custom("Archivo-SemiBold", size: 11))
                .monospacedDigit()
                .foregroundStyle(progress > 1 ? FamilyUI.danger : FamilyUI.ink)
                .frame(width: 86, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

private struct MetricStrip: View {
    enum Tone {
        case neutral
        case accent
        case success

        var color: Color {
            switch self {
            case .neutral:
                return .primary
            case .accent:
                return FamilyUI.accent
            case .success:
                return FamilyUI.success
            }
        }
    }

    let title: String
    let value: String
    let tone: Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FamilyTypography.sectionLabel)
                .tracking(1)
                .foregroundStyle(FamilyUI.inkSoft)
            Text(value)
                .font(.custom("Archivo-Bold", size: 15))
                .foregroundStyle(tone.color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NutrientRow: View {
    let value: NutrientValue

    private var current: Double { value.current ?? 0 }
    private var pct: Int {
        guard value.target > 0 else { return 0 }
        return Int((current / value.target * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(value.key.displayName)
                    .font(.caption)
                Spacer()
                Text("\(pct)%")
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(pctColor)
            }
            ProgressView(value: min(current / max(value.target, 1), 1.0))
                .tint(pctColor)
            Text("\(format(current)) / \(format(value.target)) \(value.key.unit)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var pctColor: Color {
        if pct > 100 { return FamilyUI.danger }
        if pct > 80 { return FamilyUI.success }
        return FamilyUI.ink
    }

    private func format(_ value: Double) -> String {
        if value >= 10 { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }
}

private struct NutrientGroupBlock: View {
    let title: String
    let values: [NutrientValue]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(values) { value in
                    NutrientRow(value: value)
                }
            }
        }
        .padding(.bottom, 6)
    }
}
