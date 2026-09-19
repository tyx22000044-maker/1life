import SwiftUI

struct MealManualEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (AIParsedMeal) -> Void
    @State private var draftMeal: AIParsedMeal
    @State private var editingItemIndex: Int?

    init(meal: AIParsedMeal, onSave: @escaping (AIParsedMeal) -> Void) {
        self.onSave = onSave
        _draftMeal = State(initialValue: meal)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "AI 餐食复核",
                        title: "手动编辑",
                        detail: "保存前确认餐次、备注和食物明细。"
                    )

                    SystemPanel(title: "餐次", detail: "确认 AI 解析出的餐次") {
                        editorHeader("餐次", value: draftMeal.mealType.displayName)
                        Picker("餐次", selection: $draftMeal.mealType) {
                            ForEach(MealType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if !draftMeal.note.isEmpty {
                        SystemPanel(title: "AI 备注", detail: "AI 识别时附带的备注") {
                            editorHeader("AI 备注", value: "已附加")
                            Text(draftMeal.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    SystemPanel(title: "食物明细", detail: "检查并编辑识别出的食物") {
                        editorHeader("食物明细", value: "\(draftMeal.items.count) 项")
                        VStack(spacing: 0) {
                            ForEach(Array(draftMeal.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    SystemPanelDivider()
                                }

                                Button {
                                    editingItemIndex = index
                                } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack(alignment: .top) {
                                            Text(item.name)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text("\(Int(item.calories)) kcal")
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(FamilyUI.accent)
                                                .monospacedDigit()
                                        }
                                        Text("\(item.amount.nutritionDecimal)\(item.unit) · \(item.nutritionDataBasis.displayName)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        if item.isLazyNutritionEstimate {
                                            Text("营养素仍不完整，建议手动补充并改为直接录入")
                                                .font(.caption2)
                                                .foregroundStyle(FamilyUI.accent)
                                        }
                                    }
                                    .padding(.vertical, 9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("手动编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draftMeal)
                        dismiss()
                    }
                }
            }
            .sheet(item: Binding(
                get: { editingItemIndex.map { EditorItemIndex(rawValue: $0) } },
                set: { editingItemIndex = $0?.rawValue }
            )) { itemIndex in
                if draftMeal.items.indices.contains(itemIndex.rawValue) {
                    ParsedFoodItemEditorSheet(item: draftMeal.items[itemIndex.rawValue]) { updatedItem in
                        guard draftMeal.items.indices.contains(itemIndex.rawValue) else { return }
                        draftMeal.items[itemIndex.rawValue] = updatedItem
                    }
                    .presentationDetents([.large])
                } else {
                    NavigationStack {
                        AppEmptyStateView(
                            icon: "exclamationmark.triangle",
                            title: "食物项已变化",
                            subtitle: "请关闭后重新选择要编辑的食物。"
                        )
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("关闭") { editingItemIndex = nil }
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func editorHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value, tone: .neutral)
        }
    }
}

private struct ParsedFoodItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (AIParsedFoodItem) -> Void

    @State private var item: AIParsedFoodItem
    @State private var originalItem: AIParsedFoodItem
    @State private var name = ""
    @State private var amountText = ""
    @State private var unit = "g"
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
    @State private var nutritionDataBasis: NutritionDataBasis = .direct
    @State private var nutritionNote = ""
    @State private var shouldAutoScaleNutrition = true

    private let units = ["g", "ml", "份", "个", "杯", "碗", "片", "块"]

    init(item: AIParsedFoodItem, onSave: @escaping (AIParsedFoodItem) -> Void) {
        self.onSave = onSave
        _item = State(initialValue: item)
        _originalItem = State(initialValue: item)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "AI 食物项",
                        title: "编辑营养",
                        detail: "保存前校准食物名称、份量和营养值。"
                    )

                    parsedFoodInfoPanel
                    parsedCoreNutritionPanel
                    parsedExtendedNutritionPanel
                    parsedNotePanel
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("编辑食物")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: amountText) { _, newValue in
                guard shouldAutoScaleNutrition, let newAmount = Double(newValue), newAmount > 0 else { return }
                syncNutritionFields(newAmount: newAmount)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(caloriesText) ?? 0) <= 0)
                }
            }
            .onAppear {
                name = item.name
                amountText = item.amount.nutritionDecimal
                unit = item.unit
                caloriesText = item.calories.nutritionDecimal
                proteinText = item.protein?.nutritionDecimal ?? ""
                carbsText = item.carbs?.nutritionDecimal ?? ""
                fatText = item.fat?.nutritionDecimal ?? ""
                fiberText = item.fiber?.nutritionDecimal ?? ""
                sodiumText = item.sodium?.nutritionDecimal ?? ""
                sugarText = item.sugar?.nutritionDecimal ?? ""
                cholesterolText = item.cholesterol?.nutritionDecimal ?? ""
                caffeineText = item.caffeine?.nutritionDecimal ?? ""
                teaPolyphenolsText = item.teaPolyphenols?.nutritionDecimal ?? ""
                calciumText = item.calcium?.nutritionDecimal ?? ""
                magnesiumText = item.magnesium?.nutritionDecimal ?? ""
                potassiumText = item.potassium?.nutritionDecimal ?? ""
                ironText = item.iron?.nutritionDecimal ?? ""
                zincText = item.zinc?.nutritionDecimal ?? ""
                vitaminAText = item.vitaminA?.nutritionDecimal ?? ""
                vitaminCText = item.vitaminC?.nutritionDecimal ?? ""
                vitaminDText = item.vitaminD?.nutritionDecimal ?? ""
                vitaminEText = item.vitaminE?.nutritionDecimal ?? ""
                vitaminB1Text = item.vitaminB1?.nutritionDecimal ?? ""
                vitaminB2Text = item.vitaminB2?.nutritionDecimal ?? ""
                niacinText = item.niacin?.nutritionDecimal ?? ""
                vitaminB6Text = item.vitaminB6?.nutritionDecimal ?? ""
                folateText = item.folate?.nutritionDecimal ?? ""
                vitaminB12Text = item.vitaminB12?.nutritionDecimal ?? ""
                nutritionDataBasis = item.nutritionDataBasis == .estimated ? .direct : item.nutritionDataBasis
                nutritionNote = item.nutritionDataNote ?? ""
            }
        }
    }

    private var parsedFoodInfoPanel: some View {
        SystemPanel(title: "食物信息", detail: "确认食物名称、份量和数据依据") {
            editorHeader("食物信息", value: nutritionDataBasis.displayName)

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
                compactAmountField("份量", text: $amountText, placeholder: "0")
                VStack(alignment: .leading, spacing: 6) {
                    Text("单位")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Picker("单位", selection: $unit) {
                        ForEach(units, id: \.self) { value in
                            Text(value).tag(value)
                        }
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

            SystemPanelDivider()

            Picker("数据依据", selection: $nutritionDataBasis) {
                ForEach(NutritionDataBasis.allCases) { basis in
                    Text(basis.displayName).tag(basis)
                }
            }
            .pickerStyle(.menu)

            Toggle("按份量同步缩放营养", isOn: $shouldAutoScaleNutrition)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var parsedCoreNutritionPanel: some View {
        SystemPanel(title: "核心营养", detail: "确认热量与三大营养素") {
            editorHeader("核心营养", value: caloriesText.isEmpty ? "必填" : "\(caloriesText) kcal")
            NutritionEditField(label: "热量", text: $caloriesText, unit: "kcal")
            dividerNutritionField(label: "蛋白质", text: $proteinText, unit: "g")
            dividerNutritionField(label: "碳水", text: $carbsText, unit: "g")
            dividerNutritionField(label: "脂肪", text: $fatText, unit: "g")
        }
    }

    private var parsedExtendedNutritionPanel: some View {
        SystemPanel(title: "扩展营养", detail: "确认可选扩展营养素") {
            editorHeader("扩展营养", value: "可选")
            NutritionEditField(label: "膳食纤维", text: $fiberText, unit: "g")
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
            dividerNutritionField(label: "维生素A", text: $vitaminAText, unit: "ug")
            dividerNutritionField(label: "维生素C", text: $vitaminCText, unit: "mg")
            dividerNutritionField(label: "维生素D", text: $vitaminDText, unit: "ug")
            dividerNutritionField(label: "维生素E", text: $vitaminEText, unit: "mg")
            dividerNutritionField(label: "维生素B1", text: $vitaminB1Text, unit: "mg")
            dividerNutritionField(label: "维生素B2", text: $vitaminB2Text, unit: "mg")
            dividerNutritionField(label: "烟酸", text: $niacinText, unit: "mg")
            dividerNutritionField(label: "维生素B6", text: $vitaminB6Text, unit: "mg")
            dividerNutritionField(label: "叶酸", text: $folateText, unit: "ug")
            dividerNutritionField(label: "维生素B12", text: $vitaminB12Text, unit: "ug")
        }
    }

    private var parsedNotePanel: some View {
        SystemPanel(title: "来源备注", detail: "记录来源说明、配料或备注") {
            editorHeader("来源备注", value: nutritionNote.isEmpty ? "未填写" : "已填写")
            TextField("来源说明 / 配料 / 备注", text: $nutritionNote, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...6)
                .padding(12)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
        }
    }

    private func editorHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value, tone: .neutral)
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
            NutritionEditField(label: label, text: text, unit: unit)
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedAmount = Double(amountText) ?? item.amount
        if shouldAutoScaleNutrition, updatedAmount > 0, originalItem.amount > 0 {
            item = originalItem
            item.scaleToAmount(updatedAmount)
        } else {
            item.amount = updatedAmount
        }
        item.unit = unit
        item.calories = Double(caloriesText) ?? item.calories
        item.protein = Double(proteinText)
        item.carbs = Double(carbsText)
        item.fat = Double(fatText)
        item.fiber = Double(fiberText)
        item.sodium = Double(sodiumText)
        item.sugar = Double(sugarText)
        item.cholesterol = Double(cholesterolText)
        item.caffeine = Double(caffeineText)
        item.teaPolyphenols = Double(teaPolyphenolsText)
        item.calcium = Double(calciumText)
        item.magnesium = Double(magnesiumText)
        item.potassium = Double(potassiumText)
        item.iron = Double(ironText)
        item.zinc = Double(zincText)
        item.vitaminA = Double(vitaminAText)
        item.vitaminC = Double(vitaminCText)
        item.vitaminD = Double(vitaminDText)
        item.vitaminE = Double(vitaminEText)
        item.vitaminB1 = Double(vitaminB1Text)
        item.vitaminB2 = Double(vitaminB2Text)
        item.niacin = Double(niacinText)
        item.vitaminB6 = Double(vitaminB6Text)
        item.folate = Double(folateText)
        item.vitaminB12 = Double(vitaminB12Text)
        item.nutritionDataBasis = nutritionDataBasis
        item.nutritionDataNote = nutritionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nutritionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        item.amountMin = nil
        item.amountMax = nil
        item.caloriesMin = nil
        item.caloriesMax = nil
        item.confidence = "high"
        onSave(item)
        dismiss()
    }

    private func syncNutritionFields(newAmount: Double) {
        var preview = originalItem
        preview.scaleToAmount(newAmount)
        caloriesText = preview.calories.nutritionDecimal
        proteinText = preview.protein?.nutritionDecimal ?? ""
        carbsText = preview.carbs?.nutritionDecimal ?? ""
        fatText = preview.fat?.nutritionDecimal ?? ""
        fiberText = preview.fiber?.nutritionDecimal ?? ""
        sodiumText = preview.sodium?.nutritionDecimal ?? ""
        sugarText = preview.sugar?.nutritionDecimal ?? ""
        cholesterolText = preview.cholesterol?.nutritionDecimal ?? ""
        caffeineText = preview.caffeine?.nutritionDecimal ?? ""
        teaPolyphenolsText = preview.teaPolyphenols?.nutritionDecimal ?? ""
        calciumText = preview.calcium?.nutritionDecimal ?? ""
        magnesiumText = preview.magnesium?.nutritionDecimal ?? ""
        potassiumText = preview.potassium?.nutritionDecimal ?? ""
        ironText = preview.iron?.nutritionDecimal ?? ""
        zincText = preview.zinc?.nutritionDecimal ?? ""
        vitaminAText = preview.vitaminA?.nutritionDecimal ?? ""
        vitaminCText = preview.vitaminC?.nutritionDecimal ?? ""
        vitaminDText = preview.vitaminD?.nutritionDecimal ?? ""
        vitaminEText = preview.vitaminE?.nutritionDecimal ?? ""
        vitaminB1Text = preview.vitaminB1?.nutritionDecimal ?? ""
        vitaminB2Text = preview.vitaminB2?.nutritionDecimal ?? ""
        niacinText = preview.niacin?.nutritionDecimal ?? ""
        vitaminB6Text = preview.vitaminB6?.nutritionDecimal ?? ""
        folateText = preview.folate?.nutritionDecimal ?? ""
        vitaminB12Text = preview.vitaminB12?.nutritionDecimal ?? ""
    }
}

private struct EditorItemIndex: Identifiable {
    let rawValue: Int
    var id: Int { rawValue }
}
