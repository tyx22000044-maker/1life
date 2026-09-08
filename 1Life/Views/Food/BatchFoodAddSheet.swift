import SwiftUI

struct BatchFoodAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userFoods: [UserFood]
    let recentItems: [FoodItem]
    let mealType: MealType
    let onAdd: (Set<UUID>, Set<UUID>) -> Void

    @State private var selectedUserFoodIDs: Set<UUID> = []
    @State private var selectedRecentItemIDs: Set<UUID> = []

    private var selectedCount: Int {
        selectedUserFoodIDs.count + selectedRecentItemIDs.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "BATCH ADD",
                        title: "选择食物",
                        detail: "将所选食物添加到\(mealType.displayName)"
                    )

                    if userFoods.isEmpty && recentItems.isEmpty {
                        SystemPanel(title: "暂无可选食物", detail: "保存常用食物或记录几餐后可批量添加") {
                            AppEmptyStateView(
                                icon: "checklist",
                                title: "还没有可批量添加的食物",
                                subtitle: "常用食物和最近吃过会显示在这里。"
                            )
                        }
                    }

                    if !userFoods.isEmpty {
                        batchSection(title: "常用食物", value: "\(userFoods.count) 个") {
                            ForEach(userFoods) { food in
                                BatchSelectableRow(
                                    title: food.name,
                                    subtitle: "\(food.defaultAmount.nutritionDecimal)\(food.defaultUnit) · \(Int(food.caloriesPer100g * food.defaultServingGrams / 100)) kcal",
                                    icon: "heart.fill",
                                    color: .pink,
                                    isSelected: selectedUserFoodIDs.contains(food.id)
                                ) {
                                    toggleUserFood(food.id)
                                }
                            }
                        }
                    }

                    if !recentItems.isEmpty {
                        batchSection(title: "最近吃过", value: "\(recentItems.count) 个") {
                            ForEach(recentItems) { item in
                                BatchSelectableRow(
                                    title: item.name,
                                    subtitle: "\(item.amount.nutritionDecimal)\(item.unit) · \(Int(item.calories)) kcal",
                                    icon: "clock.fill",
                                    color: FamilyUI.accent,
                                    isSelected: selectedRecentItemIDs.contains(item.id)
                                ) {
                                    toggleRecentItem(item.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("批量添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加 \(selectedCount)") {
                        onAdd(selectedUserFoodIDs, selectedRecentItemIDs)
                        dismiss()
                    }
                    .disabled(selectedCount == 0)
                }
            }
        }
    }

    private func batchSection<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SystemPanel(title: title, detail: "选择要一次添加的食物") {
            HStack {
                Text(title)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                SystemStatusBadge(text: value, tone: .neutral)
            }
            content()
        }
    }

    private func toggleUserFood(_ id: UUID) {
        if selectedUserFoodIDs.contains(id) {
            selectedUserFoodIDs.remove(id)
        } else {
            selectedUserFoodIDs.insert(id)
        }
        HapticEngine.tap()
    }

    private func toggleRecentItem(_ id: UUID) {
        if selectedRecentItemIDs.contains(id) {
            selectedRecentItemIDs.remove(id)
        } else {
            selectedRecentItemIDs.insert(id)
        }
        HapticEngine.tap()
    }
}

private struct BatchSelectableRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(color)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? FamilyUI.accent : .secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
