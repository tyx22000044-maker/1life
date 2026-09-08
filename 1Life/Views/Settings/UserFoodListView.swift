import SwiftUI
import SwiftData

struct UserFoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\UserFood.useCount, order: .reverse), SortDescriptor(\UserFood.updatedAt, order: .reverse)])
    private var foods: [UserFood]

    @State private var editingFood: UserFood?
    @State private var isAddingFood = false
    @State private var expandedBrandKeys: Set<String> = []
    @State private var isSelectionMode = false
    @State private var selectedFoodIDs: Set<UUID> = []
    @State private var isShowingBatchBrandEditor = false

    private var brandGroups: [(brand: String, foods: [UserFood])] {
        Dictionary(grouping: foods) { food in
            food.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未标品牌" : food.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .map { (brand: $0.key, foods: $0.value.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) }
        .sorted { $0.brand.localizedCompare($1.brand) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "餐食库",
                    title: "餐食记录",
                    detail: "\(foods.count) 条已确认餐食"
                )

                if foods.isEmpty {
                        SystemPanel(title: "餐食库为空", detail: "保存餐食记录后会显示在这里") {
                        AppEmptyStateView(
                            icon: "heart.fill",
                            title: "还没有餐食记录",
                            subtitle: "把常吃的食物保存到这里，手动记录时会优先显示。"
                        )
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(brandGroups, id: \.brand) { group in
                            let isExpanded = expandedBrandKeys.contains(group.brand)
                            VStack(spacing: 8) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isExpanded { expandedBrandKeys.remove(group.brand) }
                                        else { expandedBrandKeys.insert(group.brand) }
                                    }
                                } label: {
                                    UserFoodBrandHeader(brand: group.brand, count: group.foods.count, isExpanded: isExpanded)
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    ForEach(group.foods) { food in
                                        Button {
                                            if isSelectionMode { toggleSelection(food.id) }
                                            else { editingFood = food }
                                        } label: {
                                            HStack(spacing: 8) {
                                                if isSelectionMode {
                                                    Image(systemName: selectedFoodIDs.contains(food.id) ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(selectedFoodIDs.contains(food.id) ? FamilyUI.accent : .secondary)
                                                }
                                                UserFoodRow(food: food)
                                            }
                                        }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button(role: .destructive) { modelContext.delete(food) } label: {
                                                    Label("删除", systemImage: "trash")
                                                }
                                            }
                                    }
                                    .padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle("餐食库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !foods.isEmpty {
                        Button(isSelectionMode ? "完成" : "多选") {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selectedFoodIDs.removeAll() }
                        }
                    }
                    Button {
                        isAddingFood = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode {
                HStack(spacing: 10) {
                    Button("全选") { selectedFoodIDs = Set(foods.map(\.id)) }
                    Button("批量改品牌") { isShowingBatchBrandEditor = true }
                        .disabled(selectedFoodIDs.isEmpty)
                    Button("删除 \(selectedFoodIDs.count) 条", role: .destructive) {
                        foods.filter { selectedFoodIDs.contains($0.id) }.forEach { modelContext.delete($0) }
                        selectedFoodIDs.removeAll()
                        isSelectionMode = false
                    }
                    .disabled(selectedFoodIDs.isEmpty)
                }
                .font(.caption.weight(.bold))
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            }
        }
        .sheet(isPresented: $isAddingFood) {
            UserFoodEditorView(food: nil)
        }
        .sheet(item: $editingFood) { food in
            UserFoodEditorView(food: food)
        }
        .sheet(isPresented: $isShowingBatchBrandEditor) {
            BatchBrandEditorSheet { brand in
                foods.filter { selectedFoodIDs.contains($0.id) }.forEach {
                    $0.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
                    $0.updatedAt = .now
                }
                selectedFoodIDs.removeAll()
                isSelectionMode = false
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedFoodIDs.contains(id) { selectedFoodIDs.remove(id) }
        else { selectedFoodIDs.insert(id) }
    }
}

struct BatchBrandEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var brand = ""
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form { TextField("品牌（留空表示未标品牌）", text: $brand) }
                .navigationTitle("批量修改品牌")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { onSave(brand); dismiss() }
                    }
                }
        }
    }
}

private struct UserFoodRow: View {
    let food: UserFood

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("\(food.brand.isEmpty ? "未标品牌" : food.brand) · \(Int(food.servingNutrition["calories"] ?? food.caloriesPer100g)) kcal / 份 · USED \(food.useCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(food.defaultAmount.nutritionDecimal)\(food.defaultUnit)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
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

private struct UserFoodBrandHeader: View {
    let brand: String
    let count: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .foregroundStyle(.orange)
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .background(FamilyUI.panelMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(brand)
                    .font(.subheadline.weight(.bold))
                Text("\(count) 条餐食记录")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius).stroke(FamilyUI.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

struct UserFoodEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let food: UserFood?

    @State private var name = ""
    @State private var brand = ""
    @State private var amountText = "1"
    @State private var unit = "份"
    // 旧数据兼容字段：新餐食不再显示或使用克重。
    @State private var servingGramsText = "100"
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

    private let units = ["g", "ml", "份", "个", "杯", "碗", "片", "块"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(caloriesText) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "USER FOOD",
                        title: food == nil ? "新增餐食记录" : "编辑餐食记录",
                        detail: "已确认的餐食营养资料，用于快速记录。"
                    )

                    servingPanel
                    nutritionPanel
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(food == nil ? "新增食物" : "编辑食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var servingPanel: some View {
        SystemPanel(title: "默认份量", detail: "设置默认份量和单位，不记录克重") {
            editorHeader("默认份量", value: canSave ? "已就绪" : "待完善")

            TextField("品牌（可选）", text: $brand)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FamilyUI.panelMutedBackground)
                .overlay(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius).stroke(FamilyUI.panelBorder, lineWidth: 1))

            TextField("名称", text: $name)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )

            SystemPanelDivider()

            HStack(spacing: 10) {
                compactAmountField("份量", text: $amountText, placeholder: "1")
                VStack(alignment: .leading, spacing: 6) {
                    Text("单位")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Picker("单位", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 96)
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
    }

    private var nutritionPanel: some View {
        SystemPanel(title: "每份营养", detail: "填写一份对应的热量与营养素") {
            editorHeader("每份营养", value: caloriesText.isEmpty ? "必填" : "\(caloriesText) KCAL")
            UserFoodNutritionField(label: "热量/份", text: $caloriesText, unit: "kcal")
            dividerNutritionField(label: "蛋白质", text: $proteinText, unit: "g")
            dividerNutritionField(label: "碳水化合物", text: $carbsText, unit: "g")
            dividerNutritionField(label: "脂肪", text: $fatText, unit: "g")
            dividerNutritionField(label: "膳食纤维", text: $fiberText, unit: "g")
            dividerNutritionField(label: "钠", text: $sodiumText, unit: "mg")
            dividerNutritionField(label: "糖", text: $sugarText, unit: "g")
            dividerNutritionField(label: "胆固醇", text: $cholesterolText, unit: "mg")
            dividerNutritionField(label: "咖啡因", text: $caffeineText, unit: "mg")
            dividerNutritionField(label: "茶多酚", text: $teaPolyphenolsText, unit: "mg")
            dividerNutritionField(label: "钙", text: $calciumText, unit: "mg")
            dividerNutritionField(label: "镁", text: $magnesiumText, unit: "mg")
            dividerNutritionField(label: "钾", text: $potassiumText, unit: "mg")
            dividerNutritionField(label: "铁", text: $ironText, unit: "mg")
            dividerNutritionField(label: "锌", text: $zincText, unit: "mg")
            dividerNutritionField(label: "维生素 A", text: $vitaminAText, unit: "ug")
            dividerNutritionField(label: "维生素 C", text: $vitaminCText, unit: "mg")
            dividerNutritionField(label: "维生素 D", text: $vitaminDText, unit: "ug")
            dividerNutritionField(label: "维生素 E", text: $vitaminEText, unit: "mg")
            dividerNutritionField(label: "维生素 B1", text: $vitaminB1Text, unit: "mg")
            dividerNutritionField(label: "维生素 B2", text: $vitaminB2Text, unit: "mg")
            dividerNutritionField(label: "烟酸", text: $niacinText, unit: "mg")
            dividerNutritionField(label: "维生素 B6", text: $vitaminB6Text, unit: "mg")
            dividerNutritionField(label: "叶酸", text: $folateText, unit: "ug")
            dividerNutritionField(label: "维生素 B12", text: $vitaminB12Text, unit: "ug")
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

    private func compactAmountField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
        }
    }

    private func dividerNutritionField(label: String, text: Binding<String>, unit: String) -> some View {
        VStack(spacing: 0) {
            SystemPanelDivider()
            UserFoodNutritionField(label: label, text: text, unit: unit)
        }
    }

    private func load() {
        guard let food else { return }
        name = food.name
        brand = food.brand
        amountText = food.defaultAmount.nutritionDecimal
        unit = food.defaultUnit
        servingGramsText = food.defaultServingGrams.nutritionDecimal
        let serving = food.servingNutrition
        caloriesText = (serving["calories"] ?? food.caloriesPer100g).nutritionDecimal
        proteinText = nutritionValue("protein", serving, food.proteinPer100g)
        carbsText = nutritionValue("carbs", serving, food.carbsPer100g)
        fatText = nutritionValue("fat", serving, food.fatPer100g)
        fiberText = nutritionValue("fiber", serving, food.fiberPer100g)
        sodiumText = nutritionValue("sodium", serving, food.sodiumPer100g)
        sugarText = nutritionValue("sugar", serving, food.sugarPer100g)
        cholesterolText = nutritionValue("cholesterol", serving, food.cholesterolPer100g)
        caffeineText = nutritionValue("caffeine", serving, food.caffeinePer100g)
        teaPolyphenolsText = nutritionValue("teaPolyphenols", serving, food.teaPolyphenolsPer100g)
        calciumText = nutritionValue("calcium", serving, food.calciumPer100g)
        magnesiumText = nutritionValue("magnesium", serving, food.magnesiumPer100g)
        potassiumText = nutritionValue("potassium", serving, food.potassiumPer100g)
        ironText = nutritionValue("iron", serving, food.ironPer100g)
        zincText = nutritionValue("zinc", serving, food.zincPer100g)
        vitaminAText = nutritionValue("vitaminA", serving, food.vitaminAPer100g)
        vitaminCText = nutritionValue("vitaminC", serving, food.vitaminCPer100g)
        vitaminDText = nutritionValue("vitaminD", serving, food.vitaminDPer100g)
        vitaminEText = nutritionValue("vitaminE", serving, food.vitaminEPer100g)
        vitaminB1Text = nutritionValue("vitaminB1", serving, food.vitaminB1Per100g)
        vitaminB2Text = nutritionValue("vitaminB2", serving, food.vitaminB2Per100g)
        niacinText = nutritionValue("niacin", serving, food.niacinPer100g)
        vitaminB6Text = nutritionValue("vitaminB6", serving, food.vitaminB6Per100g)
        folateText = nutritionValue("folate", serving, food.folatePer100g)
        vitaminB12Text = nutritionValue("vitaminB12", serving, food.vitaminB12Per100g)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Double(amountText) ?? 1
        let calories = Double(caloriesText) ?? 0
        let servingNutrition = makeServingNutrition(calories: calories)

        if let food {
            food.name = trimmedName
            food.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
            food.defaultAmount = amount
            food.defaultUnit = unit
            food.defaultServingGrams = 100
            food.caloriesPer100g = calories
            food.servingNutrition = servingNutrition
            food.proteinPer100g = Double(proteinText)
            food.carbsPer100g = Double(carbsText)
            food.fatPer100g = Double(fatText)
            food.fiberPer100g = Double(fiberText)
            food.sodiumPer100g = Double(sodiumText)
            food.sugarPer100g = Double(sugarText)
            food.cholesterolPer100g = Double(cholesterolText)
            food.caffeinePer100g = Double(caffeineText)
            food.teaPolyphenolsPer100g = Double(teaPolyphenolsText)
            food.calciumPer100g = Double(calciumText)
            food.magnesiumPer100g = Double(magnesiumText)
            food.potassiumPer100g = Double(potassiumText)
            food.ironPer100g = Double(ironText)
            food.zincPer100g = Double(zincText)
            food.vitaminAPer100g = Double(vitaminAText)
            food.vitaminCPer100g = Double(vitaminCText)
            food.vitaminDPer100g = Double(vitaminDText)
            food.vitaminEPer100g = Double(vitaminEText)
            food.vitaminB1Per100g = Double(vitaminB1Text)
            food.vitaminB2Per100g = Double(vitaminB2Text)
            food.niacinPer100g = Double(niacinText)
            food.vitaminB6Per100g = Double(vitaminB6Text)
            food.folatePer100g = Double(folateText)
            food.vitaminB12Per100g = Double(vitaminB12Text)
            food.updatedAt = .now
        } else {
            let food = UserFood(
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                name: trimmedName,
                defaultAmount: amount,
                defaultUnit: unit,
                defaultServingGrams: 100,
                caloriesPer100g: calories,
                servingNutrition: servingNutrition,
                proteinPer100g: Double(proteinText),
                carbsPer100g: Double(carbsText),
                fatPer100g: Double(fatText),
                fiberPer100g: Double(fiberText),
                sodiumPer100g: Double(sodiumText),
                sugarPer100g: Double(sugarText),
                cholesterolPer100g: Double(cholesterolText),
                caffeinePer100g: Double(caffeineText),
                teaPolyphenolsPer100g: Double(teaPolyphenolsText),
                calciumPer100g: Double(calciumText),
                magnesiumPer100g: Double(magnesiumText),
                potassiumPer100g: Double(potassiumText),
                ironPer100g: Double(ironText),
                zincPer100g: Double(zincText),
                vitaminAPer100g: Double(vitaminAText),
                vitaminCPer100g: Double(vitaminCText),
                vitaminDPer100g: Double(vitaminDText),
                vitaminEPer100g: Double(vitaminEText),
                vitaminB1Per100g: Double(vitaminB1Text),
                vitaminB2Per100g: Double(vitaminB2Text),
                niacinPer100g: Double(niacinText),
                vitaminB6Per100g: Double(vitaminB6Text),
                folatePer100g: Double(folateText),
                vitaminB12Per100g: Double(vitaminB12Text)
            )
            modelContext.insert(food)
        }

        HapticEngine.success()
        dismiss()
    }

    private func makeServingNutrition(calories: Double) -> [String: Double] {
        [
            "calories": calories, "protein": Double(proteinText), "carbs": Double(carbsText),
            "fat": Double(fatText), "fiber": Double(fiberText), "sodium": Double(sodiumText),
            "sugar": Double(sugarText), "cholesterol": Double(cholesterolText),
            "caffeine": Double(caffeineText), "teaPolyphenols": Double(teaPolyphenolsText),
            "calcium": Double(calciumText), "magnesium": Double(magnesiumText),
            "potassium": Double(potassiumText), "iron": Double(ironText), "zinc": Double(zincText),
            "vitaminA": Double(vitaminAText), "vitaminC": Double(vitaminCText),
            "vitaminD": Double(vitaminDText), "vitaminE": Double(vitaminEText),
            "vitaminB1": Double(vitaminB1Text), "vitaminB2": Double(vitaminB2Text),
            "niacin": Double(niacinText), "vitaminB6": Double(vitaminB6Text),
            "folate": Double(folateText), "vitaminB12": Double(vitaminB12Text)
        ].compactMapValues { $0 }
    }

    private func nutritionValue(_ key: String, _ serving: [String: Double], _ legacy: Double?) -> String {
        (serving[key] ?? legacy)?.nutritionDecimal ?? ""
    }
}

private struct UserFoodNutritionField: View {
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
