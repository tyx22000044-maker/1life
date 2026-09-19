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
                    subtitle: "PDF 与 CSV 是分析产物：日期时间为本机时区、数值统一用 en_US_POSIX 小数点；只有完整备份 (JSON) 能恢复数据",
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
                    iconColor: FamilyUI.danger,
                    title: "清空所有数据",
                    subtitle: "删除饮食、饮水、习惯、日志与照片、训练、身体与排便记录、我的食物与模板、饮品/补剂知识库、聊天历史和 AI Key",
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
                Text("此操作会删除本机全部记录（含照片数据）、重置偏好、取消待发送通知并移除 AI API Key，且不可恢复。iCloud 不提供任何备份。")
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
                Text("最后确认：数据将被永久删除，只有已经导出的 JSON 备份可以恢复。")
            }
        }
    }
}
