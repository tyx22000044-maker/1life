import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { HapticEngine.tap(); action() }) {
            Text(title)
                .font(FamilyTypography.button)
                .tracking(0.4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isEnabled ? FamilyUI.accent : FamilyUI.hairlineRegular)
                .foregroundStyle(isEnabled ? FamilyUI.buttonForeground : FamilyUI.inkSoft)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}
