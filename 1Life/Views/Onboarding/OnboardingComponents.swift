import SwiftUI

struct OnboardingHeader: View {
    let stepNum: Int
    let onBack: () -> Void
    private let total = 8

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { HapticEngine.tap(); onBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                Spacer()
                SystemStatusBadge(text: "STEP \(stepNum) / \(total)", tone: .neutral)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(FamilyUI.divider)
                    Rectangle()
                        .fill(FamilyUI.accent)
                        .frame(width: proxy.size.width * min(Double(stepNum) / Double(total), 1))
                }
            }
            .frame(height: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

struct OnboardingPageHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(FamilyTypography.text(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(FamilyTypography.text(size: 32, weight: .black))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingBottomBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Rectangle()
                .fill(FamilyUI.panelBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(FamilyUI.panelBorder)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct OnboardingIconBox: View {
    let icon: String
    var tone: Color = FamilyUI.accent

    var body: some View {
        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
            .fill(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
            .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
            .overlay(
                Image(systemName: icon)
                    .font(FamilyTypography.text(size: 14, weight: .semibold))
                    .foregroundStyle(tone)
            )
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticEngine.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingMetricInput: View {
    let label: String
    @Binding var text: String
    let unit: String
    var keyboard: UIKeyboardType = .numberPad

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            TextField("", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: 96)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

struct OnboardingValueRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            OnboardingIconBox(icon: icon)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
struct OnboardingNextButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { HapticEngine.tap(); action() }) {
            Text(title)
                .font(.subheadline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isEnabled ? FamilyUI.accent : Color(.systemGray4))
                .foregroundStyle(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

struct OptionRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            HStack {
                content
                if isSelected {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundStyle(FamilyUI.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? FamilyUI.accent.opacity(0.10) : FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(isSelected ? FamilyUI.accent : FamilyUI.panelBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
        }
        .buttonStyle(.plain)
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            OnboardingIconBox(icon: icon)
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
