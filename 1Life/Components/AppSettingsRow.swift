import SwiftUI

struct AppSettingsRow: View {
    let icon: String
    var iconColor: Color = FamilyUI.ink
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var showsChevron: Bool = false
    var emphasizesValue: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
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
                    .font(.custom("Archivo-SemiBold", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.custom("Archivo-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(FamilyUI.inkSoft)
                }
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.custom("Archivo-SemiBold", size: 15, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(emphasizesValue ? FamilyUI.accent : FamilyUI.inkSoft)
                    .multilineTextAlignment(.trailing)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(FamilyUI.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
