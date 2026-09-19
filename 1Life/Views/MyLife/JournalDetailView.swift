import Foundation
import SwiftUI
import SwiftData
import UIKit

struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: JournalEntry

    @State private var isEditing = false
    @State private var showDeleteAlert = false

    private var sortedPhotos: [JournalPhoto] {
        (entry.photos ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "JOURNAL DETAIL",
                    title: entry.date.dayDisplay,
                    detail: entry.date.timeDisplay
                )

                SystemPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        SystemStatusBadge(text: "STATE ENTRY", tone: .accent)
                        Spacer()
                        if let mood = entry.mood {
                            Text(mood.emoji)
                                .font(.title3)
                        }
                    }

                    if !entry.activityTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(entry.activityTags) { tag in
                                Text(tag.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(FamilyUI.panelMutedBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                            }
                        }
                    }

                    if let attributed = try? AttributedString(markdown: entry.content) {
                        Text(attributed)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(entry.content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !sortedPhotos.isEmpty {
                    SystemPanel(title: "PHOTOS", detail: "\(sortedPhotos.count) images") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(sortedPhotos) { photo in
                            if let image = UIImage(data: photo.photoData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 112)
                                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                            }
                        }
                    }
                }
            }

                SystemPanel {
                    Button {
                        isEditing = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("编辑日志")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除日志")
                            Spacer()
                        }
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle("状态详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            JournalEditorView(entry: entry)
        }
        .alert("删除日志", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                modelContext.delete(entry)
                HapticEngine.warning()
                dismiss()
            }
        } message: {
            Text("将同时删除这条状态记录的照片，此操作不可恢复。")
        }
    }
}
