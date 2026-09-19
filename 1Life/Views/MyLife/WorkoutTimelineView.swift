import SwiftUI
import SwiftData

struct WorkoutTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var waterLogs: [WaterLog]
    @Query(sort: [SortDescriptor(\WorkoutLog.startDate, order: .reverse)])
    private var workouts: [WorkoutLog]

    @State private var isShowingEditor = false
    @State private var editingWorkout: WorkoutLog?
    @State private var calendarMonth = Date.now
    @State private var showGoalSettings = false
    @State private var showCalendar = false
    @State private var showWorkoutHistory = true
    @State private var bannerCenter = GlobalBannerCenter.shared
    @State private var weeklyGoalCountText = ""
    @State private var weeklyGoalMinutesText = ""
    @State private var goalInputError: String?

    private var groupedWorkouts: [(date: Date, workouts: [WorkoutLog])] {
        let groups = Dictionary(grouping: workouts) { $0.startDate.startOfDay }
        return groups
            .map { (date: $0.key, workouts: $0.value.sorted { $0.startDate > $1.startDate }) }
            .sorted { $0.date > $1.date }
    }

    private var monthDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: calendarMonth)) ?? calendarMonth.startOfDay
        let weekdayOffset = calendar.component(.weekday, from: start) - 1
        let gridStart = calendar.date(byAdding: .day, value: -weekdayOffset, to: start) ?? start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private var currentSettings: UserSettings? { settings.first }

    private var weeklySummary: WeeklyWorkoutSummary {
        WorkoutService.weeklySummary(
            workouts: workouts,
            targetCount: currentSettings?.weeklyWorkoutTargetCount ?? 3,
            targetMinutes: currentSettings?.weeklyWorkoutTargetMinutes ?? 150
        )
    }

    private var todayWorkoutSummary: DailyWorkoutSummary {
        WorkoutService.dailySummary(workouts: workouts, for: .now)
    }

    private var todayWaterMl: Double {
        waterLogs.filter { $0.date.isSameDay(as: .now) }.reduce(0) { $0 + $1.amount }
    }

    private var nextWorkout: WorkoutLog? {
        workouts
            .filter { !$0.isRestDay && $0.startDate > .now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    var body: some View {
        SystemPanel {
            HStack {
                SystemStatusBadge(text: "WORKOUTS \(workouts.count)", tone: workouts.isEmpty ? .warning : .accent)
                Spacer()
                Button {
                    HapticEngine.tap()
                    editingWorkout = nil
                    isShowingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await importHealthWorkouts() }
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

            weeklyGoalCard

            Button {
                withAnimation { showCalendar.toggle() }
            } label: {
                HStack {
                    Text("训练日历")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showCalendar ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
            .buttonStyle(.plain)

            if showCalendar {
                workoutCalendar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if workouts.isEmpty {
                Button {
                    editingWorkout = nil
                    isShowingEditor = true
                } label: {
                    HStack {
                        Image(systemName: "figure.run")
                        Text("记录第一次训练或休息日")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            } else {
                Button {
                    withAnimation { showWorkoutHistory.toggle() }
                } label: {
                    HStack {
                        Text("训练记录 (\(workouts.count))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showWorkoutHistory ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .buttonStyle(.plain)

                if showWorkoutHistory {
                    ForEach(groupedWorkouts, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.date.sectionHeaderDisplay)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(group.workouts) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout) {
                                        editingWorkout = workout
                                        isShowingEditor = true
                                    }
                                } label: {
                                    WorkoutRow(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            WorkoutEditorView(workout: editingWorkout)
        }
    }

    private var isDefaultGoal: Bool {
        guard let s = currentSettings else { return true }
        return s.weeklyWorkoutTargetCount == 3 && s.weeklyWorkoutTargetMinutes == 150
    }

    @ViewBuilder
    private var weeklyGoalCard: some View {
        let weekly = weeklySummary
        let today = todayWorkoutSummary
        let water = todayWaterMl
        let upcomingWorkout = nextWorkout

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本周目标")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isDefaultGoal && !showGoalSettings {
                    Button {
                        withAnimation { showGoalSettings = true }
                    } label: {
                        Text("设定目标")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(FamilyUI.accent)
                    }
                } else {
                    Text(weekly.isTargetMet ? "已达标" : "进行中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(weekly.isTargetMet ? FamilyUI.success : FamilyUI.accent)
                }
                Button {
                    withAnimation { showGoalSettings.toggle() }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !isDefaultGoal || showGoalSettings {
                HStack(spacing: 8) {
                    WorkoutMetricPill(title: "次数", value: "\(weekly.completedCount)/\(weekly.targetCount)")
                    WorkoutMetricPill(title: "分钟", value: "\(Int(weekly.totalMinutes))/\(weekly.targetMinutes)")
                    WorkoutMetricPill(title: "连续", value: "\(WorkoutService.trainingStreak(workouts: workouts))天")
                }
            }

            if showGoalSettings, let settings = currentSettings {
                VStack(spacing: 8) {
                    goalInputRow(
                        label: "每周次数",
                        unit: "次",
                        value: $weeklyGoalCountText
                    )
                    .onChange(of: weeklyGoalCountText) { _, newValue in
                        validateWeeklyGoalCount(newValue, settings: settings)
                    }
                    goalInputRow(
                        label: "每周时长",
                        unit: "分钟",
                        value: $weeklyGoalMinutesText
                    )
                    .onChange(of: weeklyGoalMinutesText) { _, newValue in
                        validateWeeklyGoalMinutes(newValue, settings: settings)
                    }

                    if let goalInputError {
                        Text(goalInputError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FamilyUI.danger)
                    }

                    Toggle("周目标提醒", isOn: Binding(
                        get: { settings.isWorkoutTargetReminderEnabled },
                        set: {
                            settings.isWorkoutTargetReminderEnabled = $0
                            settings.updatedAt = .now
                            updateWorkoutReminders(settings)
                        }
                    ))
                    Toggle("恢复提醒", isOn: Binding(
                        get: { settings.isWorkoutRestReminderEnabled },
                        set: {
                            settings.isWorkoutRestReminderEnabled = $0
                            settings.updatedAt = .now
                            updateWorkoutReminders(settings)
                        }
                    ))

                    Text(WorkoutService.weeklyReportText(weekly: weekly))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(WorkoutService.preWorkoutMealTimingSuggestion(nextWorkout: upcomingWorkout))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(WorkoutService.hydrationRecommendation(
                        workoutSummary: today,
                        currentWaterMl: water,
                        baseTargetMl: currentSettings?.dailyWaterGoalMl ?? 2000
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
        .onAppear {
            if weeklyGoalCountText.isEmpty {
                weeklyGoalCountText = String(currentSettings?.weeklyWorkoutTargetCount ?? 3)
            }
            if weeklyGoalMinutesText.isEmpty {
                weeklyGoalMinutesText = String(currentSettings?.weeklyWorkoutTargetMinutes ?? 150)
            }
        }
    }

    private func goalInputRow(label: String, unit: String, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField(unit, text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: 80)
                .background(FamilyUI.panelBackground)
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

    private func validateWeeklyGoalCount(_ text: String, settings: UserSettings) {
        guard !text.isEmpty else {
            goalInputError = "每周次数不能为空，范围为 1–14 次。"
            return
        }
        guard let value = Int(text), (1...14).contains(value) else {
            goalInputError = "每周次数请输入 1–14 之间的整数。"
            return
        }
        settings.weeklyWorkoutTargetCount = value
        settings.updatedAt = .now
        goalInputError = nil
    }

    private func validateWeeklyGoalMinutes(_ text: String, settings: UserSettings) {
        guard !text.isEmpty else {
            goalInputError = "每周时长不能为空，范围为 30–900 分钟。"
            return
        }
        guard let value = Int(text), (30...900).contains(value) else {
            goalInputError = "每周时长请输入 30–900 之间的整数。"
            return
        }
        settings.weeklyWorkoutTargetMinutes = value
        settings.updatedAt = .now
        goalInputError = nil
    }

    private func updateWorkoutReminders(_ settings: UserSettings) {
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.removeWorkoutReminders()
        if settings.isWorkoutTargetReminderEnabled {
            NotificationManager.shared.scheduleWorkoutTargetReminder(
                weeklyTargetCount: settings.weeklyWorkoutTargetCount,
                weeklyTargetMinutes: settings.weeklyWorkoutTargetMinutes
            )
        }
        if settings.isWorkoutRestReminderEnabled {
            NotificationManager.shared.scheduleWorkoutRestReminder()
        }
    }

    private func importHealthWorkouts() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            var imported: [WorkoutLog] = []
            for offset in 0..<30 {
                if let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now) {
                    imported += try await HealthKitService.shared.workoutLogs(for: date)
                }
            }
            let existingIDs = Set(workouts.compactMap(\.externalIdentifier))
            var count = 0
            for workout in imported where workout.externalIdentifier.map({ !existingIDs.contains($0) }) ?? true {
                modelContext.insert(workout)
                count += 1
            }
            if count == 0 {
                bannerCenter.show(title: "没有新的训练", message: "Apple Health 最近 30 天没有可新增的训练记录。", tone: .warning)
            } else {
                HapticEngine.success()
                bannerCenter.show(title: "导入完成", message: "已从 Apple Health 导入 \(count) 条训练记录。", tone: .success)
            }
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "导入失败", message: error.localizedDescription, tone: .error)
        }
    }

    private var workoutCalendar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    calendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarMonth) ?? calendarMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(FamilyUI.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthTitle)
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    calendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(FamilyUI.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(monthDays, id: \.self) { day in
                    let dayWorkouts = workouts.filter { $0.startDate.isSameDay(as: day) }
                    let isCurrentMonth = Calendar.current.isDate(day, equalTo: calendarMonth, toGranularity: .month)
                    Circle()
                        .fill(calendarFill(for: dayWorkouts, isCurrentMonth: isCurrentMonth))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.caption2.weight(day.isToday ? .bold : .regular))
                                .foregroundStyle(calendarTextColor(for: dayWorkouts, isCurrentMonth: isCurrentMonth))
                        }
                        .overlay {
                            if day.isToday {
                                Circle().stroke(FamilyUI.accent, lineWidth: 1)
                            }
                        }
                }
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

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: calendarMonth)
    }

    private func calendarFill(for dayWorkouts: [WorkoutLog], isCurrentMonth: Bool) -> Color {
        guard isCurrentMonth else { return Color.clear }
        if dayWorkouts.contains(where: { !$0.isRestDay }) { return FamilyUI.success.opacity(0.22) }
        if dayWorkouts.contains(where: \.isRestDay) { return FamilyUI.accent.opacity(0.14) }
        return FamilyUI.panelBackground
    }

    private func calendarTextColor(for dayWorkouts: [WorkoutLog], isCurrentMonth: Bool) -> Color {
        guard isCurrentMonth else { return Color(.tertiaryLabel) }
        if !dayWorkouts.isEmpty { return .primary }
        return .secondary
    }
}

private struct WorkoutMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutLog

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: workout.workoutType.icon)
                .font(.body)
                .foregroundStyle(workout.isRestDay ? FamilyUI.accent : FamilyUI.success)
                .frame(width: 32, height: 32)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.isRestDay ? "休息日" : workout.workoutType.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private var rowSubtitle: String {
        if workout.isRestDay { return workout.note.isEmpty ? "恢复日" : workout.note }
        let calories = workout.caloriesBurned.map { " · \(Int($0)) kcal" } ?? ""
        return "\(workout.startDate.timeDisplay) · \(Int(workout.durationMinutes)) 分钟 · \(workout.intensity.displayName)强度\(calories)"
    }
}

private struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutLog
    let onEdit: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "WORKOUT DETAIL",
                    title: workout.isRestDay ? "休息日" : workout.workoutType.displayName,
                    detail: "\(workout.startDate.dayDisplay) \(workout.startDate.timeDisplay)"
                )

                SystemPanel {
                    HStack(spacing: 12) {
                        Image(systemName: workout.workoutType.icon)
                            .font(.title2)
                            .foregroundStyle(workout.isRestDay ? FamilyUI.accent : FamilyUI.success)
                            .frame(width: 44, height: 44)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))

                        VStack(alignment: .leading, spacing: 4) {
                            SystemStatusBadge(text: workout.isRestDay ? "REST DAY" : "TRAINING", tone: workout.isRestDay ? .accent : .success)
                            Text(workout.isRestDay ? "休息日" : workout.workoutType.displayName)
                                .font(.headline)
                            Text("\(workout.startDate.dayDisplay) \(workout.startDate.timeDisplay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !workout.isRestDay {
                    SystemPanel(title: "TRAINING DATA") {
                        DetailMetricRow(title: "时长", value: "\(Int(workout.durationMinutes)) 分钟")
                        SystemPanelDivider()
                        DetailMetricRow(title: "强度", value: workout.intensity.displayName)
                        SystemPanelDivider()
                        DetailMetricRow(title: "消耗", value: workout.caloriesBurned.map { "\(Int($0)) kcal" } ?? "未记录")
                        if let hr = workout.averageHeartRate {
                            SystemPanelDivider()
                            DetailMetricRow(title: "平均心率", value: "\(Int(hr)) bpm")
                        }
                        if let dist = workout.distanceMeters {
                            SystemPanelDivider()
                            DetailMetricRow(title: "距离", value: dist >= 1000
                                ? String(format: "%.2f km", dist / 1000)
                                : String(format: "%.0f m", dist))
                        }
                        SystemPanelDivider()
                        DetailMetricRow(title: "来源", value: workout.source.displayName)
                    }
                }

                if !workout.note.isEmpty {
                    SystemPanel(title: "NOTE") {
                        Text(workout.note)
                    }
                }

                SystemPanel {
                    actionRow("编辑训练", icon: "pencil") { onEdit() }
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除训练")
                            Spacer()
                        }
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
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
        .navigationTitle("训练详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("删除训练", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                modelContext.delete(workout)
                HapticEngine.warning()
                dismiss()
            }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
    }
}

private struct DetailMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

private struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var workout: WorkoutLog?

    @State private var workoutType: WorkoutType = .strength
    @State private var startDate = Date.now
    @State private var durationText = "30"
    @State private var caloriesText = ""
    @State private var intensity: WorkoutIntensity = .moderate
    @State private var isRestDay = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "WORKOUT",
                        title: workout == nil ? "CREATE WORKOUT" : "EDIT WORKOUT",
                        detail: "Log training, recovery day and workout nutrition context."
                    )

                    SystemPanel {
                        editorHeader("TYPE", value: isRestDay ? "REST DAY" : workoutType.displayName)
                        Toggle("标记为休息日", isOn: $isRestDay)
                            .font(.subheadline.weight(.semibold))
                        if !isRestDay {
                            Picker("训练类型", selection: $workoutType) {
                                ForEach(WorkoutType.allCases.filter { $0 != .rest }) { type in
                                    Label(type.displayName, systemImage: type.icon).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    SystemPanel {
                        editorHeader("TIME", value: startDate.dayDisplay)
                        DatePicker("开始时间", selection: $startDate)
                        if !isRestDay {
                            SystemPanelDivider()
                            metricField("时长", text: $durationText, unit: "min", keyboard: .numberPad)
                            SystemPanelDivider()
                            metricField("消耗热量", text: $caloriesText, unit: "kcal", keyboard: .decimalPad)
                        }
                    }

                    if !isRestDay {
                        SystemPanel {
                            editorHeader("INTENSITY", value: intensity.displayName)
                            Picker("强度", selection: $intensity) {
                                ForEach(WorkoutIntensity.allCases) { item in
                                    Text(item.displayName).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    SystemPanel {
                        editorHeader("NOTE", value: note.isEmpty ? "EMPTY" : "ATTACHED")
                        TextField(isRestDay ? "例如：主动恢复、睡眠不足" : "例如：腿部训练、跑后状态", text: $note, axis: .vertical)
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
            .navigationTitle(workout == nil ? "记录训练" : "编辑训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isRestDay && (Double(durationText) ?? 0) <= 0)
                }
            }
            .onAppear(perform: loadWorkout)
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

    private func metricField(_ label: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField(unit, text: text)
                .keyboardType(keyboard)
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
                .frame(width: 44, alignment: .leading)
        }
    }

    private func loadWorkout() {
        guard let workout else { return }
        workoutType = workout.workoutType
        startDate = workout.startDate
        durationText = workout.durationMinutes.formatted(.number.precision(.fractionLength(0...0)))
        caloriesText = workout.caloriesBurned?.formatted(.number.precision(.fractionLength(0...0))) ?? ""
        intensity = workout.intensity
        isRestDay = workout.isRestDay
        note = workout.note
    }

    private func save() {
        let target = workout ?? WorkoutLog()
        target.isRestDay = isRestDay
        target.workoutType = isRestDay ? .rest : workoutType
        target.startDate = startDate
        target.durationMinutes = isRestDay ? 0 : (Double(durationText) ?? 30)
        target.caloriesBurned = isRestDay ? nil : Double(caloriesText)
        target.intensity = intensity
        target.source = .manual
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.updatedAt = .now

        if workout == nil {
            modelContext.insert(target)
        }
        HapticEngine.success()
        dismiss()
    }
}
