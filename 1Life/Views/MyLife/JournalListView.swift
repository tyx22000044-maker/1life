import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct JournalListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)])
    private var entries: [JournalEntry]

    @State private var isShowingEditor = false
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var filterMood: Mood?
    @State private var filterTag: ActivityTag?

    private var filteredEntries: [JournalEntry] {
        entries.filter { entry in
            if !debouncedSearchText.isEmpty {
                guard entry.content.localizedCaseInsensitiveContains(debouncedSearchText) else { return false }
            }
            if let filterMood {
                guard entry.mood == filterMood else { return false }
            }
            if let filterTag {
                guard entry.tags.contains(filterTag.rawValue) else { return false }
            }
            return true
        }
    }

    private func groupedEntries(from entries: [JournalEntry]) -> [(date: Date, entries: [JournalEntry])] {
        let groups = Dictionary(grouping: entries) { $0.date.startOfDay }
        return groups
            .map { (date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let visibleEntries = filteredEntries
        let visibleGroups = groupedEntries(from: visibleEntries)

        SystemPanel {
            HStack {
                SystemStatusBadge(text: "JOURNAL \(entries.count)", tone: entries.isEmpty ? .warning : .accent)
                Spacer()
                Button {
                    HapticEngine.tap()
                    isShowingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("新建日志")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            }

            if !entries.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索状态记录", text: $searchText)
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .accessibilityLabel("移除照片")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "全部", isSelected: filterMood == nil && filterTag == nil) {
                            filterMood = nil; filterTag = nil
                        }
                        ForEach(Mood.allCases) { mood in
                            FilterChip(title: mood.emoji, isSelected: filterMood == mood) {
                                filterMood = filterMood == mood ? nil : mood
                                filterTag = nil
                            }
                        }
                        ForEach(ActivityTag.allCases) { tag in
                            FilterChip(title: tag.displayName, isSelected: filterTag == tag) {
                                filterTag = filterTag == tag ? nil : tag
                                filterMood = nil
                            }
                        }
                    }
                }
            }

            if visibleEntries.isEmpty {
                Button {
                    isShowingEditor = true
                } label: {
                    HStack {
                        Image(systemName: "pencil.line")
                            .accessibilityLabel("编辑这篇日志")
                            .foregroundStyle(.secondary)
                        Text("记录今天的状态")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
            } else {
                ForEach(visibleGroups, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.date.sectionHeaderDisplay)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(group.entries) { entry in
                            NavigationLink {
                                JournalDetailView(entry: entry)
                            } label: {
                                JournalRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            JournalEditorView()
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

private struct JournalRow: View {
    let entry: JournalEntry

    private var sortedPhotos: [JournalPhoto] {
        (entry.photos ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let thumbnail = sortedPhotos.first?.thumbnailData, let image = UIImage(data: thumbnail) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                    .overlay(alignment: .bottomTrailing) {
                        if entry.photoCount > 1 {
                            Text("+\(entry.photoCount - 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.date.timeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let mood = entry.mood {
                        Text(mood.emoji)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(entry.content)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.activityTags.prefix(3)) { tag in
                            Text(tag.displayName)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FamilyUI.panelMutedBackground)
                                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                        }
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

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? FamilyUI.accent.opacity(0.12) : FamilyUI.panelMutedBackground)
                .foregroundStyle(isSelected ? FamilyUI.accent : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
        }
    }
}
