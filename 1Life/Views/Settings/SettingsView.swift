import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppViewModel.self) private var appViewModel
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\NutritionGoal.effectiveDate, order: .reverse)])
    private var nutritionGoals: [NutritionGoal]
    @Query private var habits: [Habit]
    @Query private var userFoods: [UserFood]
    @Query private var mealTemplates: [MealTemplate]
    @Query private var journalEntries: [JournalEntry]
    @Query private var workouts: [WorkoutLog]
    @Query(sort: [SortDescriptor(\BodyMeasurement.date, order: .reverse)])
    private var bodyMeasurements: [BodyMeasurement]
    @Query(sort: [SortDescriptor(\BowelLog.date, order: .reverse)])
    private var bowelLogs: [BowelLog]
    @Query(sort: [SortDescriptor(\AIChatMessage.createdAt)])
    private var chatMessages: [AIChatMessage]
    @Query private var drinkRecords: [DrinkRecord]
    @Query private var supplementRecords: [SupplementRecord]

    @Query private var allMeals: [Meal]
    @Query private var allWaterLogs: [WaterLog]

    @State private var isShowingProfileEditor = false
    @State private var isShowingPrivacySheet = false
    @State private var isShowingManualSheet = false
    @State private var isShowingInboxSheet = false
    @State private var isShowingExportPicker = false
    @State private var isShowingImportPicker = false
    @State private var pendingImportURL: URL?
    @State private var isShowingImportConfirmation = false
    @State private var shareItem: ShareSheetItem?
    @State private var isShowingPDFExportSheet = false
    @State private var pdfExportStartDate = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @State private var pdfExportEndDate = Calendar.current.startOfDay(for: .now)
    @State private var isExportingPDF = false
    @State private var pdfExportProgressText = ""
    @State private var clearDataStep = 0
    @State private var healthSummary: HealthEnergySummary?
    @State private var isLoadingHealth = false
    @State private var bannerCenter = GlobalBannerCenter.shared

    private var currentSettings: UserSettings? { settings.first }
    private var currentGoal: NutritionGoal? { nutritionGoals.first }
    private var mealLibraryTemplates: [MealTemplate] {
        mealTemplates.filter { TemplateLibraryCategory.meal.matches($0) }
    }
    private var currentVisionSupport: Bool {
        guard let currentSettings else { return false }
        return currentSettings.selectedAIProvider.supportsVision(model: currentSettings.selectedAIModel)
    }

    private var healthStatusText: String {
        if isLoadingHealth { return "读取中" }
        if healthSummary?.tdeeKcal != nil { return "已读取" }
        return currentSettings?.isHealthKitEnabled == true ? "已授权" : "未连接"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                    profileSection
                    aiConfigSection
                        .id("settings-ai-configuration")
                    healthGoalSection
                    appleHealthSection
                    feedbackSection
                    foodLibrarySection
                    pluginSection
                    reminderSection
                    dataSection
                    appearanceSection
                    aboutSection
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)
                    .padding(.top, 0)
                    .padding(.bottom, AppSpacing.pageBottom)
                }
                .onAppear {
                    focusPendingSettings(proxy)
                }
                .onChange(of: appViewModel.pendingSettingsFocus) { _, _ in
                    focusPendingSettings(proxy)
                }
            }
            .background(FamilyUI.pageBackground.ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingProfileEditor) {
                if let currentSettings {
                    ProfileEditorSheet(settings: currentSettings)
                }
            }
            .sheet(isPresented: $isShowingPrivacySheet) {
                PrivacySheet()
            }
            .sheet(isPresented: $isShowingManualSheet) {
                UserManualSheet()
            }
            .sheet(isPresented: $isShowingInboxSheet) {
                InAppInboxSheet()
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $isShowingPDFExportSheet) {
                PDFExportRangeSheet(
                    startDate: $pdfExportStartDate,
                    endDate: $pdfExportEndDate,
                    isExporting: isExportingPDF,
                    progressText: pdfExportProgressText,
                    onExport: { exportNutritionPDF() }
                )
            }
            .fileImporter(isPresented: $isShowingImportPicker, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    isShowingImportConfirmation = true
                case .failure:
                    importJSON(result)
                }
            }
            .alert("导入 JSON 备份", isPresented: $isShowingImportConfirmation) {
                Button("取消", role: .cancel) {
                    pendingImportURL = nil
                }
                Button("覆盖并导入", role: .destructive) {
                    if let pendingImportURL {
                        importJSON(.success(pendingImportURL))
                    }
                    pendingImportURL = nil
                }
            } message: {
                Text("导入会覆盖当前本机的饮食、饮水、习惯、日志、食物库、模板、营养目标和聊天历史。建议先导出当前数据备份。")
            }
            .onAppear {
                LegacyDrinkTemplateMigrator.migrate(in: modelContext)
            }
        }
    }

    private func focusPendingSettings(_ proxy: ScrollViewProxy) {
        guard appViewModel.pendingSettingsFocus == .aiConfiguration else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo("settings-ai-configuration", anchor: .top)
            }
            appViewModel.pendingSettingsFocus = nil
        }
    }

    private var appleHealthSection: some View {
        SystemPanel(title: "Apple Health", detail: "能量与身体：活动热量、静息热量、步数、身高、体重、体脂，用于动态 TDEE 和身体记录。训练与作息（训练、平均心率、距离、睡眠、日照）只在你进入训练时间线或回顾页时单独申请；任何一类被拒绝只会让该项显示为破折号，本机记录不受影响。") {
            if let s = currentSettings {
                Toggle(isOn: Binding(
                    get: { s.useHealthKitForDynamicTDEE },
                    set: { value in
                        s.useHealthKitForDynamicTDEE = value
                        s.isHealthKitEnabled = value || s.isHealthKitEnabled
                        s.updatedAt = .now
                        if value {
                            Task { await connectHealthKit(settings: s) }
                        }
                    }
                )) {
                    AppSettingsRow(
                        icon: "heart.text.square.fill",
                        title: "动态 TDEE",
                        subtitle: "根据活动与静息能量动态更新今日目标",
                        value: s.useHealthKitForDynamicTDEE ? "已开启" : "关闭",
                        emphasizesValue: s.useHealthKitForDynamicTDEE
                    )
                }
                .tint(FamilyUI.accent)

                SystemPanelDivider()

                Button {
                    Task { await connectHealthKit(settings: s) }
                } label: {
                    AppSettingsRow(
                        icon: "bolt.heart.fill",
                        title: isLoadingHealth ? "读取中..." : "连接 Apple Health",
                        subtitle: "授权读取活动热量、静息热量、步数与体重",
                        value: healthStatusText,
                        showsChevron: true,
                        emphasizesValue: healthSummary?.tdeeKcal != nil
                    )
                }
                .buttonStyle(.plain)

                if let healthSummary {
                    SystemPanelDivider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("今日消耗")
                            Spacer()
                            Text(healthSummary.tdeeKcal.map { "\(Int($0)) kcal" } ?? "数据不足")
                                .foregroundStyle(FamilyUI.accent)
                        }
                        HStack {
                            Text("静息")
                            Spacer()
                            Text(restingEnergyText(healthSummary))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("活动")
                            Spacer()
                            Text("\(Int(healthSummary.activeEnergyKcal)) kcal")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FamilyUI.panelMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }

            }
        }
    }

    private func connectHealthKit(settings: UserSettings) async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }

        do {
            try await HealthKitService.shared.requestAuthorization()
            // Sleep, workouts, heart rate, distance and daylight are requested by the
            // screens that show them; a refusal there must not break the TDEE feature.
            try? await HealthKitService.shared.requestActivityDetailAuthorization()
            HealthKitService.shared.enableEnergyBackgroundDelivery()
            let summary = try await HealthKitService.shared.energySummary(for: .now, settings: settings)
            healthSummary = summary
            settings.isHealthKitEnabled = true
            settings.useHealthKitForDynamicTDEE = true
            settings.updatedAt = .now
            if let tdee = summary.tdeeKcal, let goal = currentGoal {
                syncRecommendedGoal(settings: settings, goal: goal, healthTDEE: tdee)
            }
        } catch {
            bannerCenter.show(title: "Apple Health 连接失败", message: error.localizedDescription, tone: .warning)
            settings.useHealthKitForDynamicTDEE = false
            settings.updatedAt = .now
        }
    }

    private func syncRecommendedGoal(settings: UserSettings, goal: NutritionGoal, healthTDEE: Double) {
        let calories = settings.calorieTarget(from: healthTDEE)
        goal.dailyCalories = calories
        goal.updatedAt = .now
    }

    private func bodyParameterStatus(for settings: UserSettings) -> String {
        if settings.hasBodyParameters { return "已完成" }
        let missing = missingBodyParameters(for: settings)
        let filled = 5 - missing.count
        if settings.heightCm != nil && settings.weightKg != nil {
            return missing.isEmpty ? "已完成" : "缺 \(missing.joined(separator: "、"))"
        }
        if filled > 0 {
            return "缺 \(5 - filled) 项"
        }
        return "未设置"
    }

    private func missingBodyParameters(for settings: UserSettings) -> [String] {
        var missing: [String] = []
        if settings.genderRaw == nil { missing.append("性别") }
        if settings.age == nil { missing.append("年龄") }
        if settings.heightCm == nil { missing.append("身高") }
        if settings.weightKg == nil { missing.append("体重") }
        if settings.activityLevelRaw == nil { missing.append("活动") }
        return missing
    }

    private func restingEnergyText(_ summary: HealthEnergySummary) -> String {
        guard let resting = summary.restingEnergyKcal else { return "数据不足" }
        let suffix = summary.usesEstimatedBMR ? " 估算" : ""
        return "\(Int(resting)) kcal\(suffix)"
    }

    // MARK: - Profile

    private var profileSection: some View {
        SystemPanel(title: "个人资料", detail: "头像、昵称与个人资料") {
            if let s = currentSettings {
                Button { isShowingProfileEditor = true } label: {
                    HStack(spacing: 14) {
                        UserAvatarView(avatarData: s.avatarImageData, name: s.nickname, size: 64)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(s.nickname.isEmpty ? "用户" : s.nickname)
                                .font(.title3.weight(.bold))
                            Text("1Life / 编辑昵称与头像")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SystemStatusBadge(
                                    text: s.isAIConfigured ? "AI 已配置" : "AI 未设置",
                                    tone: s.isAIConfigured ? .success : .warning
                                )
                                SystemStatusBadge(
                                    text: s.useHealthKitForDynamicTDEE ? "健康已连接" : "本机模式",
                                    tone: s.useHealthKitForDynamicTDEE ? .accent : .neutral
                                )
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Body Params

    private var healthGoalSection: some View {
        SystemPanel(title: "身体与目标", detail: "身体参数、营养目标与饮水基线") {
            if let s = currentSettings {
                NavigationLink {
                    BodyParamsSettingsView(settings: s)
                } label: {
                    AppSettingsRow(
                        icon: "figure.stand",
                        title: "身体参数",
                        subtitle: "身高、体重、体脂与基础代谢",
                        value: bodyParameterStatus(for: s),
                        showsChevron: true,
                        emphasizesValue: s.heightCm != nil || s.weightKg != nil
                    )
                }
                .buttonStyle(.plain)
            }

            if let s = currentSettings, let goal = currentGoal {
                SystemPanelDivider()

                NavigationLink {
                    NutritionGoalSettingsView(settings: s, goal: goal)
                } label: {
                    AppSettingsRow(
                        icon: "flame.fill",
                        title: "每日目标",
                        subtitle: "热量与三大营养素目标",
                        value: "\(Int(goal.dailyCalories)) kcal",
                        showsChevron: true,
                        emphasizesValue: true
                    )
                }
                .buttonStyle(.plain)

                SystemPanelDivider()

                Picker(selection: Binding(
                    get: { s.dietGoalMode },
                    set: {
                        s.dietGoalMode = $0
                        s.updatedAt = .now
                        if s.useHealthKitForDynamicTDEE, let tdee = healthSummary?.tdeeKcal {
                            syncRecommendedGoal(settings: s, goal: goal, healthTDEE: tdee)
                        }
                    }
                )) {
                    ForEach(DietGoalMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                } label: {
                    AppSettingsRow(
                        icon: "target",
                        title: "饮食模式",
                        subtitle: "选择减脂、增肌、维持或均衡目标",
                        value: s.dietGoalMode.displayName
                    )
                }
                .pickerStyle(.menu)
                .tint(FamilyUI.accent)

                SystemPanelDivider()

                Stepper(value: Binding(
                    get: { s.dailyWaterGoalMl },
                    set: { s.dailyWaterGoalMl = $0; s.updatedAt = .now }
                ), in: 500...5000, step: 50) {
                    AppSettingsRow(
                        icon: "drop.fill",
                        title: "饮水目标",
                        subtitle: "当天饮水基准",
                        value: "\(Int(s.dailyWaterGoalMl)) ml"
                    )
                }
                .tint(FamilyUI.accent)

                SystemPanelDivider()

                Stepper(value: Binding(
                    get: { s.defaultCupMl },
                    set: { s.defaultCupMl = $0; s.updatedAt = .now }
                ), in: 50...1000, step: 50) {
                    AppSettingsRow(
                        icon: "cup.and.saucer.fill",
                        title: "一杯容量",
                        subtitle: "快捷饮水记录默认值",
                        value: "\(Int(s.defaultCupMl)) ml"
                    )
                }
                .tint(FamilyUI.accent)
            }
        }
    }

    // MARK: - Food Library

    private var foodLibrarySection: some View {
        SystemPanel(title: "食物库", detail: "管理已确认、可复用的营养资料") {
            NavigationLink {
                MealLibraryHubView()
            } label: {
                AppSettingsRow(
                    icon: "fork.knife",
                    title: "餐食库",
                    subtitle: "餐食记录、单品和餐食模板",
                    value: "\(userFoods.count + mealLibraryTemplates.count) 个",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            NavigationLink {
                DrinkLibraryPluginView(mode: .library)
            } label: {
                AppSettingsRow(
                    icon: "cup.and.saucer.fill",
                    title: "饮品库",
                    subtitle: "品牌饮品、杯型、糖度和营养版本",
                    value: "\(drinkRecords.count) 条",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            NavigationLink {
                SupplementLibraryPluginView(mode: .library)
            } label: {
                AppSettingsRow(
                    icon: "pills.fill",
                    title: "补剂库",
                    subtitle: "蛋白粉、维生素、肌酸等补剂资料",
                    value: "\(supplementRecords.count) 条",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Plugins

    private var pluginSection: some View {
        SystemPanel(title: "插件", detail: "识别图片或文字，确认后写入对应资料库") {
            NavigationLink {
                MealNutritionRecognitionPluginView()
            } label: {
                AppSettingsRow(
                    icon: "camera.macro",
                    title: "餐食营养识别",
                    subtitle: "参照饮品识别流程，输出到餐食库",
                    value: currentVisionSupport ? "支持图片" : "文字可用",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            NavigationLink {
                DrinkNutritionRecognitionPluginView()
            } label: {
                AppSettingsRow(
                    icon: "cup.and.saucer.fill",
                    title: "饮品营养识别",
                    subtitle: "拍成分表校对后保存到饮品库",
                    value: currentVisionSupport ? "支持图片" : "文字可用",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            NavigationLink {
                SupplementNutritionRecognitionPluginView()
            } label: {
                AppSettingsRow(
                    icon: "pills.fill",
                    title: "补剂营养识别",
                    subtitle: "识别包装和成分表，输出到补剂库",
                    value: currentVisionSupport ? "支持图片" : "文字可用",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackSection: some View {
        SystemPanel(title: "反馈", detail: "控制震动与轻提示音") {
            if let s = currentSettings {
                Toggle(isOn: Binding(
                    get: { s.isHapticsEnabled },
                    set: { value in
                        s.isHapticsEnabled = value
                        s.updatedAt = .now
                        FeedbackPreferences.shared.setHapticsEnabled(value)
                    }
                )) {
                    AppSettingsRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "震动反馈",
                        subtitle: "按钮点击、保存成功与警示操作时触发",
                        value: s.isHapticsEnabled ? "开启" : "关闭",
                        emphasizesValue: s.isHapticsEnabled
                    )
                }
                .tint(FamilyUI.accent)

                SystemPanelDivider()

                Toggle(isOn: Binding(
                    get: { s.isSoundEffectsEnabled },
                    set: { value in
                        s.isSoundEffectsEnabled = value
                        s.updatedAt = .now
                        FeedbackPreferences.shared.setSoundEffectsEnabled(value)
                    }
                )) {
                    AppSettingsRow(
                        icon: "speaker.wave.2.fill",
                        title: "提示音",
                        subtitle: "成功完成、识别确认等轻量确认音",
                        value: s.isSoundEffectsEnabled ? "开启" : "关闭",
                        emphasizesValue: s.isSoundEffectsEnabled
                    )
                }
                .tint(FamilyUI.accent)
            }
        }
    }

    // MARK: - Reminders

    private var reminderSection: some View {
        SystemPanel(title: "提醒", detail: "保持早餐、午餐和晚餐记录节奏") {
            if let s = currentSettings {
                ReminderSettingRow(icon: "sunrise.fill", name: "早餐", hour: Binding(
                    get: { s.breakfastReminderHour },
                    set: { s.breakfastReminderHour = $0; s.updatedAt = .now }
                ), isEnabled: Binding(
                    get: { s.isBreakfastReminderEnabled },
                    set: { s.isBreakfastReminderEnabled = $0; s.updatedAt = .now }
                ))

                SystemPanelDivider()

                ReminderSettingRow(icon: "sun.max.fill", name: "午餐", hour: Binding(
                    get: { s.lunchReminderHour },
                    set: { s.lunchReminderHour = $0; s.updatedAt = .now }
                ), isEnabled: Binding(
                    get: { s.isLunchReminderEnabled },
                    set: { s.isLunchReminderEnabled = $0; s.updatedAt = .now }
                ))

                SystemPanelDivider()

                ReminderSettingRow(icon: "moon.fill", name: "晚餐", hour: Binding(
                    get: { s.dinnerReminderHour },
                    set: { s.dinnerReminderHour = $0; s.updatedAt = .now }
                ), isEnabled: Binding(
                    get: { s.isDinnerReminderEnabled },
                    set: { s.isDinnerReminderEnabled = $0; s.updatedAt = .now }
                ))
            }
        }
    }

    // MARK: - AI Config

    private var aiConfigSection: some View {
        SystemPanel(title: "AI 配置", detail: "服务商、模型选择、API Key 与对话历史") {
            if let s = currentSettings {
                NavigationLink {
                    AIConfigurationSettingsView(settings: s)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        AppSettingsRow(
                            icon: "sparkles",
                            title: "AI 服务商",
                            subtitle: "配置 AI 服务商、模型与 API Key",
                            value: s.isAIConfigured ? s.selectedAIProvider.displayName : "未配置",
                            showsChevron: true,
                            emphasizesValue: s.isAIConfigured
                        )

                        HStack(spacing: 8) {
                            SystemStatusBadge(
                                text: s.isAIConfigured ? "已配置" : "未设置",
                                tone: s.isAIConfigured ? .success : .warning
                            )
                            SystemStatusBadge(
                                text: currentVisionSupport ? "支持视觉" : "仅文本",
                                tone: currentVisionSupport ? .accent : .neutral
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        SettingsDataSection(
            mealCount: allMeals.count,
            workoutCount: workouts.count,
            isShowingExportPicker: $isShowingExportPicker,
            isShowingImportPicker: $isShowingImportPicker,
            isShowingPDFExportSheet: $isShowingPDFExportSheet,
            clearDataStep: $clearDataStep,
            preparePDFExportRange: preparePDFExportRange,
            exportCSV: { exportCSV(granularity: $0) },
            exportJSON: exportJSON,
            exportWorkoutCSV: exportWorkoutCSV,
            exportWorkoutJSON: exportWorkoutJSON,
            clearAllData: clearAllData
        )
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SystemPanel(title: "显示", detail: "浅色、深色或跟随系统") {
            if let s = currentSettings {
                AppSettingsRow(
                    icon: "circle.lefthalf.filled",
                    title: "显示模式",
                    subtitle: "切换浅色、深色或跟随系统",
                    value: s.appearance.displayName
                )

                Picker("显示模式", selection: Binding<AppearanceMode>(
                    get: { s.appearance },
                    set: { mode in
                        s.appearance = mode
                        s.updatedAt = .now
                    }
                )) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        SystemPanel(title: "关于", detail: "隐私、说明文档、反馈与版本信息") {
            Button {
                isShowingInboxSheet = true
            } label: {
                AppSettingsRow(
                    icon: "tray.full.fill",
                    title: "站内信",
                    subtitle: "版本更新、重要说明和本地公告",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            Button {
                isShowingPrivacySheet = true
            } label: {
                AppSettingsRow(
                    icon: "hand.raised.fill",
                    title: "隐私政策",
                    subtitle: "本地存储、AI 服务与 Apple Health 使用说明",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            Button {
                isShowingManualSheet = true
            } label: {
                AppSettingsRow(
                    icon: "book.fill",
                    title: "用户手册",
                    subtitle: "记录饮食、AI 配置、数据管理与参考说明",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            if let url = URL(string: "mailto:tyx22000044@gmail.com") {
                SystemPanelDivider()

                Link(destination: url) {
                    AppSettingsRow(
                        icon: "envelope.fill",
                        title: "反馈",
                        subtitle: "发送问题、建议或功能反馈",
                        showsChevron: true
                    )
                }
            }

            SystemPanelDivider()

            HStack {
                Text("版本")
                    .font(.custom("Archivo-SemiBold", size: 11))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appVersionDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private var appVersionDescription: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未设置"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return build.map { "v\(version) (\($0))" } ?? "v\(version)"
    }

    private func exportCSV(granularity: ExportService.CSVGranularity) {
        bannerCenter.show(title: "正在导出 CSV", message: "正在整理记录并生成文件。", tone: .success)
        do {
            let url = try SettingsDataCoordinator.exportCSV(
                settings: currentSettings,
                meals: allMeals,
                waterLogs: allWaterLogs,
                workouts: workouts,
                bodyMeasurements: bodyMeasurements,
                bowelLogs: bowelLogs,
                granularity: granularity
            )
            shareItem = ShareSheetItem(url: url)
            bannerCenter.show(title: "CSV 导出完成", message: "文件已准备好，可以分享或存储。", tone: .success)
        } catch {
            bannerCenter.show(title: "CSV 导出失败", message: error.localizedDescription, tone: .error)
        }
    }

    private func exportWorkoutCSV() {
        let csv = WorkoutExportService.exportCSV(workouts)
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("1Life-训练数据.csv")
            try csv.data(using: .utf8)?.write(to: url, options: [.atomic])
            shareItem = ShareSheetItem(url: url)
            bannerCenter.show(title: "训练 CSV 导出完成", message: "已准备好 (workouts.count) 条训练记录。", tone: .success)
        } catch {
            bannerCenter.show(title: "训练 CSV 导出失败", message: error.localizedDescription, tone: .error)
        }
    }

    private func exportWorkoutJSON() {
        do {
            let data = try WorkoutExportService.exportJSON(workouts)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("1Life-训练数据.json")
            try data.write(to: url, options: [.atomic])
            shareItem = ShareSheetItem(url: url)
            bannerCenter.show(title: "训练 JSON 导出完成", message: "已准备好 (workouts.count) 条训练记录。", tone: .success)
        } catch {
            bannerCenter.show(title: "训练 JSON 导出失败", message: error.localizedDescription, tone: .error)
        }
    }

    private func preparePDFExportRange() {
        let range = SettingsDataCoordinator.defaultPDFRange(
            meals: allMeals,
            waterLogs: allWaterLogs,
            workouts: workouts,
            bodyMeasurements: bodyMeasurements,
            bowelLogs: bowelLogs
        )
        pdfExportStartDate = range.lowerBound
        pdfExportEndDate = range.upperBound
    }

    private func exportNutritionPDF() {
        guard !isExportingPDF else { return }
        let dayCount = pdfExportDayCount
        isExportingPDF = true
        pdfExportProgressText = "正在准备 \(dayCount) 天报告"
        bannerCenter.show(title: "正在导出 PDF", message: "正在生成 \(dayCount) 天营养报告。", tone: .success)

        Task { @MainActor in
            do {
                try? await Task.sleep(for: .milliseconds(120))
                pdfExportProgressText = "正在生成 PDF，范围 \(dayCount) 天"
                let dateRange = pdfExportStartDate...pdfExportEndDate
                pdfExportProgressText = "正在写入文件"
                let url = try SettingsDataCoordinator.exportNutritionPDF(
                    settings: currentSettings,
                    nutritionGoals: nutritionGoals,
                    meals: allMeals,
                    waterLogs: allWaterLogs,
                    workouts: workouts,
                    bodyMeasurements: bodyMeasurements,
                    bowelLogs: bowelLogs,
                    dateRange: dateRange
                )
                isShowingPDFExportSheet = false
                shareItem = ShareSheetItem(url: url)
                bannerCenter.show(title: "PDF 导出完成", message: "报告已准备好，可以分享或存储。", tone: .success)
            } catch {
                bannerCenter.show(title: "PDF 导出失败", message: error.localizedDescription, tone: .error)
            }
            isExportingPDF = false
            pdfExportProgressText = ""
        }
    }

    private var pdfExportDayCount: Int {
        SettingsDataCoordinator.dayCount(for: pdfExportStartDate...pdfExportEndDate)
    }

    private func exportJSON() {
        bannerCenter.show(title: "正在导出 JSON", message: "完整备份包含照片时可能需要稍等。", tone: .success)
        Task { @MainActor in
            do {
                try? await Task.sleep(for: .milliseconds(120))
                let url = try SettingsDataCoordinator.exportJSON(
                    settings: currentSettings,
                    nutritionGoals: nutritionGoals,
                    meals: allMeals,
                    waterLogs: allWaterLogs,
                    habits: habits,
                    journalEntries: journalEntries,
                    workouts: workouts,
                    bodyMeasurements: bodyMeasurements,
                    bowelLogs: bowelLogs,
                    userFoods: userFoods,
                    mealTemplates: mealTemplates,
                    chatMessages: chatMessages,
                    supplementRecords: supplementRecords,
                    drinkRecords: drinkRecords
                )
                shareItem = ShareSheetItem(url: url)
            } catch {
                bannerCenter.show(title: "JSON 导出失败", message: error.localizedDescription, tone: .error)
            }
        }
    }

    private func importJSON(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let summary = try SettingsDataCoordinator.importJSON(from: url, into: modelContext, existingSettings: currentSettings)
            HapticEngine.success()
            bannerCenter.show(title: "导入完成", message: summary.detailText, tone: .success)
            LegacyDrinkTemplateMigrator.migrate(in: modelContext)
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "导入失败", message: "原有数据保持不变。\(error.localizedDescription)", tone: .error)
        }
    }

    private func clearAllData() {
        do {
            let summary = try SettingsDataCoordinator.clearAllData(modelContext: modelContext, currentSettings: currentSettings)
            HapticEngine.success()
            bannerCenter.show(title: "数据已清空", message: summary.detailText, tone: .success)
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "清空失败", message: error.localizedDescription, tone: .error)
        }
    }
}

private struct MealLibraryHubView: View {
    @Query(sort: [SortDescriptor(\UserFood.useCount, order: .reverse), SortDescriptor(\UserFood.updatedAt, order: .reverse)])
    private var userFoods: [UserFood]
    @Query(sort: [SortDescriptor(\MealTemplate.useCount, order: .reverse), SortDescriptor(\MealTemplate.updatedAt, order: .reverse)])
    private var mealTemplates: [MealTemplate]

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var filter: MealLibraryFilter = .all
    @State private var expandedFoodBrandKeys: Set<String> = []
    @State private var editingFood: UserFood?

    private var mealOnlyTemplates: [MealTemplate] {
        mealTemplates.filter { TemplateLibraryCategory.meal.matches($0) }
    }

    private var normalizedSearchText: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredFoods: [UserFood] {
        guard filter.includesFoods else { return [] }
        guard !normalizedSearchText.isEmpty else { return userFoods }
        return userFoods.filter { food in
            food.name.localizedCaseInsensitiveContains(normalizedSearchText)
                || food.defaultUnit.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    private var filteredTemplates: [MealTemplate] {
        guard filter.includesTemplates else { return [] }
        guard !normalizedSearchText.isEmpty else { return mealOnlyTemplates }
        return mealOnlyTemplates.filter { template in
            template.name.localizedCaseInsensitiveContains(normalizedSearchText)
                || template.mealType.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
                || template.foodItems.contains { item in
                    item.name.localizedCaseInsensitiveContains(normalizedSearchText)
                        || item.unit.localizedCaseInsensitiveContains(normalizedSearchText)
                }
        }
    }

    private func foodBrandGroups(from foods: [UserFood]) -> [(brand: String, foods: [UserFood])] {
        Dictionary(grouping: foods) { food in
            let brand = food.brand.trimmingCharacters(in: .whitespacesAndNewlines)
            return brand.isEmpty ? "未标品牌" : brand
        }
        .map { (brand: $0.key, foods: $0.value.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) }
        .sorted { $0.brand.localizedCompare($1.brand) == .orderedAscending }
    }

    var body: some View {
        let visibleFoods = filteredFoods
        let visibleTemplates = filteredTemplates
        let visibleFoodGroups = foodBrandGroups(from: visibleFoods)
        let libraryIsEmpty = userFoods.isEmpty && mealOnlyTemplates.isEmpty
        let hasVisibleSearchResults = !visibleFoods.isEmpty || !visibleTemplates.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "食物库",
                    title: "餐食库",
                    detail: "\(userFoods.count) 条餐食记录 · \(mealOnlyTemplates.count) 个餐食模板"
                )

                Picker("餐食资料类型", selection: $filter) {
                    ForEach(MealLibraryFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if !libraryIsEmpty {
                    TextField("搜索食物、模板或食材", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }

                if libraryIsEmpty {
                    AppEmptyStateView(
                        icon: "fork.knife",
                        title: "餐食库还是空的",
                        subtitle: "可以先添加餐食记录，或单独创建餐食模板。"
                    )
                } else if !hasVisibleSearchResults {
                    AppEmptyStateView(
                        icon: "magnifyingglass",
                        title: "没有匹配条目",
                        subtitle: "换一个食物名、模板名或食材关键词试试。"
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(visibleFoodGroups, id: \.brand) { group in
                            let isExpanded = expandedFoodBrandKeys.contains(group.brand)
                            VStack(spacing: 8) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isExpanded { expandedFoodBrandKeys.remove(group.brand) }
                                        else { expandedFoodBrandKeys.insert(group.brand) }
                                    }
                                } label: {
                                    MealLibraryFoodBrandHeader(
                                        brand: group.brand,
                                        count: group.foods.count,
                                        isExpanded: isExpanded
                                    )
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    ForEach(group.foods) { food in
                                        Button {
                                            editingFood = food
                                        } label: {
                                            MealLibraryFoodPreviewRow(food: food)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 12)
                                }
                            }
                        }

                        ForEach(visibleTemplates) { template in
                            NavigationLink {
                                MealTemplateListView(
                                    initialCategory: .meal,
                                    fixedCategory: true,
                                    pageEyebrow: "食物库",
                                    pageTitle: "餐食模板"
                                )
                            } label: {
                                MealLibraryTemplatePreviewRow(template: template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SystemPanel(title: "完整管理", detail: "沿用现有编辑、删除和新增流程") {
                    NavigationLink {
                        UserFoodListView()
                    } label: {
                        AppSettingsRow(
                            icon: "heart.fill",
                            title: "餐食记录",
                            subtitle: "保存单品和已确认营养条目",
                            value: "\(userFoods.count) 个",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    SystemPanelDivider()

                    NavigationLink {
                        MealTemplateListView(
                            initialCategory: .meal,
                            fixedCategory: true,
                            pageEyebrow: "食物库",
                            pageTitle: "餐食模板"
                        )
                    } label: {
                        AppSettingsRow(
                            icon: "doc.on.doc.fill",
                            title: "餐食模板",
                            subtitle: "保存组合餐、固定搭配和常用菜单",
                            value: "\(mealOnlyTemplates.count) 个",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                SystemPanel(title: "职责说明", detail: "餐食库只管理已确认资料") {
                    Text("餐食营养识别会作为插件入口独立存在；识别结果经你确认后，再保存到餐食库。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle("餐食库")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: searchText) {
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            debouncedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .sheet(item: $editingFood) { food in
            UserFoodEditorView(food: food)
        }
    }
}

private enum MealLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case foods
    case templates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .foods: return "食物"
        case .templates: return "模板"
        }
    }

    var includesFoods: Bool {
        switch self {
        case .all, .foods: return true
        case .templates: return false
        }
    }

    var includesTemplates: Bool {
        switch self {
        case .all, .templates: return true
        case .foods: return false
        }
    }
}

private struct MealLibraryFoodPreviewRow: View {
    let food: UserFood
    private var caloriesPerServing: Double {
        food.servingNutrition["calories"] ?? food.caloriesPer100g
    }

    var body: some View {
        HStack(spacing: 12) {
            mealLibraryIcon("fork.knife", color: FamilyUI.ink)

            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1...2)
                Text("\(Int(caloriesPerServing)) kcal / 份 · 默认 \(food.defaultAmount.nutritionDecimal)\(food.defaultUnit)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1...2)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Text("食物")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

private struct MealLibraryFoodBrandHeader: View {
    let brand: String
    let count: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            mealLibraryIcon("building.2.fill", color: FamilyUI.ink)

            VStack(alignment: .leading, spacing: 3) {
                Text(brand)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("\(count) 条餐食记录")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

private struct MealLibraryTemplatePreviewRow: View {
    let template: MealTemplate

    var body: some View {
        HStack(spacing: 12) {
            mealLibraryIcon("doc.on.doc.fill", color: FamilyUI.ink)

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1...2)
                Text("\(Int(template.totalCalories)) kcal · \(template.foodItems.count) 个食材 · \(template.mealType.displayName)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1...2)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Text("模板")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

@ViewBuilder
private func mealLibraryIcon(_ systemName: String, color: Color) -> some View {
    Rectangle()
        .fill(FamilyUI.panelMutedBackground)
        .overlay(
            Rectangle()
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
        .overlay(
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        )
}
