import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [MealTemplate]
    let userFoods: [UserFood]
    let drinkRecords: [DrinkRecord]
    let selectedDate: Date
    let onSelectUserFood: (UserFood) -> Void
    let onSelectDrink: (DrinkRecord) -> Void
    let onSelect: (MealTemplate) -> Void

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var expandedDrinkBrandKeys: Set<String> = []
    @State private var didAddUserFood = false

    private var normalizedSearchText: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mealOnlyTemplates: [MealTemplate] {
        templates.filter { TemplateLibraryCategory.meal.matches($0) }
    }

    private var filteredTemplates: [MealTemplate] {
        guard !normalizedSearchText.isEmpty else { return mealOnlyTemplates }
        return mealOnlyTemplates.filter { template in
            template.name.localizedCaseInsensitiveContains(normalizedSearchText)
                || template.mealType.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
                || template.foodItems.contains { $0.name.localizedCaseInsensitiveContains(normalizedSearchText) }
        }
    }

    private var filteredDrinkRecords: [DrinkRecord] {
        guard !normalizedSearchText.isEmpty else { return drinkRecords }
        return drinkRecords.filter { record in
            record.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
                || record.brand.localizedCaseInsensitiveContains(normalizedSearchText)
                || record.productName.localizedCaseInsensitiveContains(normalizedSearchText)
                || record.sugarLevel.localizedCaseInsensitiveContains(normalizedSearchText)
                || record.toppings.localizedCaseInsensitiveContains(normalizedSearchText)
                || record.sourceNote.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    private var filteredUserFoods: [UserFood] {
        guard !normalizedSearchText.isEmpty else { return userFoods }
        return userFoods.filter { food in
            food.name.localizedCaseInsensitiveContains(normalizedSearchText)
                || food.brand.localizedCaseInsensitiveContains(normalizedSearchText)
                || food.defaultUnit.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    private var drinkBrandGroups: [TemplatePickerDrinkBrandGroup] {
        Dictionary(grouping: filteredDrinkRecords, by: { TemplatePickerDrinkBrandGroup.groupKey(for: $0) })
            .values
            .map { TemplatePickerDrinkBrandGroup(records: $0) }
            .sorted { lhs, rhs in lhs.brand.localizedCompare(rhs.brand) == .orderedAscending }
    }

    var body: some View {
        let visibleTemplates = filteredTemplates
        let visibleUserFoods = filteredUserFoods
        let visibleDrinkRecords = filteredDrinkRecords
        let visibleDrinkBrandGroups = drinkBrandGroups
        let hasVisibleSearchResults = !visibleTemplates.isEmpty || !visibleUserFoods.isEmpty || !visibleDrinkRecords.isEmpty

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "模板库",
                        title: "从模板库创建",
                        detail: selectedDate.dayDisplay
                    )

                    if mealOnlyTemplates.isEmpty && userFoods.isEmpty && drinkRecords.isEmpty {
                        SystemPanel(title: "暂无模板", detail: "在餐食库或饮品库创建记录后可以在这里复用") {
                            VStack(alignment: .leading, spacing: 8) {
                                SystemStatusBadge(text: "暂无记录", tone: .neutral)
                                Text("还没有模板。")
                                    .font(.subheadline.weight(.semibold))
                                Text("到餐食库创建餐食模板，或到饮品库保存饮品记录后，可以在这里快速复用。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if !normalizedSearchText.isEmpty && !hasVisibleSearchResults {
                        AppEmptyStateView(
                            icon: "magnifyingglass",
                            title: "没有匹配模板",
                            subtitle: "换一个品牌、饮品名、糖度或食物名称试试。"
                        )
                    } else {
                        if !visibleTemplates.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                pickerSectionHeader("餐食模板", count: visibleTemplates.count)
                                ForEach(visibleTemplates) { template in
                                    Button {
                                        onSelect(template)
                                        dismiss()
                                    } label: {
                                        templateRow(template)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !visibleUserFoods.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                pickerSectionHeader("餐食库", count: visibleUserFoods.count)
                                ForEach(visibleUserFoods) { food in
                                    Button {
                                        onSelectUserFood(food)
                                        didAddUserFood = true
                                    } label: {
                                        userFoodRow(food)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !visibleDrinkRecords.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                pickerSectionHeader("饮品库", count: visibleDrinkRecords.count)
                                ForEach(visibleDrinkBrandGroups) { brandGroup in
                                    TemplatePickerDrinkBrandGroupSection(
                                        brandGroup: brandGroup,
                                        isExpanded: Binding(
                                            get: { !normalizedSearchText.isEmpty || expandedDrinkBrandKeys.contains(brandGroup.id) },
                                            set: { isExpanded in
                                                if isExpanded {
                                                    expandedDrinkBrandKeys.insert(brandGroup.id)
                                                } else {
                                                    expandedDrinkBrandKeys.remove(brandGroup.id)
                                                }
                                            }
                                        ),
                                        rowContent: { record in
                                            AnyView(
                                                Button {
                                                    onSelectDrink(record)
                                                    dismiss()
                                                } label: {
                                                    drinkRecordRow(record, showsBrandName: false)
                                                }
                                                .buttonStyle(.plain)
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("从模板库创建")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索食物、模板、饮品、糖度")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if didAddUserFood {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .task(id: searchText) {
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
                debouncedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private func pickerSectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: "\(count) 个", tone: .neutral)
        }
    }

    private func templateRow(_ template: MealTemplate) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: iconName(for: template.mealType))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(template.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    SystemStatusBadge(text: template.mealType.displayName, tone: .neutral)
                }

                Text("\(template.foodItems.count) 项 / \(Int(template.totalCalories)) kcal / 使用 \(template.useCount) 次")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
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

    private func userFoodRow(_ food: UserFood) -> some View {
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
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(food.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(food.brand.isEmpty ? "未标品牌" : food.brand) · \(food.defaultAmount.nutritionDecimal)\(food.defaultUnit)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(Int(food.servingNutrition["calories"] ?? food.caloriesPer100g)) kcal")
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyUI.accent)
                .monospacedDigit()
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }

    private func drinkRecordRow(_ record: DrinkRecord, showsBrandName: Bool = true) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.teal)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(showsBrandName ? record.displayName : record.productName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(drinkRecordSubtitle(record))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(record.calories.map { "\(Int($0)) kcal" } ?? "未知")
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyUI.accent)
                .monospacedDigit()
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }

    private func drinkRecordSubtitle(_ record: DrinkRecord) -> String {
        var parts: [String] = []
        if let sizeML = record.sizeML { parts.append("\(Int(sizeML))ml") }
        if !record.sugarLevel.isEmpty { parts.append(record.sugarLevel) }
        if !record.toppings.isEmpty { parts.append(record.toppings) }
        if let sugar = record.sugar { parts.append("糖 \(sugar.nutritionDecimal)g") }
        if let caffeine = record.caffeine { parts.append("咖啡因 \(caffeine.nutritionDecimal)mg") }
        return parts.isEmpty ? "饮品知识库" : parts.joined(separator: " · ")
    }

    private func iconName(for type: MealType) -> String {
        type.icon
    }
}

private struct TemplatePickerDrinkBrandGroup: Identifiable {
    let id: String
    let brand: String
    let records: [DrinkRecord]

    init(records: [DrinkRecord]) {
        let sorted = records.sorted { lhs, rhs in
            if lhs.productName != rhs.productName {
                return lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
            }
            if (lhs.sizeML ?? 0) != (rhs.sizeML ?? 0) {
                return (lhs.sizeML ?? 0) < (rhs.sizeML ?? 0)
            }
            return lhs.sugarLevel.localizedCompare(rhs.sugarLevel) == .orderedAscending
        }
        let first = sorted.first ?? records[0]
        self.id = Self.groupKey(for: first)
        let trimmedBrand = first.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brand = trimmedBrand.isEmpty ? "未标品牌" : trimmedBrand
        self.records = sorted
    }

    static func groupKey(for record: DrinkRecord) -> String {
        DrinkLibraryIndex.normalize(record.brand)
    }
}

private struct TemplatePickerDrinkBrandGroupSection: View {
    let brandGroup: TemplatePickerDrinkBrandGroup
    @Binding var isExpanded: Bool
    let rowContent: (DrinkRecord) -> AnyView

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                        .overlay(
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.teal)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(brandGroup.brand)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(brandGroup.records.count) 条饮品记录")
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
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(brandGroup.records) { record in
                        rowContent(record)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}
