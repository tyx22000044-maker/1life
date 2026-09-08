import SwiftUI

struct FoodItemRow: View {
    let item: FoodItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if item.source == .ai {
                            SystemStatusBadge(text: "AI", tone: .accent)
                        }
                    }

                    HStack(spacing: 10) {
                        if item.amount > 0 {
                            Text("\(item.amount.nutritionDecimal)\(item.unit)")
                        }
                        if let p = item.protein {
                            Text("蛋白 \(p.nutritionDecimal)g")
                        }
                        if let c = item.carbs {
                            Text("碳水 \(c.nutritionDecimal)g")
                        }
                        if let f = item.fat {
                            Text("脂肪 \(f.nutritionDecimal)g")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(item.calories)) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("删除食物", systemImage: "trash")
            }
        }
    }
}
