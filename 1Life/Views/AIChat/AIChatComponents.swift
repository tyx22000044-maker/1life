import SwiftUI
import UIKit

struct AIConfigurationHeader: View {
    let status: AIConfigurationStatus?
    let isConfigured: Bool
    let errorMessage: String?
    let providerOptions: [AIProviderOption]
    let selectedProvider: AIProvider
    let selectedModel: String
    let onSelectProvider: (AIProvider) -> Void
    let onSelectModel: (String) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: isConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(FamilyTypography.text(size: 14, weight: .bold))
                        .foregroundStyle(isConfigured ? FamilyUI.success : FamilyUI.warning)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("AI 配置")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                    SystemStatusBadge(text: isConfigured ? "已启用" : "待配置", tone: isConfigured ? .success : .warning)
                }
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Section("服务商") {
                    ForEach(providerOptions) { option in
                        Button {
                            onSelectProvider(option.provider)
                        } label: {
                            providerOptionRow(option)
                        }
                    }
                }
                if !selectedProviderModels.isEmpty {
                    Section("模型") {
                        ForEach(selectedProviderModels, id: \.self) { model in
                            Button {
                                onSelectModel(model)
                            } label: {
                                modelOptionRow(model)
                            }
                        }
                    }
                }
                Divider()
                Button("AI 设置", action: onOpenSettings)
            } label: {
                Label("切换", systemImage: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.vertical, 12)
        .background(FamilyUI.pageBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FamilyUI.panelBorder)
                .frame(height: 1)
        }
    }

    private var selectedProviderModels: [String] {
        providerOptions.first { $0.provider == selectedProvider }?.models ?? []
    }

    private var detailText: String {
        if let errorMessage { return errorMessage }
        guard let status else { return "请先选择服务商并保存 API Key" }
        return "\(status.provider.displayName) · \(status.model) · \(status.maskedKey)"
    }

    private func providerOptionRow(_ option: AIProviderOption) -> some View {
        HStack(spacing: 8) {
            Image(systemName: option.provider == selectedProvider ? "checkmark.circle.fill" : "circle")
            Text(option.displayName)
        }
    }

    private func modelOptionRow(_ model: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: model == selectedModel ? "checkmark.circle.fill" : "circle")
            Text(model)
        }
    }
}

struct AIRequestProgressView: View {
    let elapsedSeconds: Int
    let hasImages: Bool

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Text(statusDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            SystemStatusBadge(text: statusBadge, tone: .neutral)
        }
        .padding(12)
        .background(FamilyUI.panelMutedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
    }

    private var statusTitle: String {
        if hasImages {
            if elapsedSeconds < 20 { return "正在读取图片" }
            if elapsedSeconds < 45 { return "正在整理营养信息" }
            return "正在生成确认结果"
        }
        if elapsedSeconds < 12 { return "正在理解记录" }
        if elapsedSeconds < 30 { return "正在估算营养" }
        return "正在整理确认结果"
    }

    private var statusDetail: String {
        if hasImages {
            if elapsedSeconds < 20 { return "OCR 识别食物、标签和份量线索" }
            if elapsedSeconds < 45 { return "换算热量、宏量素和可用营养字段" }
            return "结果较复杂，请继续等待一下"
        }
        if elapsedSeconds < 12 { return "识别餐次、日期、食物和动作意图" }
        if elapsedSeconds < 30 { return "补齐热量、蛋白、碳水、脂肪等字段" }
        return "结果较复杂，请继续等待一下"
    }

    private var statusBadge: String {
        if hasImages {
            if elapsedSeconds < 20 { return "OCR" }
            if elapsedSeconds < 45 { return "解析" }
            return "生成"
        }
        if elapsedSeconds < 12 { return "理解" }
        if elapsedSeconds < 30 { return "估算" }
        return "生成"
    }
}

struct AIEmptyStateContent: View {
    let isConfigured: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SystemPanel {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .fill(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(FamilyTypography.text(size: 22, weight: .black))
                                .foregroundStyle(FamilyUI.accent)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        SystemStatusBadge(text: isConfigured ? "AI 已就绪" : "待配置", tone: isConfigured ? .success : .warning)
                        Text("AI 健康助手")
                            .font(.title3.weight(.black))
                        Text("记录饮食、喝水、训练、排便和日记，再帮你分析摄入、消耗与营养目标。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !isConfigured {
                AISetupNoticeCard(
                    title: "完整 AI 能力未启用",
                    message: "配置服务商和 API Key 后，可使用拍照识别、营养分析和更准确的自然语言记录。",
                    actionTitle: "前往设置配置 AI",
                    onOpenSettings: onOpenSettings
                )
            }

            VStack(spacing: 10) {
                FeatureCard(icon: "camera.fill", title: "拍照识别", desc: "拍张照片，AI 分析食物和营养")
                FeatureCard(icon: "fork.knife", title: "记录饮食", desc: "用自然语言描述你吃了什么")
                FeatureCard(icon: "chart.bar.fill", title: "营养分析", desc: "了解摄入、消耗和目标差距")
                FeatureCard(icon: "figure.run", title: "训练复盘", desc: "结合运动、饥饿感和补充营养")
                FeatureCard(icon: "heart.text.square.fill", title: "生活记录", desc: "记录排便、心情、压力、睡眠和日记")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct AISetupNoticeCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FamilyUI.accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: onOpenSettings)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.warning.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: icon)
                        .font(FamilyTypography.text(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

struct ChatBubble: View {
    let message: AIChatMessage
    var onUndo: ((AIChatMessage) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == "user" { Spacer() }

            if message.toolName == "add_meal", let payload = message.decodedBubblePayload {
                MealBubbleCard(payload: payload) {
                    onUndo?(message)
                }
            } else {
                ChatBubbleContent(content: message.content, isUser: message.role == "user")
                    .frame(maxWidth: 280, alignment: message.role == "user" ? .trailing : .leading)
            }

            if message.role != "user" { Spacer() }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = copyText
                HapticEngine.success()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
        .padding(.horizontal, 2)
    }

    private var copyText: String {
        if message.toolName == "add_meal", let payload = message.decodedBubblePayload {
            let mealType = MealType(rawValue: payload.mealType)?.displayName ?? payload.mealType
            let status = payload.isRevoked == true ? "已撤销" : "已记录"
            let items = payload.items
                .map { "\($0.name) \(Int($0.calories)) kcal" }
                .joined(separator: "，")
            return "\(status)：\(mealType) \(Int(payload.totalCalories)) kcal\(items.isEmpty ? "" : "（\(items)）")"
        }
        return message.content
            .split(separator: "\n")
            .filter { !$0.hasPrefix("[图片") && !$0.hasPrefix("[照片") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct MealBubbleCard: View {
    let payload: AIChatBubblePayload
    let onUndo: () -> Void

    private var isRevoked: Bool { payload.isRevoked == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SystemStatusBadge(text: isRevoked ? "已撤销" : "已记录", tone: isRevoked ? .danger : .success)
                Spacer()
                Text("\(Int(payload.totalCalories)) kcal")
                    .font(.headline.weight(.black))
                    .foregroundStyle(isRevoked ? .secondary : FamilyUI.accent)
                    .monospacedDigit()
            }

            Text(MealType(rawValue: payload.mealType)?.displayName ?? payload.mealType)
                .font(.subheadline.weight(.bold))

            ForEach(payload.items, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.caption)
                    Spacer()
                    Text("\(Int(item.calories)) kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isRevoked {
                Text("已撤销")
                    .font(.caption2)
                    .foregroundStyle(FamilyUI.danger)
            } else {
                Button {
                    onUndo()
                } label: {
                    Text("撤销")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FamilyUI.danger)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(isRevoked ? FamilyUI.panelMutedBackground : FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        .opacity(isRevoked ? 0.6 : 1)
    }
}

private struct ChatBubbleContent: View {
    let content: String
    let isUser: Bool

    private var hasImageAttachment: Bool {
        content.contains("[图片") || content.contains("[照片")
    }

    private var displayText: String {
        content
            .split(separator: "\n")
            .filter { !$0.hasPrefix("[图片") && !$0.hasPrefix("[照片") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !displayText.isEmpty {
                Text(displayText)
                    .font(.subheadline)
            }

            if hasImageAttachment {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.caption.weight(.semibold))
                    Text("图片附件")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isUser ? Color.white.opacity(0.16) : FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                        .stroke(isUser ? Color.white.opacity(0.22) : FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isUser ? Color.black : FamilyUI.panelBackground)
        .foregroundStyle(isUser ? Color.white : Color.primary)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(isUser ? Color.black : FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

/// Names a meal review result before it is saved into the template library.
struct SaveTemplateFromReviewSheet: View {
    @Binding var name: String
    var onSave: () -> Void
    var onCancel: () -> Void

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                SystemPanel(title: "模板名称") {
                    TextField("例如：健身房午餐", text: $name)
                        .font(FamilyTypography.text(size: 16, weight: .medium))
                        .foregroundStyle(FamilyUI.ink)
                        .padding(12)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            Rectangle()
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .accessibilityLabel("模板名称")
                }

                Text("保存后可以直接说“吃了这个名字”，按同一份份量和营养记录，不需要重新识别。")
                    .font(FamilyTypography.text(size: 12))
                    .foregroundStyle(FamilyUI.inkSoft)

                Button(action: onSave) {
                    Text("保存")
                        .font(FamilyTypography.button)
                        .foregroundStyle(FamilyUI.pageBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isNameValid ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                        .overlay(
                            Rectangle()
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isNameValid)

                Button("取消", role: .cancel, action: onCancel)
                    .font(FamilyTypography.text(size: 14, weight: .semibold))
                    .foregroundStyle(FamilyUI.inkSoft)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(18)
            .background(FamilyUI.pageBackground)
            .navigationTitle("存到模板库")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
