import SwiftUI

struct MealConfirmationCard: View {
    let meal: AIParsedMeal
    let onConfirm: (AIParsedMeal) -> Void
    let onCancel: () -> Void
    var onSaveAsTemplate: ((AIParsedMeal) -> Void)?

    @State private var adjustedItems: [AIParsedFoodItem] = []
    @State private var adjustedAmounts: [UUID: Double] = [:]
    @State private var isShowingManualEditor = false
    @State private var overallScale: Double = 0.5
    @State private var overallLocalScale: Double = 0.5

    private var hasAnyRange: Bool {
        meal.items.contains { $0.isEstimatedRange }
    }

    private var baseRangedCalories: Double {
        meal.items.filter { $0.isEstimatedRange }.reduce(0) { $0 + $1.calories }
    }

    private var totalCalories: Double {
        adjustedItems.isEmpty ? meal.items.reduce(0) { $0 + $1.calories }
                              : adjustedItems.reduce(0) { $0 + $1.calories }
    }

    private var totalCaloriesRange: (Double, Double)? {
        guard hasAnyRange else { return nil }
        let items = adjustedItems.isEmpty ? meal.items : adjustedItems
        let min = items.reduce(0.0) { $0 + ($1.caloriesMin ?? $1.calories) }
        let max = items.reduce(0.0) { $0 + ($1.caloriesMax ?? $1.calories) }
        return min != max ? (min, max) : nil
    }

    private var hasLazyNutritionEstimate: Bool {
        let items = adjustedItems.isEmpty ? meal.items : adjustedItems
        return items.contains(where: \.isLazyNutritionEstimate)
    }

    private func confirmedMeal() -> AIParsedMeal {
        AIParsedMeal(mealType: meal.mealType, items: adjustedItems.isEmpty ? meal.items : adjustedItems, note: meal.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !meal.note.isEmpty {
                        Text(meal.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if hasAnyRange {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("整体估算克重")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                if let range = totalCaloriesRange {
                                    Text("\(Int(range.0))-\(Int(range.1)) kcal")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Slider(value: $overallLocalScale, in: 0...1, step: 0.05) { isDragging in
                                if !isDragging {
                                    overallScale = overallLocalScale
                                    applyOverallScale(overallLocalScale)
                                }
                            }
                            .tint(FamilyUI.accent)

                            HStack {
                                Text("\(Int(baseRangedCalories * 0.5)) kcal")
                                    .font(FamilyTypography.text(size: 10))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("×\(String(format: "%.1f", pow(2.0, 2.0 * overallLocalScale - 1.0)))")
                                    .font(FamilyTypography.text(size: 10))
                                    .foregroundStyle(FamilyUI.accent)
                                Spacer()
                                Text("\(Int(baseRangedCalories * 2.0)) kcal")
                                    .font(FamilyTypography.text(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                isShowingManualEditor = true
                            } label: {
                                Label("查看详情", systemImage: "list.bullet.rectangle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(FamilyUI.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    }

                    let displayItems = adjustedItems.isEmpty ? meal.items : adjustedItems
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        foodItemSection(item, index: index)
                    }

                    if totalCalories <= 0 {
                        Text("热量数据缺失，无法记录。请用 AI 重新识别或手动添加。")
                            .font(.caption2)
                            .foregroundStyle(FamilyUI.danger)
                    }
                    if hasLazyNutritionEstimate {
                        Text("当前结果缺少热量或三大宏量素。请点“手动编辑”补齐后再记录。")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(FamilyUI.danger)
                    }
                }
            }
            .frame(maxHeight: 360)
            .scrollIndicators(.visible)

            HStack(spacing: 12) {
                Button("取消") { onCancel() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isShowingManualEditor = true
                } label: {
                    Label("手动编辑", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(hasLazyNutritionEstimate ? FamilyUI.warning.opacity(0.14) : FamilyUI.panelMutedBackground)
                        .foregroundStyle(hasLazyNutritionEstimate ? FamilyUI.accent : Color.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                if let onSaveAsTemplate {
                    Button {
                        onSaveAsTemplate(confirmedMeal())
                    } label: {
                        Label("存到模板库", systemImage: "doc.on.doc")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(FamilyUI.panelMutedBackground)
                            .foregroundStyle(.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    }
                }
                Button("确认记录") { onConfirm(confirmedMeal()) }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(totalCalories > 0 && !hasLazyNutritionEstimate ? Color.black : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    .disabled(totalCalories <= 0 || hasLazyNutritionEstimate)
            }
        }
        .padding(16)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            adjustedItems = meal.items
        }
        .sheet(isPresented: $isShowingManualEditor) {
            MealManualEditSheet(meal: confirmedMeal()) { updatedMeal in
                adjustedItems = updatedMeal.items
            }
            .presentationDetents([.large])
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                SystemStatusBadge(text: "AI 餐食复核", tone: .accent)
                Text(meal.mealType.displayName)
                    .font(.headline.weight(.black))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let range = totalCaloriesRange {
                    Text("预计 \(Int(range.0))-\(Int(range.1)) kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("推荐记录值 \(Int(totalCalories)) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
            }
        }
    }

    private func foodItemSection(_ item: AIParsedFoodItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name).font(.caption)
                if let conf = item.confidence {
                    Text(confidenceLabel(conf))
                        .font(FamilyTypography.text(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(confidenceColor(conf).opacity(0.12))
                        .foregroundStyle(confidenceColor(conf))
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                }
                Spacer()
                Text(reviewAmountDisplay(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(item.caloriesDisplay + " kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if item.isEstimatedRange {
                FoodItemSliderView(
                    baseItem: meal.items[index],
                    externalAmount: adjustedAmounts[item.id] ?? item.amount
                ) { committedAmount in
                    adjustedAmounts[item.id] = committedAmount
                    applyAmount(index: index, amount: committedAmount)
                }
            }

            if item.nutritionDataBasis != .estimated || item.nutritionDataNote != nil {
                HStack(spacing: 6) {
                    Text(item.nutritionDataBasis.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(FamilyUI.accent)
                    if let note = item.nutritionDataNote, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if let missingSummary = item.missingNutrientSummary {
                Text(missingSummary)
                    .font(.caption2)
                    .foregroundStyle(FamilyUI.accent)
                    .lineLimit(2)
            }

            if item.isLazyNutritionEstimate {
                Label("缺少关键字段：\(criticalMissingText(for: item))", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(FamilyUI.danger)
            }
        }
    }

    private func criticalMissingText(for item: AIParsedFoodItem) -> String {
        var names: [String] = []
        if item.calories <= 0 { names.append("热量") }
        names.append(contentsOf: item.missingCoreNutrientKeys.map(\.displayName))
        return names.isEmpty ? "未知" : names.joined(separator: "、")
    }

    private func reviewAmountDisplay(for item: AIParsedFoodItem) -> String {
        if let min = item.amountMin, let max = item.amountMax, min != max {
            return "\(Int(roundedFoodAmount(min)))-\(Int(roundedFoodAmount(max)))g"
        }
        if ["g", "克", "gram", "grams"].contains(item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return "\(Int(roundedFoodAmount(item.amount)))g"
        }
        return item.amountDisplay
    }

    private func applyAmount(index: Int, amount: Double) {
        guard index < adjustedItems.count else { return }
        var item = meal.items[index]
        item.scaleToAmount(amount)
        adjustedItems[index] = item
    }

    private func applyOverallScale(_ scale: Double) {
        adjustedItems = meal.items.enumerated().map { index, item in
            guard item.isEstimatedRange else { return adjustedItems.isEmpty ? item : adjustedItems[index] }
            var updated = item
            updated.applyScale(scale)
            updated.scaleToAmount(roundedFoodAmount(updated.amount))
            return updated
        }
        for item in adjustedItems where item.isEstimatedRange {
            adjustedAmounts[item.id] = item.amount
        }
    }

    private func confidenceLabel(_ conf: String) -> String {
        switch conf {
        case "high": return "精确"
        case "medium": return "估算"
        default: return "粗估"
        }
    }

    private func confidenceColor(_ conf: String) -> Color {
        switch conf {
        case "high": return FamilyUI.success
        case "medium": return FamilyUI.accent
        default: return FamilyUI.danger
        }
    }

    private func roundedFoodAmount(_ value: Double) -> Double {
        let step: Double
        switch value {
        case ..<100:
            step = 1
        case ..<300:
            step = 5
        default:
            step = 10
        }
        return max((value / step).rounded() * step, step)
    }
}

private struct FoodItemSliderView: View {
    let baseItem: AIParsedFoodItem
    let externalAmount: Double
    let onCommit: (Double) -> Void

    @State private var localAmount: Double

    init(baseItem: AIParsedFoodItem, externalAmount: Double, onCommit: @escaping (Double) -> Void) {
        self.baseItem = baseItem
        self.externalAmount = externalAmount
        self.onCommit = onCommit
        self._localAmount = State(initialValue: externalAmount)
    }

    private var baseAmount: Double {
        if let min = baseItem.amountMin, let max = baseItem.amountMax {
            return (min + max) / 2
        }
        return baseItem.amount
    }

    private var rawLeftAmount: Double { roundedAmount(baseItem.amountMin ?? baseAmount * 0.5) }
    private var rawRightAmount: Double { roundedAmount(baseItem.amountMax ?? baseAmount * 2.0) }
    private var leftAmount: Double { min(rawLeftAmount, rawRightAmount) }
    private var rightAmount: Double { max(rawLeftAmount, rawRightAmount) }
    private var clampedAmount: Double { min(max(roundedAmount(localAmount), leftAmount), rightAmount) }
    private var step: Double {
        switch max(rightAmount, localAmount) {
        case ..<100:
            return 1
        case ..<300:
            return 5
        default:
            return 10
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Slider(value: $localAmount, in: leftAmount...rightAmount, step: step) { isDragging in
                if !isDragging { onCommit(clampedAmount) }
            }
            .tint(FamilyUI.accent)

            HStack {
                Text("\(Int(leftAmount))g")
                    .font(FamilyTypography.text(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(clampedAmount))g")
                    .font(FamilyTypography.text(size: 9))
                    .foregroundStyle(FamilyUI.accent)
                Spacer()
                Text("\(Int(rightAmount))g")
                    .font(FamilyTypography.text(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: externalAmount) { _, newAmount in
            localAmount = min(max(roundedAmount(newAmount), leftAmount), rightAmount)
        }
    }

    private func roundedAmount(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        let step: Double
        switch value {
        case ..<100:
            step = 1
        case ..<300:
            step = 5
        default:
            step = 10
        }
        return max((value / step).rounded() * step, step)
    }
}

struct AIMealIdentificationConfirmationView: View {
    let confirmation: MealIdentificationConfirmation
    let onAccept: () -> Void
    let onReidentifyWithAI: () -> Void
    let onManualEdit: () -> Void
    let onCancel: () -> Void
    let onSaveAsTemplate: () -> Void

    private var sourceColor: Color {
        confirmation.isFromLocalParser ? FamilyUI.accent : FamilyUI.info
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                    .fill(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                    .overlay(
                        Image(systemName: confirmation.isFromLocalParser ? "wand.and.stars.inverse" : "sparkles")
                            .font(FamilyTypography.text(size: 14, weight: .black))
                            .foregroundStyle(sourceColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    SystemStatusBadge(text: confirmation.isFromLocalParser ? "本地解析" : "AI 结果", tone: confirmation.isFromLocalParser ? .warning : .accent)
                    Text(confirmation.isFromLocalParser ? "本地识别结果" : "AI 识别结果")
                        .font(.headline.weight(.black))
                    Text("请确认后再写入记录；不正确可交给 AI 重新处理。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    HapticEngine.tap()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("原始输入")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text(confirmation.originalText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
            .padding(12)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))

            mealSummary

            HStack(spacing: 10) {
                Button {
                    HapticEngine.tap()
                    onReidentifyWithAI()
                } label: {
                    Label("用 AI 重新识别", systemImage: "sparkles")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .controlSize(.small)

                Button {
                    HapticEngine.tap()
                    onManualEdit()
                } label: {
                    Label("手动编辑", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .controlSize(.small)

                Button {
                    HapticEngine.tap()
                    onAccept()
                } label: {
                    Label(acceptTitle, systemImage: "checkmark")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                Button {
                    HapticEngine.tap()
                    onSaveAsTemplate()
                } label: {
                    Label("存到模板库", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("忽略") {
                    HapticEngine.tap()
                    onCancel()
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var acceptTitle: String {
        switch confirmation.identificationType {
        case .meal: return "确认记录"
        case .meals(let meals): return "确认记录 \(meals.count) 餐"
        }
    }

    @ViewBuilder
    private var mealSummary: some View {
        switch confirmation.identificationType {
        case .meal(let meal):
            mealSummaryCard(meal)
        case .meals(let meals):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(meals) { meal in
                    mealSummaryCard(meal)
                }
            }
        }
    }

    private func mealSummaryCard(_ meal: AIParsedMeal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meal.mealType.displayName)
                    .font(.caption.weight(.bold))
                Spacer()
                Text("\(Int(meal.items.reduce(0) { $0 + $1.calories })) kcal")
                    .font(.caption.weight(.black))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
            }

            ForEach(meal.items) { item in
                HStack {
                    Text(item.name)
                        .font(.caption)
                    Spacer()
                    Text("\(item.amount.nutritionDecimal)\(item.unit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.calories > 0 ? "\(Int(item.calories)) kcal" : "未知")
                        .font(.caption)
                        .foregroundStyle(item.calories > 0 ? Color.primary : FamilyUI.accent)
                }
            }

            if meal.items.contains(where: { $0.nutritionDataNote != nil }) {
                HStack(spacing: 4) {
                    ForEach(Array(Set(meal.items.compactMap(\.nutritionDataNote))).prefix(2), id: \.self) { note in
                        Text(note)
                            .font(FamilyTypography.text(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FamilyUI.panelMutedBackground)
                            .foregroundStyle(FamilyUI.accent)
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                    }
                }
            }
        }
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }
}
