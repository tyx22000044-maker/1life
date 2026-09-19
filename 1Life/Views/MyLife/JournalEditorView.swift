import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var entry: JournalEntry?

    @State private var content = ""
    @State private var selectedMood: Mood?
    @State private var selectedTags: Set<ActivityTag> = []
    @State private var selectedDate = Date.now
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var didLoadEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "状态记录",
                        title: entry == nil ? "记录状态" : "编辑状态",
                        detail: "记录心情、背景、照片和当天复盘。"
                    )

                    SystemPanel {
                        editorHeader("快速复盘", value: "\(reviewTemplates.count) 个模板")
                        FlowLayout(spacing: 8) {
                            ForEach(reviewTemplates) { template in
                                Button {
                                    applyTemplate(template)
                                } label: {
                                    Label(template.title, systemImage: template.icon)
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(FamilyUI.panelMutedBackground)
                                        .foregroundStyle(.primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                                }
                            }
                        }
                    }

                    // Mood
                    SystemPanel {
                        editorHeader("心情", value: selectedMood?.displayName ?? "可选")
                        HStack(spacing: 12) {
                            ForEach(Mood.allCases) { mood in
                                Button {
                                    HapticEngine.tap()
                                    selectedMood = selectedMood == mood ? nil : mood
                                } label: {
                                    Text(mood.emoji)
                                        .font(.title2)
                                        .padding(8)
                                        .background(selectedMood == mood ? FamilyUI.accent.opacity(0.12) : FamilyUI.panelMutedBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                                }
                            }
                        }
                    }

                    // Tags
                    SystemPanel {
                        editorHeader("影响因素", value: "已选 \(selectedTags.count) 个")
                        FlowLayout(spacing: 8) {
                            ForEach(ActivityTag.allCases) { tag in
                                Button {
                                    HapticEngine.tap()
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                } label: {
                                    Text(tag.displayName)
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedTags.contains(tag) ? FamilyUI.accent.opacity(0.12) : FamilyUI.panelMutedBackground)
                                        .foregroundStyle(selectedTags.contains(tag) ? FamilyUI.accent : .primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                                }
                            }
                        }
                    }

                    // Content
                    SystemPanel {
                        editorHeader("状态", value: content.isEmpty ? "必填" : "可保存")
                        markdownToolbar
                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                        Text("支持 **粗体**、*斜体*、- 列表、> 引用，详情页自动渲染")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Photos
                    SystemPanel {
                        editorHeader("照片", value: "\(photoDataList.count)/9")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoDataList.indices, id: \.self) { i in
                                    if let img = UIImage(data: photoDataList[i]) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: img)
                                                .resizable().scaledToFill()
                                                .frame(width: 72, height: 72)
                                                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                                )

                                            Button {
                                                photoDataList.remove(at: i)
                                                HapticEngine.tap()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .accessibilityLabel("移除这张照片")
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(.white, .black.opacity(0.55))
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                    }
                                }

                                if photoDataList.count < 9 {
                                    PhotosPicker(
                                        selection: $selectedPhotos,
                                        maxSelectionCount: 9 - photoDataList.count,
                                        matching: .images
                                    ) {
                                        VStack {
                                            Image(systemName: "plus")
                                                .font(.title3)
                                        }
                                        .frame(width: 72, height: 72)
                                        .background(FamilyUI.panelMutedBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                                    }
                                    .onChange(of: selectedPhotos) { _, items in
                                        Task {
                                            for item in items {
                                                if let data = try? await item.loadTransferable(type: Data.self) {
                                                    photoDataList.append(data)
                                                }
                                            }
                                            selectedPhotos = []
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Date
                    SystemPanel {
                        editorHeader("日期", value: selectedDate.dayDisplay)
                        DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(entry == nil ? "记录状态" : "编辑状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadEntryIfNeeded)
        }
    }

    private var markdownToolbar: some View {
        HStack(spacing: 6) {
            ForEach(MarkdownShortcut.allCases) { shortcut in
                Button {
                    applyMarkdown(shortcut)
                } label: {
                    Image(systemName: shortcut.icon)
                        .accessibilityLabel(shortcut.label)
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 28)
                        .background(FamilyUI.panelMutedBackground)
                        .foregroundStyle(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }
            Spacer()
        }
    }

    private func applyMarkdown(_ shortcut: MarkdownShortcut) {
        HapticEngine.tap()
        switch shortcut {
        case .bold:
            content += "****"
        case .italic:
            content += "*"
        case .list:
            let prefix = content.hasSuffix("\n") || content.isEmpty ? "- " : "\n- "
            content += prefix
        case .quote:
            let prefix = content.hasSuffix("\n") || content.isEmpty ? "> " : "\n> "
            content += prefix
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

    private func save() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetEntry: JournalEntry
        if let entry {
            targetEntry = entry
            targetEntry.date = selectedDate
            targetEntry.mood = selectedMood
            targetEntry.tags = selectedTags.map(\.rawValue)
            targetEntry.content = trimmedContent
            targetEntry.updatedAt = .now
            (targetEntry.photos ?? []).forEach { modelContext.delete($0) }
            targetEntry.photos = []
        } else {
            targetEntry = JournalEntry(
                date: selectedDate,
                mood: selectedMood,
                tags: selectedTags.map(\.rawValue),
                content: trimmedContent
            )
            modelContext.insert(targetEntry)
        }

        for (index, data) in photoDataList.enumerated() {
            let compressed = ImageService.compress(data) ?? data
            let photo = JournalPhoto(
                photoData: compressed,
                thumbnailData: ImageService.thumbnail(compressed) ?? compressed,
                sortOrder: index
            )
            photo.journalEntry = targetEntry
            modelContext.insert(photo)
        }

        HapticEngine.success()
        dismiss()
    }

    private var reviewTemplates: [JournalReviewTemplate] {
        [
            JournalReviewTemplate(title: "压力饮食", icon: "brain.head.profile", content: "今天压力：\n饮食影响：\n身体感受：", tags: [.stress]),
            JournalReviewTemplate(title: "睡眠状态", icon: "moon.fill", content: "昨晚睡眠：\n今天精力：\n食欲变化：", tags: [.sleep]),
            JournalReviewTemplate(title: "外食复盘", icon: "fork.knife", content: "今天外食：\n选择原因：\n下次可调整：", tags: [.diningOut]),
            JournalReviewTemplate(title: "运动日", icon: "figure.run", content: "今天运动：\n训练后饥饿感：\n补充营养：", tags: [.exercise]),
            JournalReviewTemplate(title: "经期状态", icon: "heart.fill", content: "今天状态：\n食欲/水肿：\n需要照顾：", tags: [.period]),
            JournalReviewTemplate(title: "游戏/娱乐", icon: "gamecontroller.fill", content: "今天玩了：\n时长：\n身体感受（久坐/眼疲劳）：", tags: [.gaming])
        ]
    }

    private func applyTemplate(_ template: JournalReviewTemplate) {
        content = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? template.content
            : content + "\n\n" + template.content
        selectedTags.formUnion(template.tags)
        HapticEngine.tap()
    }

    private func loadEntryIfNeeded() {
        guard !didLoadEntry, let entry else { return }
        didLoadEntry = true
        content = entry.content
        selectedMood = entry.mood
        selectedTags = Set(entry.activityTags)
        selectedDate = entry.date
        photoDataList = (entry.photos ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.photoData)
    }
}

private enum MarkdownShortcut: CaseIterable, Identifiable {
    case bold, italic, list, quote
    var id: Self { self }
    var icon: String {
        switch self {
        case .bold:   return "bold"
        case .italic: return "italic"
        case .list:   return "list.bullet"
        case .quote:  return "text.quote"
        }
    }

    var label: String {
        switch self {
        case .bold:   return "加粗"
        case .italic: return "斜体"
        case .list:   return "无序列表"
        case .quote:  return "引用"
        }
    }
}

private struct JournalReviewTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let content: String
    let tags: Set<ActivityTag>
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
