import SwiftUI

struct AppSettingsRow: View {
    let icon: String
    var iconColor: Color = FamilyUI.accent
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var showsChevron: Bool = false
    var emphasizesValue: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: icon)
                        .font(FamilyTypography.icon)
                        .foregroundStyle(iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: emphasizesValue ? .semibold : .regular))
                    .foregroundStyle(emphasizesValue ? FamilyUI.accent : .secondary)
                    .multilineTextAlignment(.trailing)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
