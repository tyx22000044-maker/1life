import SwiftUI

enum AppBannerTone: Equatable {
    case error
    case warning
    case success

    var foreground: Color {
        FamilyUI.buttonForeground
    }

    var background: Color {
        switch self {
        case .error:
            return FamilyUI.danger.opacity(0.94)
        case .warning:
            return FamilyUI.warning.opacity(0.96)
        case .success:
            return FamilyUI.success.opacity(0.96)
        }
    }

    var icon: String {
        switch self {
        case .error:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        }
    }
}

struct AppErrorBanner: View {
    let title: String
    var message: String?
    var tone: AppBannerTone = .error
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack {
            if isVisible {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(FamilyUI.onSolidOverlay)
                        .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                        .overlay(
                            Image(systemName: tone.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(tone.foreground)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tone.foreground)
                        if let message, !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(tone.foreground.opacity(0.84))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        dismiss()
                    } label: {
                            Image(systemName: "xmark")
                                .accessibilityLabel("关闭提示")
                                .font(.caption.weight(.black))
                                .foregroundStyle(tone.foreground.opacity(0.78))
                                .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(tone.background)
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.74), value: isVisible)
        .onAppear {
            isVisible = true
            autoDismissAfter(4)
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.18)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDismiss()
        }
    }

    private func autoDismissAfter(_ seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard isVisible else { return }
            dismiss()
        }
    }
}

/// Non-dismissible warning shown while the app runs on the in-memory fallback store.
/// Nothing typed in this session survives quitting, so the user must know before recording.
struct MemoryStoreWarningBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FamilyUI.danger)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text("本机数据库打不开，现在是临时内存库")
                    .font(FamilyTypography.text(size: 14, weight: .bold))
                    .foregroundStyle(FamilyUI.ink)
                Text("已有的记录还在原文件里，但本次新增和修改在退出后会丢失。可以先从 设置 → 从 JSON 备份恢复 载入最近的备份，或彻底关闭 App 后重新打开再试。")
                    .font(FamilyTypography.text(size: 12))
                    .foregroundStyle(FamilyUI.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(FamilyUI.panelBackground)
        .overlay(
            Rectangle()
                .stroke(FamilyUI.danger, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}
