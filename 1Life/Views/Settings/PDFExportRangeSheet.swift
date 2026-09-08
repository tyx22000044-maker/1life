import SwiftUI

struct PDFExportRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    let isExporting: Bool
    let progressText: String
    let onExport: () -> Void

    private var clampedEndBinding: Binding<Date> {
        Binding(
            get: { endDate },
            set: { newValue in
                endDate = newValue
                if endDate < startDate {
                    startDate = endDate
                }
            }
        )
    }

    private var clampedStartBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newValue in
                startDate = newValue
                if startDate > endDate {
                    endDate = startDate
                }
            }
        )
    }

    private var dayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "PDF 导出",
                        title: "导出报告",
                        detail: "生成每日营养与训练摘要的 PDF 报告"
                    )

                    SystemPanel(title: "日期范围", detail: "选择要导出的报告日期范围") {
                        HStack {
                            Text("日期范围")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                            Spacer()
                            SystemStatusBadge(text: "\(max(dayCount, 1)) 天", tone: .accent)
                        }

                        DatePicker("开始日期", selection: clampedStartBinding, displayedComponents: .date)
                        SystemPanelDivider()
                        DatePicker("结束日期", selection: clampedEndBinding, displayedComponents: .date)
                    }

                    SystemPanel(title: "报告内容", detail: "PDF 将包含每日营养与训练摘要") {
                        HStack {
                            Text("报告内容")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                            Spacer()
                            SystemStatusBadge(text: "紧凑", tone: .neutral)
                        }

                        Text("按天生成紧凑 PDF 报告，每天一页，包含热量差、蛋白/碳水/脂肪/饮水达标情况、当天餐次卡片和训练摘要。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("适合分享、归档或自己复盘。信息密度高，但会保持清晰卡片层级。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isExporting {
                        SystemPanel(title: "正在导出", detail: "多日 PDF 生成可能需要一些时间") {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(FamilyUI.accent)
                                Text(progressText.isEmpty ? "正在生成 PDF" : progressText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("导出 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isExporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") {
                        onExport()
                    }
                    .disabled(isExporting)
                }
            }
        }
    }
}
