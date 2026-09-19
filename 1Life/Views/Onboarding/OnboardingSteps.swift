import SwiftUI
import PhotosUI

// MARK: - Welcome

struct WelcomeStep: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "WELCOME TO",
                        title: "1Life",
                        detail: "把饮食、身体、训练和习惯放到同一个清晰系统里。"
                    )

                    SystemPanel(title: "CORE WORKFLOW", detail: "从记录到复盘的日常路径") {
                        FeaturePoint(icon: "camera.fill", text: "拍照识别，快速估算食物营养")
                        SystemPanelDivider()
                        FeaturePoint(icon: "flame.fill", text: "摄入与消耗，一眼看清能量状态")
                        SystemPanelDivider()
                        FeaturePoint(icon: "figure.run", text: "围绕训练日调整营养节奏")
                    }

                    SystemPanel(title: "HEALTH NOTICE", detail: "营养与热量数据仅供个人记录参考") {
                        Text("1Life 不构成医疗、诊断或专业营养建议。你可以随时在设置中调整目标、提醒和 AI 配置。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "开始设置", action: onStart)
                Text("继续即表示同意服务条款和隐私政策")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeaturePoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            OnboardingIconBox(icon: icon)
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}

// MARK: - Language

struct LanguageStep: View {
    @Binding var selected: AppLanguage
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void

    private let options: [(AppLanguage, String, String)] = [
        (.system, "sys", "跟随系统"),
        (.zhHans, "CN", "简体中文"),
        (.english, "EN", "English"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "LANGUAGE",
                        title: "选择语言",
                        detail: "选择你偏好的语言来开始使用 1Life。"
                    )

                    SystemPanel(title: "LANGUAGE OPTIONS") {
                        ForEach(options, id: \.0) { lang, code, name in
                            OptionRow(
                                isSelected: selected == lang,
                                action: { HapticEngine.tap(); selected = lang }
                            ) {
                                HStack(spacing: 14) {
                                    Text(code)
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .frame(width: 40, height: 40)
                                        .background(FamilyUI.panelMutedBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                                    Text(name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "下一步", action: onNext)
            }
        }
    }
}

// MARK: - Preset

struct PresetStep: View {
    @Binding var selected: OnboardingPreset
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "STARTING POINT",
                        title: "选择初始方案",
                        detail: "先选一个生活目标，1Life 会预设饮食目标、饮水目标、训练目标和提醒节奏。"
                    )

                    SystemPanel(title: "PRESETS", detail: "后续都可以在设置中修改") {
                        ForEach(OnboardingPreset.allCases) { preset in
                            OptionRow(
                                isSelected: selected == preset,
                                action: { HapticEngine.tap(); selected = preset }
                            ) {
                                HStack(spacing: 12) {
                                    OnboardingIconBox(icon: preset.icon)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(preset.rawValue)
                                            .font(.subheadline.weight(.bold))
                                        Text(preset.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "套用并继续", action: onNext)
            }
        }
    }
}

// MARK: - Profile

struct ProfileStep: View {
    @Binding var nickname: String
    @Binding var avatarData: Data?
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "PROFILE",
                        title: "个人资料",
                        detail: "设置名字和头像，让 1Life 更像你的个人空间。"
                    )

                    SystemPanel(title: "IDENTITY", detail: "头像和昵称只保存在本机") {
                        HStack {
                            Spacer()
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    UserAvatarView(avatarData: avatarData, name: nickname, size: 96)
                                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                        .fill(FamilyUI.buttonBackground)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(FamilyTypography.text(size: 12, weight: .bold))
                                                .foregroundStyle(FamilyUI.buttonForeground)
                                        )
                                }
                            }
                            Spacer()
                        }
                        .onChange(of: selectedItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    avatarData = data
                                }
                            }
                        }

                        SystemPanelDivider()

                        TextField("你的名字", text: $nickname)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "下一步", action: onNext)
            }
        }
    }
}

// MARK: - Body Parameters

struct BodyParamsStep: View {
    @Binding var gender: Gender?
    @Binding var age: String
    @Binding var heightCm: String
    @Binding var weightKg: String
    @Binding var activityLevel: ActivityLevel?
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "BODY DATA",
                        title: "身体参数",
                        detail: "用于计算每日基础代谢，为你推荐个性化的热量目标。"
                    )

                    SystemPanel(title: "BASIC DATA", detail: "可以跳过，之后从设置或 Apple Health 同步") {
                        HStack(spacing: 10) {
                            ForEach(Gender.allCases) { g in
                                Button {
                                    HapticEngine.tap()
                                    gender = g
                                } label: {
                                    Text(g.displayName)
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(gender == g ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                                        .foregroundStyle(gender == g ? .white : .primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        SystemPanelDivider()
                        OnboardingMetricInput(label: "年龄", text: $age, unit: "岁")
                        SystemPanelDivider()
                        OnboardingMetricInput(label: "身高", text: $heightCm, unit: "cm")
                        SystemPanelDivider()
                        OnboardingMetricInput(label: "体重", text: $weightKg, unit: "kg")
                    }

                    SystemPanel(title: "ACTIVITY LEVEL") {
                        ForEach(ActivityLevel.allCases) { level in
                            OptionRow(
                                isSelected: activityLevel == level,
                                action: { HapticEngine.tap(); activityLevel = level }
                            ) {
                                HStack {
                                    Text(level.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            OnboardingBottomBar {
                OnboardingNextButton(title: "下一步", action: onNext)
                OnboardingSecondaryButton(title: "跳过") {
                    onSkip()
                }
            }
        }
    }
}

private struct ParamField: View {
    let label: String
    @Binding var text: String
    let unit: String

    var body: some View {
        OnboardingMetricInput(label: label, text: $text, unit: unit)
    }
}

// MARK: - Diet Goal

struct DietGoalStep: View {
    @Binding var selected: DietGoalMode
    let recommendedCalories: Double?
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "NUTRITION GOAL",
                        title: "饮食目标",
                        detail: "选择你的饮食方向，我们会为你推荐每日热量和营养目标。"
                    )

                    SystemPanel(title: "GOAL MODE") {
                        ForEach(DietGoalMode.allCases) { mode in
                            let cal = recommendedCalories.map { $0 * mode.calorieMultiplier }
                            OptionRow(
                                isSelected: selected == mode,
                                action: { HapticEngine.tap(); selected = mode }
                            ) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.displayName).fontWeight(.semibold)
                                        if let cal {
                                            Text("推荐 \(Int(cal)) kcal/天")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "下一步", action: onNext)
            }
        }
    }
}

// MARK: - Calorie Target

struct CalorieTargetStep: View {
    @Binding var calorieText: String
    let recommendedCalories: Double
    let dietGoalMode: DietGoalMode
    let weightKg: Double?
    let proteinTargetStrategy: ProteinTargetStrategy
    let proteinTargetMultiplier: Double
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "CALORIE TARGET",
                        title: "每日热量目标",
                        detail: "根据身体参数和饮食目标推荐；跳过身体参数时会用 2000 kcal 作为起点。"
                    )

                    SystemPanel(title: "DAILY CALORIES", detail: "之后可以在设置中随时调整") {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            TextField("\(Int(recommendedCalories))", text: $calorieText)
                                .font(FamilyTypography.text(size: 46, weight: .black))
                                .keyboardType(.numberPad)
                            Text("kcal")
                                .font(FamilyTypography.text(size: 20, weight: .semibold))
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

                    let calories = Double(calorieText) ?? recommendedCalories
                    let macros = UserSettings.recommendedMacroTargets(
                        calories: calories,
                        weightKg: weightKg,
                        dietGoalMode: dietGoalMode,
                        proteinTargetStrategy: proteinTargetStrategy,
                        proteinTargetMultiplier: proteinTargetMultiplier
                    )
                    SystemPanel(title: "MACRO TARGETS") {
                        MacroRow(name: "蛋白质", grams: macros.protein, color: FamilyUI.info)
                        SystemPanelDivider()
                        MacroRow(name: "碳水化合物", grams: macros.carbs, color: FamilyUI.accent)
                        SystemPanelDivider()
                        MacroRow(name: "脂肪", grams: macros.fat, color: FamilyUI.warning)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            OnboardingBottomBar {
                OnboardingNextButton(title: "下一步", action: onNext)
            }
        }
    }
}

private struct MacroRow: View {
    let name: String
    let grams: Double
    let color: Color

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(Int(grams))g")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Reminder

struct ReminderStep: View {
    @Binding var breakfastHour: Int
    @Binding var lunchHour: Int
    @Binding var dinnerHour: Int
    @Binding var breakfastEnabled: Bool
    @Binding var lunchEnabled: Bool
    @Binding var dinnerEnabled: Bool
    let stepNum: Int
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "REMINDERS",
                        title: "提醒节奏",
                        detail: "设置三餐提醒时间，到点提醒你记录饮食。"
                    )

                    SystemPanel(title: "MEAL REMINDERS") {
                        ReminderRow(
                            icon: "sunrise.fill", name: "早餐",
                            hour: $breakfastHour, isEnabled: $breakfastEnabled
                        )
                        SystemPanelDivider()
                        ReminderRow(
                            icon: "sun.max.fill", name: "午餐",
                            hour: $lunchHour, isEnabled: $lunchEnabled
                        )
                        SystemPanelDivider()
                        ReminderRow(
                            icon: "moon.fill", name: "晚餐",
                            hour: $dinnerHour, isEnabled: $dinnerEnabled
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "下一步", action: onNext)
            }
        }
    }
}

private struct ReminderRow: View {
    let icon: String
    let name: String
    @Binding var hour: Int
    @Binding var isEnabled: Bool

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour)) ?? .now
            },
            set: {
                hour = Calendar.current.component(.hour, from: $0)
            }
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            OnboardingIconBox(icon: icon, tone: FamilyUI.accent)
            Text(name)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if isEnabled {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(AppSwitchStyle())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AI Config

struct AIConfigStep: View {
    @Binding var selectedProvider: AIProvider
    @Binding var apiKeyText: String
    let stepNum: Int
    let onBack: () -> Void
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(stepNum: stepNum, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPageHeader(
                        eyebrow: "AI SETUP",
                        title: "AI 配置",
                        detail: "配置 AI 服务商，之后可以拍照识别食物和用自然语言记录饮食。"
                    )

                    SystemPanel(title: "AI PROVIDER") {
                        Picker("AI 服务商", selection: $selectedProvider) {
                            ForEach(AIProvider.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(FamilyUI.accent)
                    }

                    SystemPanel(title: "API KEY", detail: "Key 会保存到 iOS Keychain") {
                        SecureField("粘贴你的 API Key", text: $apiKeyText)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    }

                    SystemPanel(title: "MODEL CAPABILITY") {
                        HStack(spacing: 12) {
                            OnboardingIconBox(
                                icon: selectedProvider.supportsVision(model: selectedProvider.defaultModel) ? "camera.fill" : "camera.badge.ellipsis",
                                tone: selectedProvider.supportsVision(model: selectedProvider.defaultModel) ? FamilyUI.success : .secondary
                            )
                            Text(selectedProvider.supportsVision(model: selectedProvider.defaultModel) ? "支持拍照识别" : "不支持拍照识别")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            SystemStatusBadge(
                                text: selectedProvider.defaultModel.uppercased(),
                                tone: .neutral
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)

            OnboardingBottomBar {
                OnboardingNextButton(title: "完成", isEnabled: !apiKeyText.isEmpty) {
                    HapticEngine.success()
                    onDone()
                }
                OnboardingSecondaryButton(title: "跳过，稍后设置") {
                    onSkip()
                }
            }
        }
    }
}

// MARK: - Complete

struct CompleteStep: View {
    let dietGoalName: String
    let caloriesTarget: Int
    let reminderSummary: String
    let nickname: String
    let avatarData: Data?
    let onEnter: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "READY",
                        title: "设置完成",
                        detail: "一切就绪，开始记录你的每一餐。"
                    )

                    SystemPanel(title: "YOUR SETUP") {
                        HStack(spacing: 12) {
                            UserAvatarView(avatarData: avatarData, name: nickname, size: 36)
                            Text("个人资料")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(nickname.isEmpty ? "用户" : nickname)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        SystemPanelDivider()
                        SummaryRow(icon: "flame.fill", label: "饮食目标", value: dietGoalName)
                        SystemPanelDivider()
                        SummaryRow(icon: "bolt.fill", label: "每日热量", value: "\(caloriesTarget) kcal")
                        SystemPanelDivider()
                        SummaryRow(icon: "bell.fill", label: "提醒", value: reminderSummary)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }

            OnboardingBottomBar {
                OnboardingNextButton(title: "开始记录") {
                    HapticEngine.success()
                    onEnter()
                }
            }
        }
    }
}
