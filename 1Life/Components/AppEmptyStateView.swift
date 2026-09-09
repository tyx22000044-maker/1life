import SwiftUI

struct AppEmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Rectangle()
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(FamilyUI.ink)
                )

            Text(title)
                .font(.custom("Archivo-Bold", size: 17, relativeTo: .headline))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(FamilyUI.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.custom("Archivo-Bold", size: 15))
                        .tracking(0.4)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(FamilyUI.accent)
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .background(FamilyUI.panelBackground)
        .overlay(
            Rectangle()
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
    }
}
