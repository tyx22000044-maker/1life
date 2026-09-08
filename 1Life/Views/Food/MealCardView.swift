import SwiftUI
import SwiftData

struct MealCardView: View {
    @Environment(\.modelContext) private var modelContext
    let meal: Meal

    @State private var isExpanded = true
    @State private var showAllItems = false
    @State private var isShowingAddFood = false
    @State private var isShowingDetail = false
    @State private var isShowingTemplatePrompt = false
    @State private var templateName = ""
    @State private var editingItem: FoodItem?

    private var items: [FoodItem] {
        (meal.foodItems ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// 整餐来自模板时显示的"大名"（模板名），从 note 中提取
    private var templateTitle: String? {
        let note = meal.note
        if note.hasPrefix("模板：") {
            let name = note.dropFirst("模板：".count)
                .components(separatedBy: " |").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? nil : name
        }
        if let start = note.range(of: "模板库「"),
           let end = note[start.upperBound...].firstIndex(of: "」") {
            let name = String(note[start.upperBound..<end])
            return name.isEmpty ? nil : name
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let thumb = meal.photoThumbnail, let img = UIImage(data: thumb) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .onTapGesture { isShowingDetail = true }
            }
            if isExpanded {
                foodItemsList
                    .onTapGesture { isShowingDetail = true }
            }
            addFoodButton
        }
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .sheet(isPresented: $isShowingDetail) {
            MealDetailSheet(meal: meal)
        }
        .sheet(isPresented: $isShowingAddFood) {
            AddFoodSheet(meal: meal)
        }
        .sheet(item: $editingItem) { item in
            EditFoodSheet(item: item)
        }
        .alert("保存到模板库", isPresented: $isShowingTemplatePrompt) {
            TextField("模板名称", text: $templateName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                saveAsTemplate()
            }
        } message: {
            Text("保存到模板库后，下次可以快速复用。模板名称由你自己填写。")
        }
        .contextMenu {
            Menu {
                ForEach(MealType.allCases) { type in
                    Button {
                        meal.mealType = type
                        HapticEngine.tap()
                    } label: {
                        Label(type.displayName, systemImage: type == meal.mealType ? "checkmark" : type.icon)
                    }
                }
            } label: {
                Label("更改餐次", systemImage: "arrow.triangle.swap")
            }
            Button {
                templateName = ""
                isShowingTemplatePrompt = true
            } label: {
                Label("保存到模板库", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                modelContext.delete(meal)
            } label: {
                Label("删除整餐", systemImage: "trash")
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: mealIcon)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(meal.mealType.displayName)
                            .font(.subheadline.weight(.bold))
                        SystemStatusBadge(text: sourceLabel, tone: meal.source == .manual ? .neutral : .accent)
                    }
                    if let templateTitle {
                        Text(templateTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FamilyUI.accent)
                            .lineLimit(1)
                    }
                    Text("\(meal.date.timeDisplay) / \(items.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(meal.totalCalories)) kcal")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private var foodItemsList: some View {
        VStack(spacing: 0) {
            let displayItems = showAllItems ? items : Array(items.prefix(5))
            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    SystemPanelDivider()
                        .padding(.leading, 16)
                }
                FoodItemRow(item: item, onEdit: {
                    editingItem = item
                }, onDelete: {
                    modelContext.delete(item)
                })
            }

            if items.count > 5 {
                Button {
                    withAnimation { showAllItems.toggle() }
                } label: {
                    Text(showAllItems ? "收起" : "还有 \(items.count - 5) 项")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FamilyUI.accent)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var addFoodButton: some View {
        HStack(spacing: 0) {
            Button {
                HapticEngine.tap()
                isShowingAddFood = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("添加食物")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(FamilyUI.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(FamilyUI.panelBorder)
                .frame(width: 1)

            Button {
                templateName = ""
                isShowingTemplatePrompt = true
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("存到模板库")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .background(FamilyUI.panelMutedBackground)
    }

    private var mealIcon: String {
        meal.mealType.icon
    }

    private var sourceLabel: String {
        switch meal.source {
        case .manual:
            return "MANUAL"
        case .aiText:
            return "AI TEXT"
        case .aiPhoto:
            return "AI PHOTO"
        }
    }

    private func saveAsTemplate() {
        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let snapshot = items.map {
            TemplateFoodItem(
                name: $0.name,
                amount: $0.amount,
                unit: $0.unit,
                servingGrams: $0.servingGrams,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fat: $0.fat,
                fiber: $0.fiber,
                sodium: $0.sodium,
                sugar: $0.sugar,
                cholesterol: $0.cholesterol,
                caffeine: $0.caffeine,
                teaPolyphenols: $0.teaPolyphenols,
                calcium: $0.calcium,
                magnesium: $0.magnesium,
                potassium: $0.potassium,
                iron: $0.iron,
                zinc: $0.zinc,
                vitaminA: $0.vitaminA,
                vitaminC: $0.vitaminC,
                vitaminD: $0.vitaminD,
                vitaminE: $0.vitaminE,
                vitaminB1: $0.vitaminB1,
                vitaminB2: $0.vitaminB2,
                niacin: $0.niacin,
                vitaminB6: $0.vitaminB6,
                folate: $0.folate,
                vitaminB12: $0.vitaminB12,
                nutritionDataBasisRaw: $0.nutritionDataBasisRaw,
                labelBaseAmount: $0.labelBaseAmount,
                labelBaseUnit: $0.labelBaseUnit,
                packageNetAmount: $0.packageNetAmount,
                packageNetUnit: $0.packageNetUnit,
                consumedAmount: $0.consumedAmount,
                consumedUnit: $0.consumedUnit,
                nutritionDataNote: $0.nutritionDataNote
            )
        }
        let template = MealTemplate(
            name: trimmedName,
            mealType: meal.mealType,
            foodItems: snapshot
        )
        modelContext.insert(template)
        HapticEngine.success()
    }
}
