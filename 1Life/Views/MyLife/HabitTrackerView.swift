import SwiftUI
import SwiftData

struct HabitTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { !$0.isArchived },
           sort: [SortDescriptor(\Habit.createdAt)])
    private var activeHabits: [Habit]

    @State private var isShowingAddHabit = false
    let date: Date

    var body: some View {
        SystemPanel {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let completed = activeHabits.filter { isCompleted($0) }.count
                    SystemStatusBadge(text: "HABITS \(completed)/\(activeHabits.count)", tone: activeHabits.isEmpty ? .warning : .accent)
                    if activeHabits.isEmpty {
                        Text("追踪影响健康的小行为")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    HapticEngine.tap()
                    isShowingAddHabit = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }

            if activeHabits.isEmpty {
                Button {
                    isShowingAddHabit = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                        Text("追踪早睡、补剂、拉伸等每日行为")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
                VStack(spacing: 8) {
                    ForEach(activeHabits) { habit in
                        HabitRow(habit: habit, date: date, modelContext: modelContext)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddHabit) {
            AddHabitSheet()
        }
    }

    private func isCompleted(_ habit: Habit) -> Bool {
        let dayLogs = (habit.logs ?? []).filter { $0.date.isSameDay(as: date) }
        return dayLogs.reduce(0) { $0 + $1.value } >= (habit.targetCount ?? 1)
    }
}

private enum HabitState {
    case none, half, done
}

private struct HabitRow: View {
    let habit: Habit
    let date: Date
    let modelContext: ModelContext

    private var dayLogs: [HabitLog] {
        (habit.logs ?? []).filter { $0.date.isSameDay(as: date) }
    }

    private var currentValue: Double { dayLogs.reduce(0) { $0 + $1.value } }

    private var state: HabitState {
        if currentValue >= 1 { return .done }
        if currentValue > 0 { return .half }
        return .none
    }

    var body: some View {
        let rowState = state

        NavigationLink {
            HabitDetailView(habit: habit)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: habit.iconSymbol)
                    .font(.body)
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 28, height: 28)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline)
                        .strikethrough(rowState == .done)
                        .foregroundStyle(rowState == .done ? .secondary : .primary)
                    Text("连续 \(HabitService.currentStreak(habit: habit))\(habit.frequencyType == .daily ? "天" : "周")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button { cycleState() } label: {
                    Image(systemName: stateIcon(for: rowState))
                        .font(.title3)
                        .foregroundStyle(stateColor(for: rowState))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private func stateIcon(for state: HabitState) -> String {
        switch state {
        case .none: return "circle"
        case .half: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }

    private func stateColor(for state: HabitState) -> Color {
        switch state {
        case .none: return .secondary
        case .half: return FamilyUI.accent
        case .done: return FamilyUI.success
        }
    }

    private func cycleState() {
        switch state {
        case .none:
            let log = HabitLog(date: date, value: 0.5)
            habit.logs?.append(log)
            modelContext.insert(log)
            HapticEngine.tap()
        case .half:
            dayLogs.forEach { modelContext.delete($0) }
            let log = HabitLog(date: date, value: 1)
            habit.logs?.append(log)
            modelContext.insert(log)
            HapticEngine.success()
        case .done:
            dayLogs.forEach { modelContext.delete($0) }
            HapticEngine.tap()
        }
    }
}

struct AddHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var iconSymbol = "checkmark.circle.fill"
    @State private var colorHex = "3B82F6"
    @State private var frequencyType: HabitFrequencyType = .daily
    @State private var frequencyCount = 1
    @State private var hasReminder = false
    @State private var reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now

    private let icons = ["checkmark.circle.fill", "drop.fill", "figure.run", "book.fill",
                         "moon.fill", "heart.fill", "brain.head.profile", "leaf.fill",
                         "dumbbell.fill", "cup.and.saucer.fill"]
    private let colors = ["3B82F6", "EF4444", "22C55E", "F59E0B", "8B5CF6",
                          "06B6D4", "EC4899", "F97316"]
    private let presets: [HabitPreset] = [
        HabitPreset(name: "早睡", iconSymbol: "moon.fill", colorHex: "8B5CF6"),
        HabitPreset(name: "运动", iconSymbol: "figure.run", colorHex: "22C55E", frequencyType: .weekly, frequencyCount: 3),
        HabitPreset(name: "拉伸", iconSymbol: "figure.flexibility", colorHex: "06B6D4"),
        HabitPreset(name: "补剂", iconSymbol: "pills.fill", colorHex: "F59E0B"),
        HabitPreset(name: "控糖", iconSymbol: "heart.fill", colorHex: "EF4444"),
        HabitPreset(name: "称重", iconSymbol: "scalemass.fill", colorHex: "3B82F6"),
        HabitPreset(name: "晒太阳", iconSymbol: "sun.max.fill", colorHex: "F97316"),
        HabitPreset(name: "冥想", iconSymbol: "brain.head.profile", colorHex: "8B5CF6")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "HABIT",
                        title: "CREATE HABIT",
                        detail: "Track repeatable behaviors that affect health and nutrition."
                    )

                    SystemPanel {
                        editorHeader("PRESETS", value: "\(presets.count) OPTIONS")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(presets) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: preset.iconSymbol)
                                            .font(.headline)
                                            .frame(width: 34, height: 34)
                                            .background(Color(hex: preset.colorHex).opacity(0.14))
                                            .foregroundStyle(Color(hex: preset.colorHex))
                                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                                        Text(preset.name)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 64)
                                    .padding(.vertical, 6)
                                    .background(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    }

                    SystemPanel {
                        editorHeader("HABIT INFO", value: name.isEmpty ? "REQUIRED" : "READY")
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
                        ForEach(HabitFrequencyType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                        .pickerStyle(.segmented)

                    if frequencyType == .weekly {
                        Stepper("每周 \(frequencyCount) 次", value: $frequencyCount, in: 1...7)
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
            .navigationTitle("新建习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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

    private func save() {
        let habit = Habit(
            name: name.trimmingCharacters(in: .whitespaces),
            iconSymbol: iconSymbol,
            colorHex: colorHex,
            frequencyType: frequencyType,
            frequencyCount: frequencyType == .weekly ? frequencyCount : 1,
            reminderHour: hasReminder ? Calendar.current.component(.hour, from: reminderDate) : nil,
            reminderMinute: hasReminder ? Calendar.current.component(.minute, from: reminderDate) : nil
        )
        modelContext.insert(habit)
        if hasReminder, let hour = habit.reminderHour, let minute = habit.reminderMinute {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleHabitReminder(habitID: habit.id, name: habit.name, hour: hour, minute: minute)
        }
        HapticEngine.success()
        dismiss()
    }

    private func applyPreset(_ preset: HabitPreset) {
        name = preset.name
        iconSymbol = preset.iconSymbol
        colorHex = preset.colorHex
        frequencyType = preset.frequencyType
        frequencyCount = preset.frequencyCount
        hasReminder = false
        HapticEngine.tap()
    }
}

private struct HabitPreset: Identifiable {
    let id = UUID()
    let name: String
    let iconSymbol: String
    let colorHex: String
    var frequencyType: HabitFrequencyType = .daily
    var frequencyCount: Int = 1
}
