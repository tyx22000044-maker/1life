import SwiftUI
import SwiftData

private struct FoodDaySnapshot {
    let meals: [Meal]
    let items: [FoodItem]
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let totalSodium: Double
    let totalSugar: Double

    init(meals: [Meal]) {
        self.meals = meals

        var items: [FoodItem] = []
        items.reserveCapacity(meals.reduce(0) { $0 + ($1.foodItems?.count ?? 0) })
        for meal in meals {
            items.append(contentsOf: meal.foodItems ?? [])
        }
        self.items = items

        var totalCalories = 0.0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var totalSodium = 0.0
        var totalSugar = 0.0

        for item in items {
            totalCalories += item.calories
            totalProtein += item.protein ?? 0
            totalCarbs += item.carbs ?? 0
            totalFat += item.fat ?? 0
            totalSodium += item.sodium ?? 0
            totalSugar += item.sugar ?? 0
        }

        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.totalSodium = totalSodium
        self.totalSugar = totalSugar
    }
}

private struct FoodHistorySearchResults {
    let historicalItems: [FoodItem]
    let favoriteFoods: [UserFood]

    var isEmpty: Bool { historicalItems.isEmpty && favoriteFoods.isEmpty }
}

struct FoodTimelineView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allMeals: [Meal]
    @Query(sort: [SortDescriptor(\NutritionGoal.effectiveDate, order: .reverse)])
    private var nutritionGoals: [NutritionGoal]
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\MealTemplate.useCount, order: .reverse), SortDescriptor(\MealTemplate.updatedAt, order: .reverse)])
    private var mealTemplates: [MealTemplate]
    @Query(sort: [SortDescriptor(\DrinkRecord.brand), SortDescriptor(\DrinkRecord.productName)])
    private var drinkRecords: [DrinkRecord]
    @Query(sort: [SortDescriptor(\UserFood.useCount, order: .reverse), SortDescriptor(\UserFood.updatedAt, order: .reverse)])
    private var userFoods: [UserFood]

    @State private var isShowingAddMeal = false
    @State private var isShowingTemplates = false
    @State private var isShowingBatchAdd = false
    @State private var selectedMealType: MealType = .lunch
    @State private var dashboardFoodFocusMealType: MealType?
    @State private var templateImportMealTypeOverride: MealType?
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var healthTDEE: Double?
    @State private var isPreparingDay = false
    @State private var bannerCenter = GlobalBannerCenter.shared

    private var selectedDate: Date { appViewModel.selectedDate }
    private var currentSettings: UserSettings? { settings.first }
    private var currentGoal: NutritionGoal? { nutritionGoals.first }
    private var mealLibraryTemplates: [MealTemplate] {
        mealTemplates.filter { TemplateLibraryCategory.meal.matches($0) }
    }

    private var effectiveCalorieTarget: Double {
        (currentSettings?.effectiveTarget(healthTDEE: healthTDEE, goal: currentGoal)
            ?? EffectiveNutritionTarget.fallback).calories
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { appViewModel.selectedDate },
            set: { appViewModel.selectedDate = min($0, Date.now) }
        )
    }

    private var dayMeals: [Meal] {
        allMeals
            .filter { $0.date.isSameDay(as: selectedDate) }
            .sorted { a, b in
                if a.mealTypeSortOrder != b.mealTypeSortOrder {
                    return a.mealTypeSortOrder < b.mealTypeSortOrder
                }
                return a.createdAt < b.createdAt
            }
    }

    private var effectiveTarget: EffectiveNutritionTarget {
        currentSettings?.effectiveTarget(healthTDEE: healthTDEE, goal: currentGoal)
            ?? EffectiveNutritionTarget.fallback
    }

    private func filteredMeals(from meals: [Meal]) -> [Meal] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return meals }
        return meals.filter { meal in
            meal.mealType.displayName.localizedCaseInsensitiveContains(query)
            || (meal.foodItems ?? []).contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    private var recentFoodItems: [FoodItem] {
        var seen: Set<String> = []
        let sortedItems = allMeals
            .filter { !$0.date.isSameDay(as: selectedDate) }
            .sorted { $0.date > $1.date }
            .flatMap { ($0.foodItems ?? []).sorted { $0.createdAt > $1.createdAt } }

        return sortedItems.compactMap { item in
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else { return nil }
            seen.insert(key)
            return item
        }
        .prefix(8)
        .map { $0 }
    }

    private var yesterdayMeals: [Meal] {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return [] }
        return allMeals
            .filter { $0.date.isSameDay(as: yesterday) && !(($0.foodItems ?? []).isEmpty) }
            .sorted { $0.mealTypeSortOrder < $1.mealTypeSortOrder }
    }

    private var historySearchResults: FoodHistorySearchResults {
        let query = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return FoodHistorySearchResults(historicalItems: [], favoriteFoods: []) }
        var seen: Set<String> = []
        let historicalItems = allMeals
            .sorted { $0.date > $1.date }
            .flatMap { $0.foodItems ?? [] }
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .compactMap { item -> FoodItem? in
                let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty, !seen.contains(key) else { return nil }
                seen.insert(key)
                return item
            }
            .prefix(6)
            .map { $0 }

        let favoriteFoods = Array(userFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(6))
        return FoodHistorySearchResults(historicalItems: historicalItems, favoriteFoods: favoriteFoods)
    }

    var body: some View {
        let daySnapshot = FoodDaySnapshot(meals: dayMeals)
        let visibleMeals = filteredMeals(from: daySnapshot.meals)
        let historySearch = historySearchResults
        let recentItems = recentFoodItems

        NavigationStack {
            ScrollViewReader { scrollProxy in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            dayControlPanel
                            inlineSearchBar
                            summaryPanel(snapshot: daySnapshot)
                            quickActionsPanel(recentItems: recentItems)
                            macroSummaryPanel(snapshot: daySnapshot)
                            todayDietSummaryPanel(snapshot: daySnapshot)
                            if !searchText.isEmpty && !historySearch.isEmpty {
                                historySearchPanel(results: historySearch)
                            }

                            if isPreparingDay {
                                loadingPanel
                            } else if daySnapshot.meals.isEmpty && searchText.isEmpty {
                                emptyState
                            } else if visibleMeals.isEmpty {
                                noSearchResultPanel
                            } else {
                                mealList(meals: visibleMeals)
                            }
                        }
                        .padding(.horizontal, AppSpacing.pageHorizontal)
                        .padding(.top, 0)
                        .padding(.bottom, 96)
                    }
                    .scrollIndicators(.hidden)

                    bottomBar(snapshot: daySnapshot)
                }
                .navigationTitle("饮食")
                .navigationBarTitleDisplayMode(.inline)
                .background(FamilyUI.pageBackground)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            startTemplateImport()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .disabled(mealLibraryTemplates.isEmpty && userFoods.isEmpty && drinkRecords.isEmpty)
                        .accessibilityLabel("从模板库创建")
                    }
                }
                .sheet(isPresented: $isShowingAddMeal, onDismiss: cleanupEmptyMeals) {
                    AddMealSheet(mealType: selectedMealType, date: selectedDate)
                }
                .sheet(isPresented: $isShowingTemplates, onDismiss: resetTemplateImportFocus) {
                    TemplatePickerView(
                        templates: mealLibraryTemplates,
                        userFoods: userFoods,
                        drinkRecords: drinkRecords,
                        selectedDate: selectedDate,
                        onSelectUserFood: { food in
                            addUserFood(food, mealType: consumeTemplateMealTypeOverride() ?? guessMealType())
                        },
                        onSelectDrink: { record in
                            createDrinkMeal(from: record)
                        }
                    ) { template in
                        createMeal(from: template)
                    }
                }
                .sheet(isPresented: $isShowingBatchAdd) {
                    BatchFoodAddSheet(
                        userFoods: Array(userFoods.prefix(24)),
                        recentItems: recentItems,
                        mealType: guessMealType()
                    ) { userFoodIDs, recentItemIDs in
                        addBatchFoods(userFoodIDs: userFoodIDs, recentItemIDs: recentItemIDs)
                    }
                }
                .task(id: selectedDate) {
                    await prepareDayChange()
                    await refreshHealthTDEE()
                }
                .onAppear {
                    applyPendingFoodFocus(scrollProxy: scrollProxy)
                }
                .onChange(of: appViewModel.foodScrollMealType) { _, _ in
                    applyPendingFoodFocus(scrollProxy: scrollProxy)
                }
            }
        }
    }

    private var dayControlPanel: some View {
        SystemPanel(title: "日期选择", detail: "查看不同日期的餐食流水") {
            DaySelectorView(selectedDate: selectedDateBinding)
        }
    }

    private var inlineSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("搜索当天食物、餐次或历史食物", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline.weight(.semibold))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticEngine.tap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(FamilyUI.panelMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .task(id: searchText) {
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            debouncedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func summaryPanel(snapshot: FoodDaySnapshot) -> some View {
        let progress = effectiveCalorieTarget > 0 ? snapshot.totalCalories / effectiveCalorieTarget : 0
        let remaining = Int((effectiveCalorieTarget - snapshot.totalCalories).rounded())

        return SystemPanel(title: "今日摄入", detail: "当天餐食总热量与记录数量") {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("总摄入")
                        .font(FamilyTypography.text(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(snapshot.totalCalories))")
                        .font(FamilyTypography.hero)
                        .monospacedDigit()
                    Text("/ \(Int(effectiveCalorieTarget)) kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    SystemStatusBadge(
                        text: remaining >= 0 ? "剩余 \(remaining)" : "超出 \(abs(remaining))",
                        tone: remaining >= 0 ? .accent : .danger
                    )
                    SystemStatusBadge(text: "\(snapshot.meals.count) 餐", tone: .neutral)
                }
            }

            ProgressView(value: min(max(progress, 0), 1))
                .tint(progress > 1 ? FamilyUI.danger : FamilyUI.accent)
        }
    }

    private func quickActionsPanel(recentItems: [FoodItem]) -> some View {
        SystemPanel(title: "快捷记录", detail: "复用最近食物、模板库或昨天同餐") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                quickActionButton("拍照识别", icon: "camera.fill") {
                    HapticEngine.tap()
                    appViewModel.selectedTab = .ai
                }
                quickActionButton("手动添加", icon: "plus") {
                    HapticEngine.tap()
                    selectedMealType = dashboardFoodFocusMealType ?? guessMealType()
                    isShowingAddMeal = true
                }
                quickActionButton("批量添加", icon: "checklist") {
                    guard !userFoods.isEmpty || !recentItems.isEmpty else {
                        bannerCenter.show(title: "暂无可批量添加的食物", message: "先保存常用食物或记录几餐后再试。", tone: .warning)
                        return
                    }
                    HapticEngine.tap()
                    isShowingBatchAdd = true
                }
                quickActionButton("模板库", icon: "doc.on.doc") {
                    guard !mealLibraryTemplates.isEmpty || !drinkRecords.isEmpty else {
                        bannerCenter.show(title: "暂无模板", message: "在餐食库创建模板或饮品库保存记录后可以一键复用。", tone: .warning)
                        return
                    }
                    HapticEngine.tap()
                    startTemplateImport()
                }
                Menu {
                    if yesterdayMeals.isEmpty {
                        Button("昨天没有可复制的餐食") {}
                    } else {
                        ForEach(yesterdayMeals) { meal in
                            Button("\(meal.mealType.displayName) · \(Int(meal.totalCalories)) kcal") {
                                copyMeal(meal)
                            }
                        }
                    }
                } label: {
                    quickActionLabel("复制昨天", icon: "clock.arrow.circlepath")
                }
            }

            if !mealLibraryTemplates.isEmpty {
                SystemPanelDivider()
                quickTemplateStrip
            }

            if !userFoods.isEmpty {
                SystemPanelDivider()
                favoriteFoodStrip
            }

            if !recentItems.isEmpty {
                SystemPanelDivider()
                recentFoodStrip(items: recentItems)
            }
        }
    }

    private var quickTemplateStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            foodSectionHeader("模板库", value: "\(min(mealLibraryTemplates.count, 4)) 个")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(mealLibraryTemplates.prefix(4)) { template in
                        Button {
                            createMeal(from: template)
                        } label: {
                            QuickFoodChip(
                                title: template.name,
                                subtitle: "\(template.mealType.displayName) · \(Int(template.totalCalories)) kcal",
                                icon: template.mealType.icon,
                                color: FamilyUI.accent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func recentFoodStrip(items: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            foodSectionHeader("最近吃过", value: "\(items.count) 个")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        Button {
                            addFoodItemCopy(item, mealType: guessMealType())
                        } label: {
                            QuickFoodChip(
                                title: item.name,
                                subtitle: "\(item.amount.nutritionDecimal)\(item.unit) · \(Int(item.calories)) kcal",
                                icon: "clock.fill",
                                color: FamilyUI.accent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var favoriteFoodStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            foodSectionHeader("常用食物", value: "\(min(userFoods.count, 6)) 个")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(userFoods.prefix(6)) { food in
                        Button {
                            addUserFood(food, mealType: guessMealType())
                        } label: {
                            QuickFoodChip(
                                title: food.name,
                                subtitle: "\(food.defaultAmount.nutritionDecimal)\(food.defaultUnit) · \(Int(food.caloriesPer100g * food.defaultServingGrams / 100)) kcal",
                                icon: "heart.fill",
                                color: .pink
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func macroSummaryPanel(snapshot: FoodDaySnapshot) -> some View {
        SystemPanel(title: "营养摘要", detail: "三大营养素、目标差距和风险提醒") {
            HStack(spacing: 12) {
                MacroSummaryTile(title: "蛋白质", value: snapshot.totalProtein, target: effectiveTarget.protein, unit: "g", color: FamilyUI.info)
                MacroSummaryTile(title: "碳水", value: snapshot.totalCarbs, target: effectiveTarget.carbs, unit: "g", color: FamilyUI.success)
                MacroSummaryTile(title: "脂肪", value: snapshot.totalFat, target: effectiveTarget.fat, unit: "g", color: FamilyUI.accent)
            }

            SystemPanelDivider()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                nutritionHint(
                    title: "目标差距",
                    value: calorieGapText(for: snapshot),
                    tone: snapshot.totalCalories > effectiveTarget.calories ? .danger : .accent
                )
                nutritionHint(
                    title: "这一餐可能缺",
                    value: missingNutritionHint(for: snapshot),
                    tone: .neutral
                )
                nutritionHint(
                    title: "钠",
                    value: snapshot.totalSodium > effectiveTarget.sodium ? "偏高" : "\(Int(snapshot.totalSodium)) mg",
                    tone: snapshot.totalSodium > effectiveTarget.sodium ? .warning : .neutral
                )
                nutritionHint(
                    title: "糖",
                    value: snapshot.totalSugar > effectiveTarget.sugar ? "偏高" : "\(Int(snapshot.totalSugar)) g",
                    tone: snapshot.totalSugar > effectiveTarget.sugar ? .warning : .neutral
                )
            }
        }
    }

    private func historySearchPanel(results: FoodHistorySearchResults) -> some View {
        SystemPanel(title: "历史食物", detail: "从常用食物和历史记录中快速添加") {
            if !results.favoriteFoods.isEmpty {
                foodSectionHeader("常用匹配", value: "\(results.favoriteFoods.count) 个")
                ForEach(results.favoriteFoods) { food in
                    Button {
                        addUserFood(food, mealType: guessMealType())
                    } label: {
                        searchQuickAddRow(
                            title: food.name,
                            subtitle: "\(food.defaultAmount.nutritionDecimal)\(food.defaultUnit) · \(Int(food.caloriesPer100g * food.defaultServingGrams / 100)) kcal",
                            icon: "heart.fill",
                            color: .pink
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !results.favoriteFoods.isEmpty && !results.historicalItems.isEmpty {
                SystemPanelDivider()
            }

            if !results.historicalItems.isEmpty {
                foodSectionHeader("历史匹配", value: "\(results.historicalItems.count) 个")
                ForEach(results.historicalItems) { item in
                    Button {
                        addFoodItemCopy(item, mealType: guessMealType())
                    } label: {
                        searchQuickAddRow(
                            title: item.name,
                            subtitle: "\(item.amount.nutritionDecimal)\(item.unit) · \(Int(item.calories)) kcal",
                            icon: "clock.fill",
                            color: FamilyUI.accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func todayDietSummaryPanel(snapshot: FoodDaySnapshot) -> some View {
        SystemPanel(title: "今天饮食小结", detail: "基于当前记录生成的轻量复盘") {
            VStack(alignment: .leading, spacing: 10) {
                Text(todayDietSummaryText(for: snapshot))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                SystemPanelDivider()

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    nutritionHint(title: "记录完整度", value: "\(snapshot.meals.count)/\(MealType.allCases.count) 餐次", tone: snapshot.meals.count >= 3 ? .accent : .neutral)
                    nutritionHint(title: "食物数量", value: "\(snapshot.items.count) 项", tone: snapshot.items.count >= 4 ? .accent : .neutral)
                    nutritionHint(title: "蛋白执行", value: macroRatioText(snapshot.totalProtein, target: effectiveTarget.protein), tone: snapshot.totalProtein >= effectiveTarget.protein * 0.8 ? .accent : .warning)
                    nutritionHint(title: "能量状态", value: calorieGapText(for: snapshot), tone: snapshot.totalCalories > effectiveTarget.calories ? .danger : .accent)
                }
            }
        }
    }

    private func refreshHealthTDEE() async {
        guard currentSettings?.useHealthKitForDynamicTDEE == true else {
            healthTDEE = nil
            return
        }
        let summary = try? await HealthKitService.shared.energySummary(for: selectedDate, settings: currentSettings)
        healthTDEE = summary?.tdeeKcal
        syncDynamicGoalIfNeeded()
    }

    private func prepareDayChange() async {
        searchText = ""
        isPreparingDay = true
        try? await Task.sleep(for: .milliseconds(160))
        isPreparingDay = false
    }

    private func syncDynamicGoalIfNeeded() {
        guard selectedDate.isToday,
              let settings = currentSettings,
              settings.useHealthKitForDynamicTDEE,
              let goal = currentGoal,
              let tdee = healthTDEE else { return }

        let calories = settings.calorieTarget(from: tdee)
        goal.dailyCalories = calories
        goal.updatedAt = .now
    }

    // MARK: - Meal List

    private func mealList(meals: [Meal]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(MealType.allCases) { type in
                let typeMeals = meals.filter { $0.mealType == type }
                if !typeMeals.isEmpty || searchText.isEmpty {
                    MealTypeSection(
                        type: type,
                        meals: typeMeals,
                        onAdd: {
                            selectedMealType = type
                            dashboardFoodFocusMealType = nil
                            isShowingAddMeal = true
                        }
                    )
                    .id(mealSectionScrollID(for: type))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        SystemPanel(title: "暂无记录", detail: "今天还没有餐食流水") {
            AppEmptyStateView(
                icon: "fork.knife",
                title: "还没有记录",
                subtitle: "拍照或手动添加你的第一餐"
            )

            HStack(spacing: 12) {
                Button {
                    HapticEngine.tap()
                    appViewModel.selectedTab = .ai
                } label: {
                    Label("拍照记录", systemImage: "camera.fill")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }

                Button {
                    HapticEngine.tap()
                    selectedMealType = dashboardFoodFocusMealType ?? guessMealType()
                    isShowingAddMeal = true
                } label: {
                    Label("手动添加", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(FamilyUI.panelMutedBackground)
                        .foregroundStyle(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }
        }
    }

    private var noSearchResultPanel: some View {
        SystemPanel(title: "搜索结果", detail: "没有找到匹配的食物或餐次") {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("没有找到 “\(searchText)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var loadingPanel: some View {
        SystemPanel(title: "正在整理", detail: "正在准备当天餐食记录") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(FamilyUI.accent)
                Text("正在载入当天数据")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Bottom Bar

    private func bottomBar(snapshot: FoodDaySnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("当天合计")
                    .font(FamilyTypography.text(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text("\(Int(snapshot.totalCalories)) / \(Int(effectiveCalorieTarget)) kcal")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            Spacer()
            Button {
                HapticEngine.tap()
                selectedMealType = dashboardFoodFocusMealType ?? guessMealType()
                isShowingAddMeal = true
            } label: {
                Label("添加一餐", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func guessMealType() -> MealType {
        .guessByTime()
    }

    private func applyPendingFoodFocus(scrollProxy: ScrollViewProxy? = nil) {
        if let mealType = appViewModel.foodScrollMealType {
            searchText = ""
            selectedMealType = mealType
            dashboardFoodFocusMealType = mealType
            appViewModel.foodScrollMealType = nil
            scrollToMealType(mealType, proxy: scrollProxy)
            return
        }

        guard let mealType = appViewModel.foodFocusMealType else { return }
        selectedMealType = mealType
        dashboardFoodFocusMealType = mealType
        appViewModel.foodFocusMealType = nil
    }

    private func scrollToMealType(_ mealType: MealType, proxy: ScrollViewProxy?) {
        guard let proxy else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.snappy(duration: 0.34)) {
                proxy.scrollTo(mealSectionScrollID(for: mealType), anchor: .top)
            }
        }
    }

    private func mealSectionScrollID(for mealType: MealType) -> String {
        "meal-section-\(mealType.rawValue)"
    }

    private func startTemplateImport() {
        templateImportMealTypeOverride = dashboardFoodFocusMealType ?? selectedMealType
        isShowingTemplates = true
    }

    private func resetTemplateImportFocus() {
        templateImportMealTypeOverride = nil
        dashboardFoodFocusMealType = nil
    }

    private func consumeTemplateMealTypeOverride() -> MealType? {
        let override = templateImportMealTypeOverride ?? dashboardFoodFocusMealType
        templateImportMealTypeOverride = nil
        dashboardFoodFocusMealType = nil
        return override
    }

    private func cleanupEmptyMeals() {
        FoodTimelineMealWriter.cleanupEmptyMeals(dayMeals, modelContext: modelContext)
    }

    private func createMeal(from template: MealTemplate) {
        FoodTimelineMealWriter.createMeal(
            from: template,
            date: mealDateForSelectedDay(),
            mealTypeOverride: consumeTemplateMealTypeOverride(),
            modelContext: modelContext
        )
        HapticEngine.success()
    }

    private func createDrinkMeal(from record: DrinkRecord) {
        FoodTimelineMealWriter.createDrinkMeal(
            from: record,
            date: mealDateForSelectedDay(),
            mealType: consumeTemplateMealTypeOverride() ?? .snack,
            modelContext: modelContext
        )
        DrinkLibraryIndex.shared.invalidate()
        HapticEngine.success()
    }

    private func calorieGapText(for snapshot: FoodDaySnapshot) -> String {
        let gap = Int((effectiveTarget.calories - snapshot.totalCalories).rounded())
        return gap >= 0 ? "还差 \(gap) kcal" : "超出 \(abs(gap)) kcal"
    }

    private func todayDietSummaryText(for snapshot: FoodDaySnapshot) -> String {
        guard snapshot.totalCalories > 0 else {
            return "今天还没有足够的饮食记录。先记录一餐后，这里会生成摄入、宏量营养和风险提示。"
        }
        if snapshot.totalCalories > effectiveTarget.calories * 1.1 {
            return "今天总热量已经高于目标，后续餐次可以优先选择高蛋白、低油和高纤维食物。"
        }
        if snapshot.totalProtein < effectiveTarget.protein * 0.5 {
            return "今天蛋白质记录偏少，可以在下一餐补充鸡蛋、鱼肉、豆制品或酸奶这类食物。"
        }
        if snapshot.totalSodium > effectiveTarget.sodium || snapshot.totalSugar > effectiveTarget.sugar {
            return "今天钠或糖有偏高迹象，后续可以减少酱料、甜饮和加工食品。"
        }
        return "今天饮食整体比较平稳，继续保持餐次记录完整度会让复盘更准确。"
    }

    private func missingNutritionHint(for snapshot: FoodDaySnapshot) -> String {
        guard snapshot.totalCalories > 0 else { return "先记录一餐" }
        let proteinRatio = effectiveTarget.protein > 0 ? snapshot.totalProtein / effectiveTarget.protein : 1
        let carbsRatio = effectiveTarget.carbs > 0 ? snapshot.totalCarbs / effectiveTarget.carbs : 1
        let fatRatio = effectiveTarget.fat > 0 ? snapshot.totalFat / effectiveTarget.fat : 1
        let lowest = [
            ("蛋白质", proteinRatio),
            ("碳水", carbsRatio),
            ("脂肪", fatRatio)
        ].min { $0.1 < $1.1 }
        return lowest?.1 ?? 1 < 0.35 ? (lowest?.0 ?? "均衡") : "整体尚可"
    }

    private func quickActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func quickActionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption.weight(.bold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private func foodSectionHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value, tone: .neutral)
        }
    }

    private func searchQuickAddRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func macroRatioText(_ value: Double, target: Double) -> String {
        guard target > 0 else { return "\(Int(value))g" }
        return "\(Int(value))g / \(Int(value / target * 100))%"
    }

    private func nutritionHint(title: String, value: String, tone: FoodHintTone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(hintColor(tone))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private func hintColor(_ tone: FoodHintTone) -> Color {
        switch tone {
        case .accent:
            return FamilyUI.accent
        case .neutral:
            return .primary
        case .warning:
            return FamilyUI.warning
        case .danger:
            return FamilyUI.danger
        }
    }

    private func copyMeal(_ sourceMeal: Meal) {
        FoodTimelineMealWriter.copyMeal(sourceMeal, date: mealDateForSelectedDay(), modelContext: modelContext)
        HapticEngine.success()
    }

    private func addFoodItemCopy(_ sourceItem: FoodItem, mealType: MealType) {
        FoodTimelineMealWriter.addFoodItemCopy(
            sourceItem,
            mealType: mealType,
            date: mealDateForSelectedDay(),
            existingMeal: existingMeal(for: mealType),
            modelContext: modelContext
        )
        HapticEngine.success()
    }

    private func addUserFood(_ food: UserFood, mealType: MealType) {
        FoodTimelineMealWriter.addUserFood(
            food,
            mealType: mealType,
            date: mealDateForSelectedDay(),
            existingMeal: existingMeal(for: mealType),
            modelContext: modelContext
        )
        HapticEngine.success()
    }

    private func addBatchFoods(userFoodIDs: Set<UUID>, recentItemIDs: Set<UUID>) {
        let targetMealType = guessMealType()
        for food in userFoods where userFoodIDs.contains(food.id) {
            addUserFood(food, mealType: targetMealType)
        }
        for item in recentFoodItems where recentItemIDs.contains(item.id) {
            addFoodItemCopy(item, mealType: targetMealType)
        }
        HapticEngine.success()
    }

    private func existingMeal(for type: MealType) -> Meal? {
        dayMeals.first { $0.mealType == type }
    }

    private func mealDateForSelectedDay() -> Date {
        if selectedDate.isToday { return .now }
        let calendar = Calendar.current
        let current = calendar.dateComponents([.hour, .minute], from: Date.now)
        return calendar.date(bySettingHour: current.hour ?? 12, minute: current.minute ?? 0, second: 0, of: selectedDate) ?? selectedDate
    }
}
