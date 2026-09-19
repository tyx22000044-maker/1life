import SwiftUI

struct SplashView: View {
    let appName: String
    let iconName: String
    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var panelOffset: CGFloat = 18

    init(appName: String, iconName: String = "SplashAppIcon", onFinished: @escaping () -> Void) {
        self.appName = appName
        self.iconName = iconName
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            FamilyUI.pageBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                    .fill(FamilyUI.panelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .frame(width: 132, height: 132)
                    .overlay {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius, style: .continuous))
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }

                VStack(spacing: 6) {
                    Text(appName)
                        .font(FamilyTypography.hero)
                        .monospacedDigit()
                    Text("营养、习惯与身体回顾")
                        .font(FamilyTypography.text(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
            }
            .offset(y: panelOffset)
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
            panelOffset = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onFinished()
        }
    }
}
