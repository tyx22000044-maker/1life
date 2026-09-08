import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: UserSettings
    @Query(sort: [SortDescriptor(\NutritionGoal.effectiveDate, order: .reverse)])
    private var nutritionGoals: [NutritionGoal]

    @State private var step = 0

    // Step 1: Language
    @State private var selectedLanguage: AppLanguage = .system
    // Step 2: Preset
    @State private var selectedPreset: OnboardingPreset = .balanced
    // Step 3: Profile
    @State private var nickname = ""
    @State private var avatarData: Data?
    // Step 4: Body Params
    @State private var gender: Gender?
    @State private var ageText = ""
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var activityLevel: ActivityLevel?
    // Step 5: Diet Goal
    @State private var dietGoalMode: DietGoalMode = .balanced
    // Step 6: Calorie Target
    @State private var calorieText = ""
    // Step 7: Reminders
    @State private var breakfastHour = 8
    @State private var lunchHour = 12
    @State private var dinnerHour = 19
    @State private var breakfastEnabled = true
    @State private var lunchEnabled = true
    @State private var dinnerEnabled = true
    // Step 8: AI Config
    @State private var selectedAIProvider: AIProvider = .claude
    @State private var apiKeyText = ""
    @State private var aiConfigError: String?
    private let aiConfigurationService = LocalAIConfigurationService()

    private var estimatedTDEE: Double? {
        guard let gender,
              let age = Int(ageText),
              let height = Double(heightText),
              let weight = Double(weightText),
              let activityLevel else { return nil }
        let bmr: Double
        switch gender {
        case .male: bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        case .female: bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        }
        return bmr * activityLevel.multiplier
    }

    private var recommendedCalories: Double {
        (estimatedTDEE ?? 2000) * dietGoalMode.calorieMultiplier
    }

    private var recommendedMacros: RecommendedMacroTargets {
        UserSettings.recommendedMacroTargets(
            calories: Double(calorieText) ?? recommendedCalories,
            weightKg: Double(weightText),
            dietGoalMode: dietGoalMode,
            proteinTargetStrategy: selectedPreset.proteinStrategy,
            proteinTargetMultiplier: selectedPreset.proteinMultiplier
        )
    }

    var body: some View {
        ZStack {
            FamilyUI.pageBackground.ignoresSafeArea()
            Group {
                switch step {
                case 0:
                    WelcomeStep(onStart: next)
                case 1:
                    LanguageStep(selected: $selectedLanguage, stepNum: 1, onBack: back, onNext: next)
                case 2:
                    PresetStep(
                        selected: $selectedPreset,
                        stepNum: 2,
                        onBack: back,
                        onNext: {
                            applyPreset(selectedPreset)
                            next()
                        }
                    )
                case 3:
                    ProfileStep(nickname: $nickname, avatarData: $avatarData, stepNum: 3, onBack: back, onNext: next)
                case 4:
                    BodyParamsStep(
                        gender: $gender, age: $ageText, heightCm: $heightText,
                        weightKg: $weightText, activityLevel: $activityLevel,
                        stepNum: 4, onBack: back, onNext: next, onSkip: next
                    )
                case 5:
                    DietGoalStep(
                        selected: $dietGoalMode,
                        recommendedCalories: estimatedTDEE,
                        stepNum: 5, onBack: back, onNext: {
                            if calorieText.isEmpty {
                                calorieText = "\(Int(recommendedCalories))"
                            }
                            next()
                        }
                    )
                case 6:
                    CalorieTargetStep(
                        calorieText: $calorieText,
                        recommendedCalories: recommendedCalories,
                        dietGoalMode: dietGoalMode,
                        weightKg: Double(weightText),
                        proteinTargetStrategy: selectedPreset.proteinStrategy,
                        proteinTargetMultiplier: selectedPreset.proteinMultiplier,
                        stepNum: 6, onBack: back, onNext: next
                    )
                case 7:
                    ReminderStep(
                        breakfastHour: $breakfastHour, lunchHour: $lunchHour, dinnerHour: $dinnerHour,
                        breakfastEnabled: $breakfastEnabled, lunchEnabled: $lunchEnabled, dinnerEnabled: $dinnerEnabled,
                        stepNum: 7, onBack: back, onNext: next
                    )
                case 8:
                    AIConfigStep(
                        selectedProvider: $selectedAIProvider, apiKeyText: $apiKeyText,
                        stepNum: 8, onBack: back,
                        onDone: {
                            if saveAIConfig() {
                                complete()
                            }
                        },
                        onSkip: {
                            settings.isAIConfigured = false
                            complete()
                        }
                    )
                default:
                    CompleteStep(
                        dietGoalName: dietGoalMode.displayName,
                        caloriesTarget: Int(Double(calorieText) ?? recommendedCalories),
                        reminderSummary: reminderSummary,
                        nickname: nickname,
                        avatarData: avatarData,
                        onEnter: markDone
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
            .id(step)

            if let aiConfigError {
                AppErrorBanner(title: "AI 配置失败", message: aiConfigError) {
                    self.aiConfigError = nil
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: step)
        .background(FamilyUI.pageBackground.ignoresSafeArea())
    }

    private func next() { step += 1 }
    private func back() { step -= 1 }

    private var reminderSummary: String {
        var parts: [String] = []
        if breakfastEnabled { parts.append("早\(breakfastHour):00") }
        if lunchEnabled { parts.append("午\(lunchHour):00") }
        if dinnerEnabled { parts.append("晚\(dinnerHour):00") }
        return parts.isEmpty ? "未开启" : parts.joined(separator: " · ")
    }

    private func applyPreset(_ preset: OnboardingPreset) {
        dietGoalMode = preset.dietGoalMode
        breakfastHour = preset.defaultReminderHours.breakfast
        lunchHour = preset.defaultReminderHours.lunch
        dinnerHour = preset.defaultReminderHours.dinner
        breakfastEnabled = true
        lunchEnabled = true
        dinnerEnabled = true
        calorieText = ""
    }

    private func saveAIConfig() -> Bool {
        let trimmedKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            aiConfigError = "请输入 API Key，或选择跳过。"
            return false
        }
        settings.selectedAIProviderRaw = selectedAIProvider.rawValue
        settings.selectedAIModel = selectedAIProvider.defaultModel
        do {
            try aiConfigurationService.saveAPIKey(trimmedKey, provider: selectedAIProvider)
            settings.isAIConfigured = true
            aiConfigError = nil
            return true
        } catch {
            settings.isAIConfigured = false
            aiConfigError = "保存 API Key 失败，请稍后在设置中配置。"
            return false
        }
    }

    private func complete() {
        // Save all settings
        settings.languageRaw = selectedLanguage.rawValue
        settings.nickname = nickname.trimmingCharacters(in: .whitespaces)
        if let avatarData { settings.avatarImageData = avatarData }
        settings.dietGoalModeRaw = dietGoalMode.rawValue
        settings.proteinTargetStrategyRaw = selectedPreset.proteinStrategy.rawValue
        settings.proteinTargetMultiplier = selectedPreset.proteinMultiplier
        settings.genderRaw = gender?.rawValue
        settings.age = Int(ageText)
        settings.heightCm = Double(heightText)
        settings.weightKg = Double(weightText)
        settings.activityLevelRaw = activityLevel?.rawValue
        settings.dailyWaterGoalMl = selectedPreset.waterGoalMl
        settings.weeklyWorkoutTargetCount = selectedPreset.weeklyWorkoutTargetCount
        settings.weeklyWorkoutTargetMinutes = selectedPreset.weeklyWorkoutTargetMinutes
        settings.isBreakfastReminderEnabled = breakfastEnabled
        settings.breakfastReminderHour = breakfastHour
        settings.isLunchReminderEnabled = lunchEnabled
        settings.lunchReminderHour = lunchHour
        settings.isDinnerReminderEnabled = dinnerEnabled
        settings.dinnerReminderHour = dinnerHour
        settings.updatedAt = .now

        let calories = Double(calorieText) ?? recommendedCalories
        let recommendedGoal = NutritionGoal.fromRecommendedTargets(
            calories: calories,
            macros: recommendedMacros
        )
        if let existingGoal = nutritionGoals.first(where: { $0.effectiveDate.isSameDay(as: .now) }) ?? nutritionGoals.first {
            existingGoal.effectiveDate = .now
            existingGoal.dailyCalories = recommendedGoal.dailyCalories
            existingGoal.dailyProtein = recommendedGoal.dailyProtein
            existingGoal.dailyCarbs = recommendedGoal.dailyCarbs
            existingGoal.dailyFat = recommendedGoal.dailyFat
            existingGoal.updatedAt = .now
        } else {
            modelContext.insert(recommendedGoal)
        }

        step = 9
    }

    private func markDone() {
        HapticEngine.success()
        settings.hasCompletedOnboarding = true
        settings.updatedAt = .now
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.rescheduleRemindersIfNeeded(settings: settings)
    }
}
