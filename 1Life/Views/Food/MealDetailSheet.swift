import SwiftUI

struct MealDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let meal: Meal

    private var items: [FoodItem] {
        (meal.foodItems ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    private var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { items.compactMap(\.protein).reduce(0, +) }
    private var totalCarbs: Double { items.compactMap(\.carbs).reduce(0, +) }
    private var totalFat: Double { items.compactMap(\.fat).reduce(0, +) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    if let photo = meal.photoData, let img = UIImage(data: photo) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                            .padding(.horizontal, AppSpacing.pageHorizontal)
                    }

                    foodItemsSection
                    nutrientBreakdown
                    dataSourceSection
                }
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle(meal.mealType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                    .fill(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: meal.mealType.icon)
                            .font(FamilyTypography.text(size: 16, weight: .semibold))
                            .foregroundStyle(FamilyUI.accent)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.mealType.displayName)
                        .font(.headline)
                    Text(meal.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(totalCalories))")
                    .font(FamilyTypography.text(size: 30, weight: .black))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
                + Text(" kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                macroCell(label: "蛋白质", value: totalProtein, unit: "g", color: FamilyUI.danger)
                Spacer()
                macroCell(label: "碳水", value: totalCarbs, unit: "g", color: FamilyUI.accent)
                Spacer()
                macroCell(label: "脂肪", value: totalFat, unit: "g", color: FamilyUI.warning)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .padding(.horizontal, AppSpacing.pageHorizontal)
    }

    private func macroCell(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value.nutritionDecimal)\(unit)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var foodItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("食物明细")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, 10)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().padding(.leading, AppSpacing.cardPadding)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        if item.amount > 0 {
                            Text("\(item.amount.nutritionDecimal)\(item.unit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(item.calories)) kcal")
                            .font(.subheadline.weight(.medium))
                    }
                    HStack(spacing: 12) {
                        if let p = item.protein { microLabel("蛋白", p, "g") }
                        if let c = item.carbs { microLabel("碳水", c, "g") }
                        if let f = item.fat { microLabel("脂肪", f, "g") }
                        if let fb = item.fiber { microLabel("纤维", fb, "g") }
                    }
                    if item.nutritionDataBasis != .direct {
                        Text(item.nutritionDataBasis.displayName)
                            .font(.caption2)
                            .foregroundStyle(FamilyUI.accent)
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, 8)
            }
        }
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .padding(.horizontal, AppSpacing.pageHorizontal)
    }

    private func microLabel(_ name: String, _ value: Double, _ unit: String) -> some View {
        Text("\(name) \(value.nutritionDecimal)\(unit)")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func nutrientTotal(for key: NutrientKey) -> Double? {
        let values: [Double] = items.compactMap { item in
            switch key {
            case .protein: return item.protein
            case .carbs: return item.carbs
            case .fat: return item.fat
            case .fiber: return item.fiber
            case .sodium: return item.sodium
            case .sugar: return item.sugar
            case .cholesterol: return item.cholesterol
            case .caffeine: return item.caffeine
            case .teaPolyphenols: return item.teaPolyphenols
            case .calcium: return item.calcium
            case .magnesium: return item.magnesium
            case .potassium: return item.potassium
            case .iron: return item.iron
            case .zinc: return item.zinc
            case .vitaminA: return item.vitaminA
            case .vitaminC: return item.vitaminC
            case .vitaminD: return item.vitaminD
            case .vitaminE: return item.vitaminE
            case .vitaminB1: return item.vitaminB1
            case .vitaminB2: return item.vitaminB2
            case .niacin: return item.niacin
            case .vitaminB6: return item.vitaminB6
            case .folate: return item.folate
            case .vitaminB12: return item.vitaminB12
            }
        }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    private var nutrientBreakdown: some View {
        let groups = NutrientDefinitions.dashboardGroups
        let hasAny = groups.contains { group in
            group.keys.contains { nutrientTotal(for: $0) != nil && nutrientTotal(for: $0)! > 0 }
        }

        return Group {
            if hasAny {
                VStack(alignment: .leading, spacing: 12) {
                    Text("全部营养素")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.top, 12)

                    ForEach(groups) { group in
                        let rows = group.keys.compactMap { key -> (NutrientKey, Double)? in
                            guard let val = nutrientTotal(for: key), val > 0 else { return nil }
                            return (key, val)
                        }
                        if !rows.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.group.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, AppSpacing.cardPadding)

                                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                                LazyVGrid(columns: columns, spacing: 8) {
                                    ForEach(rows, id: \.0) { key, value in
                                        HStack {
                                            Text(key.displayName)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(formatNutrient(value)) \(key.unit)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.cardPadding)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
                .background(FamilyUI.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                .padding(.horizontal, AppSpacing.pageHorizontal)
            }
        }
    }

    private func formatNutrient(_ value: Double) -> String {
        if value >= 10 { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }

    private var dataSourceSection: some View {
        let notes = items.compactMap { item -> (String, String)? in
            guard let note = item.nutritionDataNote, !note.isEmpty else { return nil }
            return (item.name, note)
        }

        return Group {
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("配料与来源")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, 10)

                    ForEach(Array(notes.enumerated()), id: \.offset) { index, entry in
                        if index > 0 {
                            Divider().padding(.leading, AppSpacing.cardPadding)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.0)
                                .font(.caption.weight(.medium))
                            Text(entry.1)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, 8)
                    }
                }
                .background(FamilyUI.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                .padding(.horizontal, AppSpacing.pageHorizontal)
            }
        }
    }
}
