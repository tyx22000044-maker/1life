import SwiftUI

enum FoodHintTone {
    case accent
    case neutral
    case warning
    case danger
}

private struct MealTypeNutritionSnapshot {
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double

    init(meals: [Meal]) {
        var totalCalories = 0.0
        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0

        for meal in meals {
            for item in meal.foodItems ?? [] {
                totalCalories += item.calories
                totalProtein += item.protein ?? 0
                totalCarbs += item.carbs ?? 0
                totalFat += item.fat ?? 0
            }
        }

        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
    }
}

struct MealTypeSection: View {
    let type: MealType
    let meals: [Meal]
    let onAdd: () -> Void

    var body: some View {
        let nutrition = MealTypeNutritionSnapshot(meals: meals)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                    .fill(FamilyUI.panelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                    .overlay(
                        Image(systemName: type.icon)
                            .font(FamilyTypography.text(size: 15, weight: .bold))
                            .foregroundStyle(FamilyUI.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(type.displayName)
                            .font(.subheadline.weight(.black))
                        SystemStatusBadge(text: meals.isEmpty ? "未记录" : "\(Int(nutrition.totalCalories)) kcal", tone: meals.isEmpty ? .neutral : .accent)
                    }
                    Text("蛋白 \(Int(nutrition.totalProtein))g / 碳水 \(Int(nutrition.totalCarbs))g / 脂肪 \(Int(nutrition.totalFat))g")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                }
                .buttonStyle(.plain)
            }

            if !meals.isEmpty {
                MacroRatioBar(protein: nutrition.totalProtein, carbs: nutrition.totalCarbs, fat: nutrition.totalFat)
            }

            if meals.isEmpty {
                Button(action: onAdd) {
                    HStack {
                        Text("记录\(type.displayName)")
                            .font(.caption.weight(.bold))
                        Spacer()
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(meals) { meal in
                        MealCardView(meal: meal)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MacroRatioBar: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private var proteinCalories: Double { protein * 4 }
    private var carbsCalories: Double { carbs * 4 }
    private var fatCalories: Double { fat * 9 }
    private var total: Double { proteinCalories + carbsCalories + fatCalories }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FamilyUI.info)
                        .frame(width: width(for: proteinCalories, totalWidth: proxy.size.width))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FamilyUI.success)
                        .frame(width: width(for: carbsCalories, totalWidth: proxy.size.width))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FamilyUI.accent)
                        .frame(width: width(for: fatCalories, totalWidth: proxy.size.width))
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                ratioLabel("蛋白", value: proteinCalories, color: FamilyUI.info)
                ratioLabel("碳水", value: carbsCalories, color: FamilyUI.success)
                ratioLabel("脂肪", value: fatCalories, color: FamilyUI.accent)
            }
        }
    }

    private func width(for value: Double, totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return totalWidth / 3 }
        return max(totalWidth * value / total, 6)
    }

    private func ratioLabel(_ title: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title) \(percent(value))%")
                .font(FamilyTypography.text(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ value: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((value / total * 100).rounded())
    }
}

struct MacroSummaryTile: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(Int(value))\(unit)")
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(color)
            ProgressView(value: progress)
                .tint(color)
            Text("目标 \(Int(target))\(unit)")
                .font(FamilyTypography.text(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
}

struct QuickFoodChip: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .fill(color.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 188, alignment: .leading)
        .padding(10)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }
}
