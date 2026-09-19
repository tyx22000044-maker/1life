import SwiftUI
import SwiftData

struct NutritionGoalSettingsView: View {
    @Bindable var settings: UserSettings
    @Bindable var goal: NutritionGoal

    @State private var healthTDEE: Double?
    @State private var calorieMultiplierText = ""
    @State private var proteinMultiplierText = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var fiberText = ""
    @State private var sodiumText = ""
    @State private var sugarText = ""
    @State private var cholesterolText = ""
    @State private var caffeineText = ""
    @State private var teaPolyphenolsText = ""
    @State private var calciumText = ""
    @State private var magnesiumText = ""
    @State private var potassiumText = ""
    @State private var ironText = ""
    @State private var zincText = ""
    @State private var vitaminAText = ""
    @State private var vitaminCText = ""
    @State private var vitaminDText = ""
    @State private var vitaminEText = ""
    @State private var vitaminB1Text = ""
    @State private var vitaminB2Text = ""
    @State private var niacinText = ""
    @State private var vitaminB6Text = ""
    @State private var folateText = ""
    @State private var vitaminB12Text = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "NUTRITION TARGET",
                    title: "DAILY GOAL MATRIX",
                    detail: "Configure diet mode, macro targets and micronutrient limits used across dashboard and AI analysis."
                )

                strategyPanel
                dailyTargetPanel
                micronutrientPanel
                spotlightPanel
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle("营养目标")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadValues() }
        .onDisappear { saveValues() }
        .task { await loadHealthTDEE() }
    }

    private var strategyPanel: some View {
        SystemPanel(title: "DIET STRATEGY", detail: "选择饮食目标与推荐值算法") {
            sectionHeader("DIET STRATEGY", value: settings.dietGoalMode.displayName)

            Picker("饮食目标", selection: Binding(
                get: { settings.dietGoalMode },
                set: {
                    settings.dietGoalMode = $0
                    settings.updatedAt = .now
                    restoreRecommended()
                }
            )) {
                ForEach(DietGoalMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)

            SystemPanelDivider()
            Toggle("自定义热量系数", isOn: Binding(
                get: { settings.useCustomCalorieMultiplier },
                set: {
                    settings.useCustomCalorieMultiplier = $0
                    settings.updatedAt = .now
                    restoreRecommended()
                }
            ))
            .font(.subheadline.weight(.semibold))

            if settings.useCustomCalorieMultiplier {
                GoalField(label: "热量系数", text: $calorieMultiplierText, unit: "x")
                helperText("当前模式默认 \(settings.dietGoalMode.displayName) 为 \(settings.dietGoalMode.calorieMultiplier.nutritionDecimal)x，比如减脂默认是 0.8x。")
            }

            SystemPanelDivider()
            Picker("蛋白目标方式", selection: Binding(
                get: { settings.proteinTargetStrategy },
                set: {
                    settings.proteinTargetStrategy = $0
                    settings.updatedAt = .now
                    restoreRecommended()
                }
            )) {
                ForEach(ProteinTargetStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            .pickerStyle(.menu)

            if settings.proteinTargetStrategy == .bodyWeight {
                GoalField(label: "蛋白系数", text: $proteinMultiplierText, unit: "g/kg")
                helperText("常见参考：普通人 1.0-1.2，规律训练 1.4-1.6，增肌或减脂保肌 1.6-2.0。没有体重数据时会回退到宏量比例。")
            }

            if settings.useHealthKitForDynamicTDEE {
                SystemPanelDivider()
                readoutRow(label: "动态 TDEE", value: healthTDEE.map { "\(Int($0)) kcal" } ?? "读取中...")
            }

            SystemPanelDivider()
            readoutRow(label: "目标来源", value: settings.effectiveTarget(healthTDEE: healthTDEE, goal: goal).caloriesProvenance.displayName)

            Button {
                restoreRecommended()
                HapticEngine.tap()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("根据 TDEE 恢复推荐值")
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

    private var dailyTargetPanel: some View {
        SystemPanel(title: "DAILY TARGETS", detail: "设置每日热量和三大营养素目标") {
            sectionHeader("DAILY TARGETS", value: "\(caloriesText) KCAL")
            GoalField(label: "热量", text: $caloriesText, unit: "kcal")
            dividerGoalField(label: "蛋白质", text: $proteinText, unit: "g")
            dividerGoalField(label: "碳水化合物", text: $carbsText, unit: "g")
            dividerGoalField(label: "脂肪", text: $fatText, unit: "g")
        }
    }

    private static let spotlightCandidates: [NutrientKey] = [
        .protein, .carbs, .fat, .fiber, .sodium,
        .sugar, .cholesterol, .caffeine, .teaPolyphenols, .calcium, .potassium, .iron, .zinc
    ]

    private var spotlightPanel: some View {
        let current = settings.spotlightNutrientKeys
        return SystemPanel(title: "DASHBOARD SPOTLIGHT", detail: "选择主页展示的营养素（最多 5 个）") {
            sectionHeader("SPOTLIGHT", value: "\(current.count)/5")

            Text("在主页营养素卡片中最多展示 5 个营养素指标，勾选你最关心的。")
                .font(.caption)
                .foregroundStyle(.secondary)

            SystemPanelDivider()

            VStack(spacing: 0) {
                ForEach(Array(Self.spotlightCandidates.enumerated()), id: \.element.id) { index, key in
                    let isOn = current.contains(key)
                    let atLimit = current.count >= 5

                    if index > 0 { SystemPanelDivider() }

                    Button {
                        var keys = current
                        if isOn {
                            keys.removeAll { $0 == key }
                        } else if !atLimit {
                            keys.append(key)
                        } else {
                            HapticEngine.warning()
                            return
                        }
                        settings.spotlightNutrientKeys = keys
                        settings.updatedAt = .now
                        HapticEngine.tap()
                    } label: {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(key.spotlightColor)
                                .frame(width: 6, height: 22)
                            Text(key.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if isOn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(key.spotlightColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(atLimit ? FamilyUI.inkFaint : FamilyUI.inkSoft)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isOn && atLimit)
                }
            }
        }
    }

    private var micronutrientPanel: some View {
        SystemPanel(title: "MICRO TARGETS", detail: "设置可选的微量营养素上限或目标") {
            sectionHeader("MICRO TARGETS", value: "OPTIONAL")
            GoalField(label: "膳食纤维", text: $fiberText, unit: "g")
            dividerGoalField(label: "钠", text: $sodiumText, unit: "mg")
            dividerGoalField(label: "糖", text: $sugarText, unit: "g")
            dividerGoalField(label: "胆固醇", text: $cholesterolText, unit: "mg")
            dividerGoalField(label: "咖啡因", text: $caffeineText, unit: "mg")
            dividerGoalField(label: "茶多酚", text: $teaPolyphenolsText, unit: "mg")
            dividerGoalField(label: "钙", text: $calciumText, unit: "mg")
            dividerGoalField(label: "镁", text: $magnesiumText, unit: "mg")
            dividerGoalField(label: "钾", text: $potassiumText, unit: "mg")
            dividerGoalField(label: "铁", text: $ironText, unit: "mg")
            dividerGoalField(label: "锌", text: $zincText, unit: "mg")
            dividerGoalField(label: "维生素 A", text: $vitaminAText, unit: "ug")
            dividerGoalField(label: "维生素 C", text: $vitaminCText, unit: "mg")
            dividerGoalField(label: "维生素 D", text: $vitaminDText, unit: "ug")
            dividerGoalField(label: "维生素 E", text: $vitaminEText, unit: "mg")
            dividerGoalField(label: "维生素 B1", text: $vitaminB1Text, unit: "mg")
            dividerGoalField(label: "维生素 B2", text: $vitaminB2Text, unit: "mg")
            dividerGoalField(label: "烟酸", text: $niacinText, unit: "mg")
            dividerGoalField(label: "维生素 B6", text: $vitaminB6Text, unit: "mg")
            dividerGoalField(label: "叶酸", text: $folateText, unit: "ug")
            dividerGoalField(label: "维生素 B12", text: $vitaminB12Text, unit: "ug")
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

    private func dividerGoalField(label: String, text: Binding<String>, unit: String) -> some View {
        VStack(spacing: 0) {
            SystemPanelDivider()
            GoalField(label: label, text: text, unit: unit)
        }
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func readoutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func loadValues() {
        calorieMultiplierText = settings.useCustomCalorieMultiplier
            ? settings.customCalorieMultiplier.nutritionDecimal
            : settings.dietGoalMode.calorieMultiplier.nutritionDecimal
        proteinMultiplierText = settings.proteinTargetMultiplier.nutritionDecimal
        caloriesText = "\(Int(goal.dailyCalories))"
        proteinText = "\(Int(goal.dailyProtein))"
        carbsText = "\(Int(goal.dailyCarbs))"
        fatText = "\(Int(goal.dailyFat))"
        fiberText = "\(Int(goal.dailyFiber))"
        sodiumText = "\(Int(goal.dailySodium))"
        sugarText = "\(Int(goal.dailySugar))"
        cholesterolText = "\(Int(goal.dailyCholesterol))"
        caffeineText = "\(Int(goal.dailyCaffeine))"
        teaPolyphenolsText = "\(Int(goal.dailyTeaPolyphenols))"
        calciumText = "\(Int(goal.dailyCalcium))"
        magnesiumText = "\(Int(goal.dailyMagnesium))"
        potassiumText = "\(Int(goal.dailyPotassium))"
        ironText = goal.dailyIron.nutritionDecimal
        zincText = goal.dailyZinc.nutritionDecimal
        vitaminAText = "\(Int(goal.dailyVitaminA))"
        vitaminCText = "\(Int(goal.dailyVitaminC))"
        vitaminDText = goal.dailyVitaminD.nutritionDecimal
        vitaminEText = goal.dailyVitaminE.nutritionDecimal
        vitaminB1Text = goal.dailyVitaminB1.nutritionDecimal
        vitaminB2Text = goal.dailyVitaminB2.nutritionDecimal
        niacinText = goal.dailyNiacin.nutritionDecimal
        vitaminB6Text = goal.dailyVitaminB6.nutritionDecimal
        folateText = "\(Int(goal.dailyFolate))"
        vitaminB12Text = goal.dailyVitaminB12.nutritionDecimal
    }

    private func saveValues() {
        if let calorieMultiplier = Double(calorieMultiplierText), calorieMultiplier > 0 {
            settings.customCalorieMultiplier = calorieMultiplier
        }
        if let proteinMultiplier = Double(proteinMultiplierText), proteinMultiplier >= 0 {
            settings.proteinTargetMultiplier = proteinMultiplier
        }
        settings.updatedAt = .now
        goal.dailyCalories = Double(caloriesText) ?? goal.dailyCalories
        goal.dailyProtein = Double(proteinText) ?? goal.dailyProtein
        goal.dailyCarbs = Double(carbsText) ?? goal.dailyCarbs
        goal.dailyFat = Double(fatText) ?? goal.dailyFat
        goal.dailyFiber = Double(fiberText) ?? goal.dailyFiber
        goal.dailySodium = Double(sodiumText) ?? goal.dailySodium
        goal.dailySugar = Double(sugarText) ?? goal.dailySugar
        goal.dailyCholesterol = Double(cholesterolText) ?? goal.dailyCholesterol
        goal.dailyCaffeine = Double(caffeineText) ?? goal.dailyCaffeine
        goal.dailyTeaPolyphenols = Double(teaPolyphenolsText) ?? goal.dailyTeaPolyphenols
        goal.dailyCalcium = Double(calciumText) ?? goal.dailyCalcium
        goal.dailyMagnesium = Double(magnesiumText) ?? goal.dailyMagnesium
        goal.dailyPotassium = Double(potassiumText) ?? goal.dailyPotassium
        goal.dailyIron = Double(ironText) ?? goal.dailyIron
        goal.dailyZinc = Double(zincText) ?? goal.dailyZinc
        goal.dailyVitaminA = Double(vitaminAText) ?? goal.dailyVitaminA
        goal.dailyVitaminC = Double(vitaminCText) ?? goal.dailyVitaminC
        goal.dailyVitaminD = Double(vitaminDText) ?? goal.dailyVitaminD
        goal.dailyVitaminE = Double(vitaminEText) ?? goal.dailyVitaminE
        goal.dailyVitaminB1 = Double(vitaminB1Text) ?? goal.dailyVitaminB1
        goal.dailyVitaminB2 = Double(vitaminB2Text) ?? goal.dailyVitaminB2
        goal.dailyNiacin = Double(niacinText) ?? goal.dailyNiacin
        goal.dailyVitaminB6 = Double(vitaminB6Text) ?? goal.dailyVitaminB6
        goal.dailyFolate = Double(folateText) ?? goal.dailyFolate
        goal.dailyVitaminB12 = Double(vitaminB12Text) ?? goal.dailyVitaminB12
        goal.updatedAt = .now
    }

    private func loadHealthTDEE() async {
        guard settings.useHealthKitForDynamicTDEE else { return }
        let summary = try? await HealthKitService.shared.energySummary(for: .now, settings: settings)
        healthTDEE = summary?.tdeeKcal
        if healthTDEE != nil {
            restoreRecommended()
        }
    }

    private func restoreRecommended() {
        saveStrategyValues()
        let calories = settings.calorieTarget(from: healthTDEE)
        goal.applyRecommendedValues(calories: calories, macros: settings.recommendedMacroTargets(calories: calories))
        loadValues()
    }

    private func saveStrategyValues() {
        if let calorieMultiplier = Double(calorieMultiplierText), calorieMultiplier > 0 {
            settings.customCalorieMultiplier = calorieMultiplier
        }
        if let proteinMultiplier = Double(proteinMultiplierText), proteinMultiplier >= 0 {
            settings.proteinTargetMultiplier = proteinMultiplier
        }
        settings.updatedAt = .now
    }
}

private struct GoalField: View {
    let label: String
    @Binding var text: String
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            TextField("", text: $text)
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
                .frame(width: 40, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}
