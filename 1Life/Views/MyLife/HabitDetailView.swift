import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit

    @State private var showArchiveAlert = false
    @State private var showDeleteAlert = false
    @State private var isEditing = false

    private var streak: Int { HabitService.currentStreak(habit: habit) }
    private var completionRate: Double { HabitService.completionRate(habit: habit) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "HABIT DETAIL",
                    title: habit.name,
                    detail: frequencyDescription
                )

                SystemPanel {
                HStack(spacing: 14) {
                    Image(systemName: habit.iconSymbol)
                        .font(.title2)
                        .foregroundStyle(Color(hex: habit.colorHex))
                        .frame(width: 44, height: 44)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                    VStack(alignment: .leading, spacing: 4) {
                        SystemStatusBadge(text: "ACTIVE HABIT", tone: .accent)
                        Text(habit.name).font(.headline)
                        Text(frequencyDescription).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

                SystemPanel(title: "STATS") {
                HStack {
                    StatCard(title: "当前连续", value: "\(streak)", unit: streakUnit)
                    StatCard(title: "完成率", value: "\(Int(completionRate * 100))", unit: "%")
                    StatCard(title: "总记录", value: "\(habit.logs?.count ?? 0)", unit: "次")
                }
            }

                SystemPanel(title: "LAST 30 DAYS") {
                HeatmapView(habit: habit)
            }

                SystemPanel(title: "TREND") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("\(completedDays30) / 30 天", systemImage: "calendar")
                        Spacer()
                        Text(trendText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(trendColor)
                    }
                    .font(.subheadline)

                    Text(trendInsight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

                SystemPanel {
                    actionRow("编辑习惯", icon: "pencil") { isEditing = true }

                    Button {
                        showArchiveAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                                .accessibilityLabel("归档这个习惯")
                            Text("归档习惯")
                            Spacer()
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )

                    Button("删除习惯", role: .destructive) {
                        showDeleteAlert = true
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
        .navigationTitle("习惯详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("归档习惯", isPresented: $showArchiveAlert) {
            Button("取消", role: .cancel) {}
            Button("归档") {
                habit.isArchived = true
                habit.updatedAt = .now
                NotificationManager.shared.removeHabitReminder(habitID: habit.id)
                HapticEngine.tap()
                dismiss()
            }
        } message: {
            Text("归档后不再出现在日常列表中，但历史数据保留。")
        }
        .alert("删除习惯", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                NotificationManager.shared.removeHabitReminder(habitID: habit.id)
                modelContext.delete(habit)
                HapticEngine.warning()
                dismiss()
            }
        } message: {
            Text("将同时删除所有完成记录，此操作不可恢复。")
        }
        .sheet(isPresented: $isEditing) {
            EditHabitSheet(habit: habit)
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

    private var frequencyDescription: String {
        switch habit.frequencyType {
        case .daily: return "每天"
        case .weekly: return "每周 \(habit.frequencyCount) 次"
        }
    }

    private var streakUnit: String {
        habit.frequencyType == .daily ? "天" : "周"
    }

    private var completedDays30: Int {
        HabitService.completedDays(habit: habit, days: 30)
    }

    private var previousCompletedDays30: Int {
        let previousEnd = Calendar.current.date(byAdding: .day, value: -30, to: Date.now) ?? Date.now
        return HabitService.completedDays(habit: habit, days: 30, asOf: previousEnd)
    }

    private var trendDelta: Int {
        completedDays30 - previousCompletedDays30
    }

    private var trendText: String {
        if trendDelta > 0 { return "+\(trendDelta) 天" }
        if trendDelta < 0 { return "\(trendDelta) 天" }
        return "持平"
    }

    private var trendColor: Color {
        if trendDelta > 0 { return FamilyUI.success }
        if trendDelta < 0 { return FamilyUI.accent }
        return .secondary
    }

    private var trendInsight: String {
        if completedDays30 == 0 {
            return "最近还没有完成记录，可以先降低目标，让这个习惯更容易开始。"
        }
        if completionRate >= 0.8 {
            return "最近 30 天稳定性很好，适合保持当前节奏，不必急着加量。"
        }
        if trendDelta > 0 {
            return "最近 30 天比上一阶段更稳定，继续观察它和饮食、状态的关系。"
        }
        if trendDelta < 0 {
            return "最近完成频率下降，可以检查是否和压力、睡眠或外食有关。"
        }
        return "最近节奏基本稳定，可以继续积累数据后再看趋势。"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.weight(.bold).monospacedDigit())
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeatmapView: View {
    let habit: Habit

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    private var days: [(date: Date, completed: Bool)] {
        let cal = Calendar.current
        let today = Date.now
        return (0..<30).reversed().compactMap { offset -> (Date, Bool)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let logs = (habit.logs ?? []).filter { $0.date.isSameDay(as: day) }
            let total = logs.reduce(0.0) { $0 + $1.value }
            return (day, total >= (habit.targetCount ?? 1))
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(days, id: \.date) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(day.completed ? Color(hex: habit.colorHex) : FamilyUI.panelMutedBackground)
                    .frame(height: 24)
                    .overlay {
                        if day.date.isToday {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        }
                    }
            }
        }
    }
}

struct EditHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit

    @State private var name = ""
    @State private var iconSymbol = ""
    @State private var colorHex = ""
    @State private var frequencyType: HabitFrequencyType = .daily
    @State private var frequencyCount = 1
    @State private var hasTarget = false
    @State private var targetText = ""
    @State private var unitName = ""
    @State private var hasReminder = false
    @State private var reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now

    private let icons = ["checkmark.circle.fill", "drop.fill", "figure.run", "book.fill",
                         "moon.fill", "heart.fill", "brain.head.profile", "leaf.fill",
                         "dumbbell.fill", "cup.and.saucer.fill"]
    private let colors = ["3B82F6", "EF4444", "22C55E", "F59E0B", "8B5CF6",
                          "06B6D4", "EC4899", "F97316"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "HABIT",
                        title: "EDIT HABIT",
                        detail: "Update behavior identity, rhythm, targets and reminders."
                    )

                    SystemPanel {
                        editorHeader("BASIC INFO", value: name.isEmpty ? "REQUIRED" : "READY")
                        TextField("习惯名称", text: $name)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        iconSymbol = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .accessibilityLabel("选择习惯图标")
                                            .font(.title3)
                                            .frame(width: 40, height: 40)
                                            .background(iconSymbol == icon ? Color(hex: colorHex) : FamilyUI.panelMutedBackground)
                                            .foregroundStyle(iconSymbol == icon ? .white : .primary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                                    }
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(colors, id: \.self) { hex in
                                    Button {
                                        colorHex = hex
                                    } label: {
                                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                            .fill(Color(hex: hex))
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                                    .stroke(colorHex == hex ? Color.primary : FamilyUI.panelBorder, lineWidth: colorHex == hex ? 2 : 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    SystemPanel {
                        editorHeader("FREQUENCY", value: frequencyType.displayName)
                        Picker("频率", selection: $frequencyType) {
                            ForEach(HabitFrequencyType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        if frequencyType == .weekly {
                            Stepper("每周 \(frequencyCount) 次", value: $frequencyCount, in: 1...7)
                        }
                    }

                    SystemPanel {
                        editorHeader("TARGET", value: hasTarget ? "CUSTOM" : "NONE")
                        Toggle("设定数量目标", isOn: $hasTarget)
                            .font(.subheadline.weight(.semibold))
                        if hasTarget {
                            HStack {
                                TextField("目标数量", text: $targetText)
                                    .keyboardType(.decimalPad)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                TextField("单位", text: $unitName)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }

                    SystemPanel {
                        editorHeader("REMINDER", value: hasReminder ? "ON" : "OFF")
                        Toggle("开启提醒", isOn: $hasReminder)
                            .font(.subheadline.weight(.semibold))
                        if hasReminder {
                            DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("编辑习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        habit.name = name.trimmingCharacters(in: .whitespaces)
                        habit.iconSymbol = iconSymbol
                        habit.colorHex = colorHex
                        habit.frequencyType = frequencyType
                        habit.frequencyCount = frequencyType == .weekly ? frequencyCount : 1
                        habit.targetCount = hasTarget ? Double(targetText) : nil
                        habit.unitName = hasTarget ? unitName.trimmingCharacters(in: .whitespaces) : nil
                        habit.reminderHour = hasReminder ? Calendar.current.component(.hour, from: reminderDate) : nil
                        habit.reminderMinute = hasReminder ? Calendar.current.component(.minute, from: reminderDate) : nil
                        habit.updatedAt = .now
                        NotificationManager.shared.removeHabitReminder(habitID: habit.id)
                        if hasReminder, let hour = habit.reminderHour, let minute = habit.reminderMinute {
                            NotificationManager.shared.requestPermission()
                            NotificationManager.shared.scheduleHabitReminder(habitID: habit.id, name: habit.name, hour: hour, minute: minute)
                        }
                        HapticEngine.success()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = habit.name
                iconSymbol = habit.iconSymbol
                colorHex = habit.colorHex
                frequencyType = habit.frequencyType
                frequencyCount = habit.frequencyCount
                hasTarget = habit.targetCount != nil
                targetText = habit.targetCount?.formatted(.number.precision(.fractionLength(0...1))) ?? ""
                unitName = habit.unitName ?? ""
                hasReminder = habit.reminderHour != nil && habit.reminderMinute != nil
                if let hour = habit.reminderHour, let minute = habit.reminderMinute {
                    reminderDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? reminderDate
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
}
