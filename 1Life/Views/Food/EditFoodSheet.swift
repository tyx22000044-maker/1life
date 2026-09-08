import SwiftUI

struct EditFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: FoodItem

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
    @State private var nutritionDataBasis: NutritionDataBasis = .direct
    @State private var labelBaseAmountText = ""
    @State private var labelBaseUnit = "g"
    @State private var consumedAmountText = ""
    @State private var consumedUnit = "g"
    @State private var packageNetAmountText = ""
    @State private var packageNetUnit = "g"
    @State private var nutritionNote = ""

    private let units = ["g", "ml", "份", "个", "杯", "碗", "片", "块"]
    private let baseUnits = ["g", "ml", "份"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "FOOD ITEM",
                        title: "编辑营养记录",
                        detail: "更新份量、营养数据、标签换算和来源备注。"
                    )

                    foodInfoPanel
                    coreNutritionPanel
                    extendedNutritionPanel
                    officialLabelPanel
                    notePanel
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("编辑食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty || caloriesText.isEmpty)
                }
            }
            .onAppear {
                name = item.name
                amountText = item.amount.nutritionDecimal
                unit = item.unit
                servingGramsText = item.servingGrams.nutritionDecimal
                caloriesText = "\(Int(item.calories))"
                if let p = item.protein { proteinText = p.nutritionDecimal }
                if let c = item.carbs { carbsText = c.nutritionDecimal }
                if let f = item.fat { fatText = f.nutritionDecimal }
                if let v = item.fiber { fiberText = v.nutritionDecimal }
                if let v = item.sodium { sodiumText = v.nutritionDecimal }
                if let v = item.sugar { sugarText = v.nutritionDecimal }
                if let v = item.cholesterol { cholesterolText = v.nutritionDecimal }
                if let v = item.caffeine { caffeineText = v.nutritionDecimal }
                if let v = item.teaPolyphenols { teaPolyphenolsText = v.nutritionDecimal }
                if let v = item.calcium { calciumText = v.nutritionDecimal }
                if let v = item.magnesium { magnesiumText = v.nutritionDecimal }
                if let v = item.potassium { potassiumText = v.nutritionDecimal }
                if let v = item.iron { ironText = v.nutritionDecimal }
                if let v = item.zinc { zincText = v.nutritionDecimal }
                if let v = item.vitaminA { vitaminAText = v.nutritionDecimal }
                if let v = item.vitaminC { vitaminCText = v.nutritionDecimal }
                if let v = item.vitaminD { vitaminDText = v.nutritionDecimal }
                if let v = item.vitaminE { vitaminEText = v.nutritionDecimal }
                if let v = item.vitaminB1 { vitaminB1Text = v.nutritionDecimal }
                if let v = item.vitaminB2 { vitaminB2Text = v.nutritionDecimal }
                if let v = item.niacin { niacinText = v.nutritionDecimal }
                if let v = item.vitaminB6 { vitaminB6Text = v.nutritionDecimal }
                if let v = item.folate { folateText = v.nutritionDecimal }
                if let v = item.vitaminB12 { vitaminB12Text = v.nutritionDecimal }
                nutritionDataBasis = item.nutritionDataBasis
                labelBaseAmountText = item.labelBaseAmount?.nutritionDecimal ?? ""
                labelBaseUnit = item.labelBaseUnit ?? "g"
                consumedAmountText = item.consumedAmount?.nutritionDecimal ?? item.amount.nutritionDecimal
                consumedUnit = item.consumedUnit ?? item.unit
                packageNetAmountText = item.packageNetAmount?.nutritionDecimal ?? ""
                packageNetUnit = item.packageNetUnit ?? "g"
                nutritionNote = item.nutritionDataNote ?? ""
            }
        }
    }

    private var foodInfoPanel: some View {
        SystemPanel(title: "食物信息", detail: "设置食物名称、份量和单位") {
            editSectionHeader("食物信息", value: item.source == .ai ? "AI 来源" : "手动")
            systemTextField("名称", text: $name, placeholder: "食物名称")
            SystemPanelDivider()
            HStack(spacing: 10) {
                compactTextField("份量", text: $amountText, placeholder: "0", keyboard: .decimalPad)
                compactPicker("单位", selection: $unit, options: units)
            }
            SystemPanelDivider()
            HStack(spacing: 10) {
                compactTextField("对应克数", text: $servingGramsText, placeholder: "0", keyboard: .decimalPad)
                Text("g")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
            }
        }
    }

    private var coreNutritionPanel: some View {
        SystemPanel(title: "核心营养", detail: "填写热量与三大营养素") {
            editSectionHeader("核心营养", value: caloriesText.isEmpty ? "必填" : "\(caloriesText) kcal")
            NutritionEditField(label: "热量", text: $caloriesText, unit: "kcal")
            SystemPanelDivider()
            NutritionEditField(label: "蛋白质", text: $proteinText, unit: "g")
            SystemPanelDivider()
            NutritionEditField(label: "碳水", text: $carbsText, unit: "g")
            SystemPanelDivider()
            NutritionEditField(label: "脂肪", text: $fatText, unit: "g")
        }
    }

    private var extendedNutritionPanel: some View {
        SystemPanel(title: "微量营养素", detail: "填写可选扩展营养素") {
            editSectionHeader("微量营养素", value: "可选")
            NutritionEditField(label: "膳食纤维", text: $fiberText, unit: "g")
            nutrientDividerField(label: "钠", text: $sodiumText, unit: "mg")
            nutrientDividerField(label: "糖", text: $sugarText, unit: "g")
            nutrientDividerField(label: "胆固醇", text: $cholesterolText, unit: "mg")
            nutrientDividerField(label: "咖啡因", text: $caffeineText, unit: "mg")
            nutrientDividerField(label: "茶多酚", text: $teaPolyphenolsText, unit: "mg")
            nutrientDividerField(label: "钙", text: $calciumText, unit: "mg")
            nutrientDividerField(label: "镁", text: $magnesiumText, unit: "mg")
            nutrientDividerField(label: "钾", text: $potassiumText, unit: "mg")
            nutrientDividerField(label: "铁", text: $ironText, unit: "mg")
            nutrientDividerField(label: "锌", text: $zincText, unit: "mg")
            nutrientDividerField(label: "维生素A", text: $vitaminAText, unit: "ug")
            nutrientDividerField(label: "维生素C", text: $vitaminCText, unit: "mg")
            nutrientDividerField(label: "维生素D", text: $vitaminDText, unit: "ug")
            nutrientDividerField(label: "维生素E", text: $vitaminEText, unit: "mg")
            nutrientDividerField(label: "维生素B1", text: $vitaminB1Text, unit: "mg")
            nutrientDividerField(label: "维生素B2", text: $vitaminB2Text, unit: "mg")
            nutrientDividerField(label: "烟酸", text: $niacinText, unit: "mg")
            nutrientDividerField(label: "维生素B6", text: $vitaminB6Text, unit: "mg")
            nutrientDividerField(label: "叶酸", text: $folateText, unit: "ug")
            nutrientDividerField(label: "维生素B12", text: $vitaminB12Text, unit: "ug")
        }
    }

    private var officialLabelPanel: some View {
        let canApply = (Double(labelBaseAmountText) ?? 0) > 0 && (Double(consumedAmountText) ?? 0) > 0

        return SystemPanel(title: "官方标签", detail: "按包装标签换算本次实际摄入") {
            editSectionHeader("官方标签", value: nutritionDataBasis.displayName)
            Picker("数据基准", selection: $nutritionDataBasis) {
                Text("直接录入").tag(NutritionDataBasis.direct)
                Text("每100g").tag(NutritionDataBasis.per100g)
                Text("每100ml").tag(NutritionDataBasis.per100ml)
                Text("每份").tag(NutritionDataBasis.perServing)
            }
            .pickerStyle(.segmented)

            SystemPanelDivider()
            amountUnitRow(label: "标签基准量", amount: $labelBaseAmountText, unit: $labelBaseUnit, placeholder: "100")
            SystemPanelDivider()
            amountUnitRow(label: "实际食用量", amount: $consumedAmountText, unit: $consumedUnit, placeholder: "0")
            SystemPanelDivider()
            amountUnitRow(label: "包装净含量", amount: $packageNetAmountText, unit: $packageNetUnit, placeholder: "0")

            Button {
                applyOfficialLabelData()
            } label: {
                HStack {
                    Image(systemName: "function")
                    Text("按官方标签自动换算本次摄入")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(canApply ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(canApply ? FamilyUI.panelMutedBackground : FamilyUI.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
            }
            .disabled(!canApply)
            .padding(.top, 4)

            Text("先填标签基准量、实际食用量，再把上面的营养值当作官方标签数据，一键换算成这次实际摄入。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notePanel: some View {
        SystemPanel(title: "来源备注", detail: "记录数据来源、配料或备注") {
            editSectionHeader("来源备注", value: nutritionNote.isEmpty ? "未填写" : "已填写")
            TextField("数据来源/配料/备注", text: $nutritionNote, axis: .vertical)
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

    private func editSectionHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value, tone: .neutral)
        }
        .padding(.bottom, 2)
    }

    private func nutrientDividerField(label: String, text: Binding<String>, unit: String) -> some View {
        VStack(spacing: 0) {
            SystemPanelDivider()
            NutritionEditField(label: label, text: text, unit: unit)
        }
    }

    private func systemTextField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
        }
    }

    private func compactTextField(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
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

    private func compactPicker(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .font(.subheadline.weight(.semibold))
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

    private func amountUnitRow(
        label: String,
        amount: Binding<String>,
        unit: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField(placeholder, text: amount)
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
                Picker(label, selection: unit) {
                    ForEach(baseUnits, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 88)
                .padding(.vertical, 8)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
            }
        }
    }

    private func applyOfficialLabelData() {
        let baseAmount = Double(labelBaseAmountText) ?? 0
        let consumedAmount = Double(consumedAmountText) ?? 0
        guard baseAmount > 0, consumedAmount > 0 else { return }
        let ratio = consumedAmount / baseAmount

        caloriesText = scaled(caloriesText, ratio)
        proteinText = scaledOptional(proteinText, ratio)
        carbsText = scaledOptional(carbsText, ratio)
        fatText = scaledOptional(fatText, ratio)
        fiberText = scaledOptional(fiberText, ratio)
        sodiumText = scaledOptional(sodiumText, ratio)
        sugarText = scaledOptional(sugarText, ratio)
        cholesterolText = scaledOptional(cholesterolText, ratio)
        caffeineText = scaledOptional(caffeineText, ratio)
        teaPolyphenolsText = scaledOptional(teaPolyphenolsText, ratio)
        calciumText = scaledOptional(calciumText, ratio)
        magnesiumText = scaledOptional(magnesiumText, ratio)
        potassiumText = scaledOptional(potassiumText, ratio)
        ironText = scaledOptional(ironText, ratio)
        zincText = scaledOptional(zincText, ratio)
        vitaminAText = scaledOptional(vitaminAText, ratio)
        vitaminCText = scaledOptional(vitaminCText, ratio)
        vitaminDText = scaledOptional(vitaminDText, ratio)
        vitaminEText = scaledOptional(vitaminEText, ratio)
        vitaminB1Text = scaledOptional(vitaminB1Text, ratio)
        vitaminB2Text = scaledOptional(vitaminB2Text, ratio)
        niacinText = scaledOptional(niacinText, ratio)
        vitaminB6Text = scaledOptional(vitaminB6Text, ratio)
        folateText = scaledOptional(folateText, ratio)
        vitaminB12Text = scaledOptional(vitaminB12Text, ratio)

        amountText = consumedAmount.nutritionDecimal
        unit = consumedUnit
        if consumedUnit == "g" || consumedUnit == "ml" {
            servingGramsText = consumedAmount.nutritionDecimal
        }
        HapticEngine.tap()
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.amount = Double(amountText) ?? item.amount
        item.unit = unit
        item.servingGrams = Double(servingGramsText) ?? item.servingGrams
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
        item.labelBaseAmount = Double(labelBaseAmountText)
        item.labelBaseUnit = labelBaseUnit
        item.consumedAmount = Double(consumedAmountText)
        item.consumedUnit = consumedUnit
        item.packageNetAmount = Double(packageNetAmountText)
        item.packageNetUnit = packageNetUnit
        item.nutritionDataNote = nutritionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nutritionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        HapticEngine.success()
        dismiss()
    }

    private func scaled(_ text: String, _ ratio: Double) -> String {
        guard let value = Double(text) else { return text }
        return (value * ratio).nutritionDecimal
    }

    private func scaledOptional(_ text: String, _ ratio: Double) -> String {
        guard !text.isEmpty else { return "" }
        return scaled(text, ratio)
    }
}
