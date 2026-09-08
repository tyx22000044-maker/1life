import SwiftUI

struct SettingsDataSection: View {
    let mealCount: Int
    let workoutCount: Int
    @Binding var isShowingExportPicker: Bool
    @Binding var isShowingImportPicker: Bool
    @Binding var isShowingPDFExportSheet: Bool
    @Binding var clearDataStep: Int
    let preparePDFExportRange: () -> Void
    let exportCSV: (ExportService.CSVGranularity) -> Void
    let exportJSON: () -> Void
    let exportWorkoutCSV: () -> Void
    let exportWorkoutJSON: () -> Void
    let clearAllData: () -> Void

    var body: some View {
        SystemPanel(title: "数据与同步", detail: "本机数据、备份恢复与后续同步能力") {
            HStack(alignment: .top, spacing: 12) {
                AppSettingsRow(
                    icon: "icloud",
                    title: "iCloud 同步",
                    subtitle: "当前版本仅保存到本机，跨设备同步后续推出"
                )
                SystemStatusBadge(text: "后续推出", tone: .neutral)
            }

            SystemPanelDivider()

            Button {
                isShowingExportPicker = true
            } label: {
                AppSettingsRow(
                    icon: "square.and.arrow.up",
                    title: "导出数据",
                    subtitle: "支持 PDF、CSV 与完整 JSON 备份",
                    value: "\(mealCount) 餐 · \(workoutCount) 次",
                    emphasizesValue: true
                )
            }
            .buttonStyle(.plain)
            .confirmationDialog("选择导出格式", isPresented: $isShowingExportPicker) {
                Button("精美营养报告 (PDF)") {
                    preparePDFExportRange()
                    isShowingPDFExportSheet = true
                }
                Button("食物明细 (CSV)") { exportCSV(.detail) }
                Button("每日汇总 (CSV)") { exportCSV(.dailySummary) }
                Button("完整备份 (JSON)") { exportJSON() }
                Button("训练明细 (CSV)") { exportWorkoutCSV() }
                Button("训练数据 (JSON)") { exportWorkoutJSON() }
                Button("取消", role: .cancel) {}
            }

            SystemPanelDivider()

            Button {
                isShowingImportPicker = true
            } label: {
                AppSettingsRow(
                    icon: "square.and.arrow.down",
                    title: "导入 JSON 备份",
                    subtitle: "用已导出的完整备份覆盖当前本机数据",
                    value: "覆盖导入"
                )
            }
            .buttonStyle(.plain)

            SystemPanelDivider()

            Button(role: .destructive) {
                clearDataStep = 1
            } label: {
                AppSettingsRow(
                    icon: "trash",
                    iconColor: .red,
                    title: "清空所有数据",
                    subtitle: "删除饮食、习惯、日志、模板和聊天历史",
                    value: "不可恢复"
                )
            }
            .buttonStyle(.plain)
            .alert("清空所有数据", isPresented: Binding(
                get: { clearDataStep == 1 },
                set: { if !$0 { clearDataStep = 0 } }
            )) {
                Button("取消", role: .cancel) { clearDataStep = 0 }
                Button("继续", role: .destructive) { clearDataStep = 2 }
            } message: {
                Text("此操作将删除所有饮食记录、习惯、状态记录和设置，且不可恢复。")
            }
            .alert("确认清空", isPresented: Binding(
                get: { clearDataStep == 2 },
                set: { if !$0 { clearDataStep = 0 } }
            )) {
                Button("取消", role: .cancel) { clearDataStep = 0 }
                Button("清空所有数据", role: .destructive) {
                    HapticEngine.warning()
                    clearAllData()
                    clearDataStep = 0
                }
            } message: {
                Text("最后确认：所有数据将被永久删除。")
            }
        }
    }
}
