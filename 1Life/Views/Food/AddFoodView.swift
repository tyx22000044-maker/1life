import SwiftUI
import SwiftData

struct AddMealSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mealType: MealType
    let date: Date

    @State private var meal: Meal?
    @State private var isShowingAddFood = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "MEAL ENTRY",
                        title: "添加\(mealType.displayName)",
                        detail: date.dayDisplay
                    )

                    if let meal, let items = meal.foodItems, !items.isEmpty {
                        SystemPanel(title: "食物明细", detail: "当前餐次已添加的食物记录") {
                            ForEach(items.sorted(by: { $0.createdAt < $1.createdAt })) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(item.amount.nutritionDecimal)\(item.unit)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(item.calories)) kcal")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(FamilyUI.accent)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 4)
                            }

                            Button {
                                isShowingAddFood = true
                            } label: {
                                Label("继续添加食物", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(FamilyUI.buttonBackground)
                                    .foregroundStyle(FamilyUI.buttonForeground)
                                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                            }
                        }
                    } else {
                        SystemPanel(title: "空餐次", detail: "先添加第一条食物记录") {
                            AppEmptyStateView(
                                icon: "fork.knife",
                                title: "添加食物到这餐",
                                subtitle: "手动输入食物和营养数据，后续可以复用到常用食物。",
                                buttonTitle: "添加食物"
                            ) {
                                isShowingAddFood = true
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.pageBottom)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("添加\(mealType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isShowingAddFood = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("添加这个食物")
                    }
                }
            }
            .onAppear {
                if meal == nil {
                    let newMeal = Meal(date: date, mealType: mealType)
                    modelContext.insert(newMeal)
                    meal = newMeal
                }
            }
            .sheet(isPresented: $isShowingAddFood) {
                if let meal {
                    AddFoodSheet(meal: meal)
                }
            }
        }
    }
}

struct AddFoodSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\UserFood.useCount, order: .reverse)])
    private var userFoods: [UserFood]
    let meal: Meal

    @State private var name = ""
    @State private var amountText = ""
    @State private var unit = "g"
    @State private var servingGramsText = ""
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
    @State private var saveToUserFood = false
    @State private var searchResults: [FoodSearchResult] = []
    @State private var selectedSource: FoodSource = .manual

    private let units = ["g", "ml", "份", "个", "杯", "碗", "片", "块"]

    private var canSave: Bool {
        !name.isEmpty && !caloriesText.isEmpty && Double(caloriesText) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "FOOD ITEM",
                        title: "添加食物",
                        detail: "\(meal.mealType.displayName) / \(meal.date.timeDisplay)"
                    )

                    basicInfoPanel
                    nutritionPanel
                    extendedNutritionPanel
                    saveOptionsPanel
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.pageBottom)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("添加食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var basicInfoPanel: some View {
        SystemPanel(title: "食物信息", detail: "搜索常用食物，或手动输入名称与份量") {
            TextField("搜索食物或输入名称", text: $name)
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
                .onChange(of: name) { _, newValue in
                    searchFood(newValue)
                }

            if !searchResults.isEmpty && !name.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults.prefix(5)) { result in
                        Button {
                            applySearchResult(result)
                        } label: {
                            HStack(spacing: 10) {
                                if result.isUserFood {
                                    SystemStatusBadge(text: "我的", tone: .accent)
                                }
                                if result.isEstimate {
                                    SystemStatusBadge(text: "估算", tone: .warning)
                                }
                                Text(result.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(result.caloriesPerServing)) kcal/\(result.defaultUnit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            SystemPanelDivider()

            HStack(spacing: 12) {
                TextField("份量", text: $amountText)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))

                Picker("单位", selection: $unit) {
                    ForEach(units, id: \.self) { u in
                        Text(u).tag(u)
                    }
                }
                .pickerStyle(.menu)
                .tint(FamilyUI.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }

            if unit != "g" && unit != "ml" {
                HStack(spacing: 10) {
                    Text("1\(unit) =")
                        .font(.subheadline.weight(.semibold))
                    TextField("克数", text: $servingGramsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    Text("g")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var nutritionPanel: some View {
        SystemPanel(title: "核心营养", detail: "热量与三大营养素") {
            NutritionField(label: "热量", text: $caloriesText, unit: "kcal")
            SystemPanelDivider()
            NutritionField(label: "蛋白质", text: $proteinText, unit: "g")
            SystemPanelDivider()
            NutritionField(label: "碳水化合物", text: $carbsText, unit: "g")
            SystemPanelDivider()
            NutritionField(label: "脂肪", text: $fatText, unit: "g")
        }
    }

    private var extendedNutritionPanel: some View {
        SystemPanel(title: "扩展营养", detail: "可选填写，用于更完整的营养分析") {
            NutritionField(label: "膳食纤维", text: $fiberText, unit: "g")
            SystemPanelDivider()
            NutritionField(label: "钠", text: $sodiumText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "糖", text: $sugarText, unit: "g")
            SystemPanelDivider()
            NutritionField(label: "胆固醇", text: $cholesterolText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "咖啡因", text: $caffeineText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "茶多酚", text: $teaPolyphenolsText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "钙", text: $calciumText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "镁", text: $magnesiumText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "钾", text: $potassiumText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "铁", text: $ironText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "锌", text: $zincText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "维生素 A", text: $vitaminAText, unit: "ug")
            SystemPanelDivider()
            NutritionField(label: "维生素 C", text: $vitaminCText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "维生素 D", text: $vitaminDText, unit: "ug")
            SystemPanelDivider()
            NutritionField(label: "维生素 E", text: $vitaminEText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "维生素 B1", text: $vitaminB1Text, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "维生素 B2", text: $vitaminB2Text, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "烟酸", text: $niacinText, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "维生素 B6", text: $vitaminB6Text, unit: "mg")
            SystemPanelDivider()
            NutritionField(label: "叶酸", text: $folateText, unit: "ug")
            SystemPanelDivider()
            NutritionField(label: "维生素 B12", text: $vitaminB12Text, unit: "ug")
        }
    }

    private var saveOptionsPanel: some View {
        SystemPanel(title: "保存选项", detail: "保存后会加入当前餐次") {
            Toggle(isOn: $saveToUserFood) {
                AppSettingsRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "收藏到我的食物",
                    subtitle: "下次输入时可以直接复用这条营养数据"
                )
            }
            .tint(FamilyUI.accent)
        }
    }

    private func save() {
        let amount = Double(amountText) ?? 1
        let servingGrams: Double
        if unit == "g" {
            servingGrams = amount
        } else if unit == "ml" {
            servingGrams = amount
        } else {
            servingGrams = Double(servingGramsText) ?? 100
        }

        let item = FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            unit: unit,
            servingGrams: servingGrams,
            calories: Double(caloriesText) ?? 0,
            protein: Double(proteinText),
            carbs: Double(carbsText),
            fat: Double(fatText),
            fiber: Double(fiberText),
            sodium: Double(sodiumText),
            sugar: Double(sugarText),
            cholesterol: Double(cholesterolText),
            caffeine: Double(caffeineText),
            teaPolyphenols: Double(teaPolyphenolsText),
            calcium: Double(calciumText),
            magnesium: Double(magnesiumText),
            potassium: Double(potassiumText),
            iron: Double(ironText),
            zinc: Double(zincText),
            vitaminA: Double(vitaminAText),
            vitaminC: Double(vitaminCText),
            vitaminD: Double(vitaminDText),
            vitaminE: Double(vitaminEText),
            vitaminB1: Double(vitaminB1Text),
            vitaminB2: Double(vitaminB2Text),
            niacin: Double(niacinText),
            vitaminB6: Double(vitaminB6Text),
            folate: Double(folateText),
            vitaminB12: Double(vitaminB12Text),
            nutritionDataNote: nil,
            source: selectedSource
        )
        item.meal = meal
        modelContext.insert(item)

        if saveToUserFood {
            let uf = UserFood(
                name: name.trimmingCharacters(in: .whitespaces),
                defaultAmount: amount,
                defaultUnit: unit,
                defaultServingGrams: servingGrams,
                caloriesPer100g: servingGrams > 0 ? (Double(caloriesText) ?? 0) * 100 / servingGrams : 0,
                proteinPer100g: Double(proteinText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                carbsPer100g: Double(carbsText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                fatPer100g: Double(fatText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                fiberPer100g: Double(fiberText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                sodiumPer100g: Double(sodiumText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                sugarPer100g: Double(sugarText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                cholesterolPer100g: Double(cholesterolText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                caffeinePer100g: Double(caffeineText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                teaPolyphenolsPer100g: Double(teaPolyphenolsText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                calciumPer100g: Double(calciumText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                magnesiumPer100g: Double(magnesiumText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                potassiumPer100g: Double(potassiumText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                ironPer100g: Double(ironText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                zincPer100g: Double(zincText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminAPer100g: Double(vitaminAText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminCPer100g: Double(vitaminCText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminDPer100g: Double(vitaminDText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminEPer100g: Double(vitaminEText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminB1Per100g: Double(vitaminB1Text).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminB2Per100g: Double(vitaminB2Text).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                niacinPer100g: Double(niacinText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminB6Per100g: Double(vitaminB6Text).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                folatePer100g: Double(folateText).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 },
                vitaminB12Per100g: Double(vitaminB12Text).map { servingGrams > 0 ? $0 * 100 / servingGrams : 0 }
            )
            modelContext.insert(uf)
        }

        HapticEngine.success()
        dismiss()
    }

    private func searchFood(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResults = []; return }

        var results: [FoodSearchResult] = []

        for uf in userFoods where uf.name.localizedCaseInsensitiveContains(q) {
            let calPerServing = uf.caloriesPer100g * uf.defaultServingGrams / 100
            results.append(FoodSearchResult(
                id: uf.id, name: uf.name, defaultAmount: uf.defaultAmount,
                defaultUnit: uf.defaultUnit, defaultServingGrams: uf.defaultServingGrams,
                caloriesPerServing: calPerServing,
                proteinPerServing: uf.proteinPer100g.map { $0 * uf.defaultServingGrams / 100 },
                carbsPerServing: uf.carbsPer100g.map { $0 * uf.defaultServingGrams / 100 },
                fatPerServing: uf.fatPer100g.map { $0 * uf.defaultServingGrams / 100 },
                fiberPerServing: uf.fiberPer100g.map { $0 * uf.defaultServingGrams / 100 },
                sodiumPerServing: uf.sodiumPer100g.map { $0 * uf.defaultServingGrams / 100 },
                sugarPerServing: uf.sugarPer100g.map { $0 * uf.defaultServingGrams / 100 },
                cholesterolPerServing: uf.cholesterolPer100g.map { $0 * uf.defaultServingGrams / 100 },
                caffeinePerServing: uf.caffeinePer100g.map { $0 * uf.defaultServingGrams / 100 },
                teaPolyphenolsPerServing: uf.teaPolyphenolsPer100g.map { $0 * uf.defaultServingGrams / 100 },
                calciumPerServing: uf.calciumPer100g.map { $0 * uf.defaultServingGrams / 100 },
                magnesiumPerServing: uf.magnesiumPer100g.map { $0 * uf.defaultServingGrams / 100 },
                potassiumPerServing: uf.potassiumPer100g.map { $0 * uf.defaultServingGrams / 100 },
                ironPerServing: uf.ironPer100g.map { $0 * uf.defaultServingGrams / 100 },
                zincPerServing: uf.zincPer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminAPerServing: uf.vitaminAPer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminCPerServing: uf.vitaminCPer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminDPerServing: uf.vitaminDPer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminEPerServing: uf.vitaminEPer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminB1PerServing: uf.vitaminB1Per100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminB2PerServing: uf.vitaminB2Per100g.map { $0 * uf.defaultServingGrams / 100 },
                niacinPerServing: uf.niacinPer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminB6PerServing: uf.vitaminB6Per100g.map { $0 * uf.defaultServingGrams / 100 },
                folatePerServing: uf.folatePer100g.map { $0 * uf.defaultServingGrams / 100 },
                vitaminB12PerServing: uf.vitaminB12Per100g.map { $0 * uf.defaultServingGrams / 100 },
                nutritionDataNote: nil,
                isUserFood: true, isEstimate: false
            ))
        }

        searchResults = results
    }

    private func applySearchResult(_ result: FoodSearchResult) {
        name = result.name
        amountText = result.defaultAmount.nutritionDecimal
        unit = result.defaultUnit
        servingGramsText = "\(Int(result.defaultServingGrams))"
        caloriesText = "\(Int(result.caloriesPerServing))"
        if let p = result.proteinPerServing { proteinText = "\(Int(p))" }
        if let c = result.carbsPerServing { carbsText = "\(Int(c))" }
        if let f = result.fatPerServing { fatText = "\(Int(f))" }
        if let v = result.fiberPerServing { fiberText = v.nutritionDecimal }
        if let v = result.sodiumPerServing { sodiumText = v.nutritionDecimal }
        if let v = result.sugarPerServing { sugarText = v.nutritionDecimal }
        if let v = result.cholesterolPerServing { cholesterolText = v.nutritionDecimal }
        if let v = result.caffeinePerServing { caffeineText = v.nutritionDecimal }
        if let v = result.teaPolyphenolsPerServing { teaPolyphenolsText = v.nutritionDecimal }
        if let v = result.calciumPerServing { calciumText = v.nutritionDecimal }
        if let v = result.magnesiumPerServing { magnesiumText = v.nutritionDecimal }
        if let v = result.potassiumPerServing { potassiumText = v.nutritionDecimal }
        if let v = result.ironPerServing { ironText = v.nutritionDecimal }
        if let v = result.zincPerServing { zincText = v.nutritionDecimal }
        if let v = result.vitaminAPerServing { vitaminAText = v.nutritionDecimal }
        if let v = result.vitaminCPerServing { vitaminCText = v.nutritionDecimal }
        if let v = result.vitaminDPerServing { vitaminDText = v.nutritionDecimal }
        if let v = result.vitaminEPerServing { vitaminEText = v.nutritionDecimal }
        if let v = result.vitaminB1PerServing { vitaminB1Text = v.nutritionDecimal }
        if let v = result.vitaminB2PerServing { vitaminB2Text = v.nutritionDecimal }
        if let v = result.niacinPerServing { niacinText = v.nutritionDecimal }
        if let v = result.vitaminB6PerServing { vitaminB6Text = v.nutritionDecimal }
        if let v = result.folatePerServing { folateText = v.nutritionDecimal }
        if let v = result.vitaminB12PerServing { vitaminB12Text = v.nutritionDecimal }
        selectedSource = .manual
        searchResults = []
        HapticEngine.tap()
    }
}

struct FoodSearchResult: Identifiable {
    let id: UUID
    let name: String
    let defaultAmount: Double
    let defaultUnit: String
    let defaultServingGrams: Double
    let caloriesPerServing: Double
    let proteinPerServing: Double?
    let carbsPerServing: Double?
    let fatPerServing: Double?
    let fiberPerServing: Double?
    let sodiumPerServing: Double?
    let sugarPerServing: Double?
    let cholesterolPerServing: Double?
    let caffeinePerServing: Double?
    var teaPolyphenolsPerServing: Double? = nil
    let calciumPerServing: Double?
    let magnesiumPerServing: Double?
    let potassiumPerServing: Double?
    let ironPerServing: Double?
    let zincPerServing: Double?
    let vitaminAPerServing: Double?
    let vitaminCPerServing: Double?
    let vitaminDPerServing: Double?
    let vitaminEPerServing: Double?
    let vitaminB1PerServing: Double?
    let vitaminB2PerServing: Double?
    let niacinPerServing: Double?
    let vitaminB6PerServing: Double?
    let folatePerServing: Double?
    let vitaminB12PerServing: Double?
    let nutritionDataNote: String?
    let isUserFood: Bool
    let isEstimate: Bool
}

private struct NutritionField: View {
    let label: String
    @Binding var text: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: 92)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            Text(unit)
                .foregroundStyle(.secondary)
                .font(.caption.weight(.semibold))
                .frame(width: 36, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}
