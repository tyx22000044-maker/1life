import SwiftUI

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
                    if case .meals(let meals) = confirmation.identificationType, meals.count > 1 {
                        Text("共 \(meals.count) 餐，确认后将一起写入；手动编辑只修改第 1 餐。")
                            .font(FamilyTypography.text(size: 11, weight: .medium))
                            .foregroundStyle(FamilyUI.inkSoft)
                    }
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
                // A batch review holds several meals; naming one template for all of them
                // would be ambiguous, so the action only appears for a single meal.
                if case .meal = confirmation.identificationType {
                    Button {
                        HapticEngine.tap()
                        onSaveAsTemplate()
                    } label: {
                        Label("存到模板库", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }

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
