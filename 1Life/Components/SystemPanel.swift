import SwiftUI

struct SystemPageHeader: View {
    let eyebrow: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(FamilyTypography.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(FamilyTypography.pageTitle)
                .monospacedDigit()
                .foregroundStyle(.primary)

            if let detail {
                Text(detail)
                .font(.custom("Archivo-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(FamilyUI.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SystemPanel<Content: View>: View {
    let title: String?
    let detail: String?
    let content: Content

    init(title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    init(@ViewBuilder content: () -> Content) {
        self.title = nil
        self.detail = nil
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(FamilyTypography.sectionLabel)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    if let detail {
                        Text(detail)
                            .font(.custom("Archivo-Regular", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(FamilyUI.inkSoft)
                    }
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

struct SystemPanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(FamilyUI.divider)
            .frame(height: 1)
    }
}

struct SystemStatusBadge: View {
    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case danger

        var foreground: Color {
            switch self {
            case .neutral:
                return FamilyUI.ink
            case .accent:
                return FamilyUI.accent
            case .success:
                return FamilyUI.success
            case .warning:
                return FamilyUI.warning
            case .danger:
                return FamilyUI.danger
            }
        }
    }

    let text: String
    var tone: Tone = .neutral

    // Swiss Ledger tag: outlined rectangle, uppercase, tracked — no fill.
    var body: some View {
        Text(text.uppercased())
            .font(FamilyTypography.badge)
            .tracking(0.6)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .overlay(
                Rectangle()
                    .stroke(tone.foreground, lineWidth: 1)
            )
    }
}
