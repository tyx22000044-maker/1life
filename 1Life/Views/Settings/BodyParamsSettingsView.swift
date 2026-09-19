import SwiftUI
import SwiftData

struct BodyParamsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: UserSettings
    @Query(sort: [SortDescriptor(\NutritionGoal.effectiveDate, order: .reverse)])
    private var goals: [NutritionGoal]
    @Query(sort: [SortDescriptor(\BodyMeasurement.date, order: .reverse)])
    private var bodyMeasurements: [BodyMeasurement]

    @State private var ageText = ""
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var invalidValueNotice: String?
    @State private var healthSyncMessage: String?
    @State private var isSyncingHealth = false
    @State private var showRecalculateAlert = false
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable { case age, height, weight }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "身体参数",
                    title: "健康档案",
                    detail: "维护身高、体重和活动水平，用于估算 TDEE 与营养目标。"
                )

                basicInfoPanel
                appleHealthPanel
                activityPanel

                if settings.hasBodyParameters, let tdee = settings.estimatedTDEE {
                    estimatePanel(tdee: tdee)
                } else {
                    missingDataPanel
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FamilyUI.pageBackground)
        .navigationTitle("身体参数")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                KeyboardDoneButton {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            if settings.gender == nil {
                settings.gender = .male
            }
            if settings.activityLevel == nil {
                settings.activityLevel = .sedentary
            }
            ageText = settings.age.map { "\($0)" } ?? ""
            heightText = settings.heightCm.map { "\(Int($0))" } ?? ""
            weightText = settings.weightKg.map { String(format: "%.1f", $0) } ?? ""
            syncTextFieldsToSettings()
            Task { await syncLatestWeightFromHealth(silent: true) }
        }
        .onChange(of: ageText) { _, _ in syncTextFieldsToSettings() }
        .onChange(of: heightText) { _, _ in syncTextFieldsToSettings() }
        .onChange(of: weightText) { _, _ in syncTextFieldsToSettings() }
        .onDisappear {
            syncTextFieldsToSettings()
        }
        .alert("重新推荐营养目标", isPresented: $showRecalculateAlert) {
            Button("取消", role: .cancel) {}
            Button("确认") { recalculateGoal() }
        } message: {
            Text("将根据你的身体参数和饮食目标重新计算营养目标。")
        }
    }

    private var basicInfoPanel: some View {
        SystemPanel(title: "基础数据", detail: "性别、年龄、身高和体重") {
            sectionHeader("基础数据", value: settings.hasBodyParameters ? "已完成" : "待补全")

            Picker("性别", selection: Binding(
                get: { settings.gender ?? .male },
                set: { settings.gender = $0; settings.updatedAt = .now }
            )) {
                ForEach(Gender.allCases) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .pickerStyle(.segmented)

            SystemPanelDivider()
            metricField(label: "年龄", text: $ageText, unit: "岁", keyboard: .numberPad, field: .age)
            SystemPanelDivider()
            metricField(label: "身高", text: $heightText, unit: "cm", keyboard: .decimalPad, field: .height)
            SystemPanelDivider()
            metricField(label: "体重", text: $weightText, unit: "kg", keyboard: .decimalPad, field: .weight)
            if let invalidValueNotice {
                Text(invalidValueNotice)
                    .font(FamilyTypography.text(size: 12))
                    .foregroundStyle(FamilyUI.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var activityPanel: some View {
        SystemPanel(title: "活动水平", detail: "选择日常活动水平") {
            sectionHeader("活动水平", value: (settings.activityLevel ?? .sedentary).displayName)

            VStack(spacing: 8) {
                ForEach(ActivityLevel.allCases) { level in
                    Button {
                        settings.activityLevel = level
                        settings.updatedAt = .now
                        HapticEngine.tap()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: (settings.activityLevel ?? .sedentary) == level ? "checkmark.square.fill" : "square")
                                .foregroundStyle((settings.activityLevel ?? .sedentary) == level ? FamilyUI.accent : .secondary)
                            Text(level.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background((settings.activityLevel ?? .sedentary) == level ? FamilyUI.panelMutedBackground : FamilyUI.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var appleHealthPanel: some View {
        SystemPanel(title: "Apple Health", detail: "同步最新身高、体重，并更新身体参数") {
            sectionHeader("健康同步", value: healthSyncMessage == nil ? "可同步" : "已更新")

            HStack(spacing: 10) {
                Button {
                    Task { await syncLatestWeightFromHealth(silent: false) }
                } label: {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                        Text(isSyncingHealth ? "同步中" : "同步身高体重")
                        Spacer()
                        Image(systemName: "arrow.down")
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
                .buttonStyle(.plain)
                .disabled(isSyncingHealth)
            }

            if let healthSyncMessage {
                Text(healthSyncMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func estimatePanel(tdee: Double) -> some View {
        SystemPanel(title: "估算结果", detail: "根据当前参数估算能量消耗") {
            sectionHeader("估算结果", value: "已启用")
            metricReadout(label: "基础代谢 (BMR)", value: "\(Int(settings.estimatedBMR ?? 0)) kcal")
            SystemPanelDivider()
            metricReadout(label: "每日总消耗 (TDEE)", value: "\(Int(tdee)) kcal")
            SystemPanelDivider()
            metricReadout(label: "推荐热量 (\(settings.dietGoalMode.displayName))", value: "\(Int(settings.recommendedCalories)) kcal", emphasized: true)

            Button {
                showRecalculateAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityLabel("从 Apple Health 重新读取")
                    Text("根据新参数重新推荐营养目标")
                    Spacer()
                    Image(systemName: "arrow.right")
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
            .padding(.top, 4)
        }
    }

    private var missingDataPanel: some View {
        SystemPanel(title: "缺少数据", detail: "补全身体参数后生成推荐目标") {
            VStack(alignment: .leading, spacing: 8) {
                SystemStatusBadge(text: "待补全", tone: .warning)
                Text("补全年龄、身高、体重后，1Life 会生成 BMR、TDEE 和推荐热量。")
                    .font(.subheadline.weight(.semibold))
                Text("这些参数会影响每日营养目标和首页健康指标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sectionHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value.uppercased(), tone: .neutral)
        }
        .padding(.bottom, 2)
    }

    private func metricField(label: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType, field: FocusedField) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField("", text: text)
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
                .focused($focusedField, equals: field)
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func metricReadout(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(emphasized ? .headline.weight(.black) : .subheadline.weight(.bold))
                .foregroundStyle(emphasized ? FamilyUI.accent : .secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    private func recalculateGoal() {
        let calories = settings.recommendedCalories
        let macros = settings.recommendedMacroTargets(calories: calories)

        if let existing = goals.first, existing.effectiveDate.isSameDay(as: .now) {
            existing.dailyCalories = calories
            existing.dailyProtein = macros.protein
            existing.dailyCarbs = macros.carbs
            existing.dailyFat = macros.fat
            existing.updatedAt = .now
        } else {
            let newGoal = NutritionGoal.fromRecommendedTargets(calories: calories, macros: macros)
            modelContext.insert(newGoal)
        }
        HapticEngine.success()
    }

    private func syncTextFieldsToSettings() {
        let parsedAge = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines))
        let parsedHeight = Double(heightText.replacingOccurrences(of: ",", with: "."))
        let parsedWeight = Double(weightText.replacingOccurrences(of: ",", with: "."))

        settings.age = BodyMeasurementLimits.validatedAge(parsedAge)
        settings.heightCm = BodyMeasurementLimits.validatedHeight(parsedHeight)
        settings.weightKg = BodyMeasurementLimits.validatedWeight(parsedWeight)
        invalidValueNotice = BodyMeasurementLimits.outOfRangeNotice(weight: parsedWeight, height: parsedHeight, age: parsedAge, bodyFat: nil)
        settings.updatedAt = .now
    }

    private func syncLatestWeightFromHealth(silent: Bool) async {
        guard !isSyncingHealth else { return }
        isSyncingHealth = true
        defer { isSyncingHealth = false }

        do {
            try await HealthKitService.shared.requestAuthorization()
            guard let snapshot = try await HealthKitService.shared.latestBodyMeasurement(),
                  snapshot.weightKg != nil || snapshot.heightCm != nil else {
                if !silent { healthSyncMessage = "Apple Health 中暂无身高或体重记录" }
                return
            }

            if let weight = snapshot.weightKg {
                settings.weightKg = weight
                weightText = String(format: "%.1f", weight)
            }
            if let height = snapshot.heightCm {
                settings.heightCm = height
                heightText = String(format: "%.0f", height)
            }
            settings.updatedAt = .now

            if snapshot.weightKg != nil || snapshot.bodyFatPercentage != nil {
                if let existing = bodyMeasurements.first(where: { $0.source == .appleHealth && $0.date.isSameDay(as: snapshot.date) }) {
                    existing.weightKg = snapshot.weightKg
                    existing.bodyFatPercentage = snapshot.bodyFatPercentage
                    existing.updatedAt = .now
                } else {
                    modelContext.insert(BodyMeasurement(
                        date: snapshot.date,
                        weightKg: snapshot.weightKg,
                        bodyFatPercentage: snapshot.bodyFatPercentage,
                        source: .appleHealth,
                        syncedToAppleHealth: true,
                        note: "由 Apple Health 导入"
                    ))
                }
            }
            try modelContext.save()
            let weightPart = snapshot.weightKg.map { String(format: "体重 %.1f kg", $0) }
            let heightPart = snapshot.heightCm.map { String(format: "身高 %.0f cm", $0) }
            healthSyncMessage = "已同步 \(snapshot.date.dayDisplay) 的 \([heightPart, weightPart].compactMap { $0 }.joined(separator: "、"))"
            if !silent { HapticEngine.success() }
        } catch {
            if !silent {
                healthSyncMessage = error.localizedDescription
                HapticEngine.warning()
            }
        }
    }
}
