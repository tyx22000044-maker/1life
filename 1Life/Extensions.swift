import SwiftUI
import Foundation
import UIKit
import AudioToolbox

// MARK: - App Typography (Swiss Ledger — Archivo grotesk for text roles)
//
// Text roles use the bundled Archivo grotesk. Icon roles (`icon`, `actionIcon`)
// stay on the system font because they render SF Symbols, which only exist in the
// symbol font — a custom face there would draw blank glyphs.

enum FamilyTypography {
    static let hero = Font.custom("Archivo-Black", size: 34)
    static let pageTitle = Font.custom("Archivo-Black", size: 32)
    static let sectionLabel = Font.custom("Archivo-Bold", size: 10)
    static let icon = Font.system(size: 14, weight: .semibold)
    static let actionIcon = Font.system(.caption, weight: .black)
    static let badge = Font.custom("Archivo-Bold", size: 9.5)
    static let button = Font.custom("Archivo-Bold", size: 15)
}

enum AppTypography {
    static func configureGlobalAppearance() {
        let inlineTitle = groteskUIFont(textStyle: .headline, weight: .semibold)
        let largeTitle = groteskUIFont(textStyle: .largeTitle, weight: .bold)
        let tabLabel = groteskUIFont(textStyle: .caption1, weight: .semibold)

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithDefaultBackground()
        navigationAppearance.titleTextAttributes = [.font: inlineTitle]
        navigationAppearance.largeTitleTextAttributes = [.font: largeTitle]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance

        UITabBarItem.appearance().setTitleTextAttributes([.font: tabLabel], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabLabel], for: .selected)
    }

    private static func groteskUIFont(textStyle: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        // Match the bundled Archivo face for the requested weight, falling back to
        // the system font at the same size/weight if the face is unavailable.
        if let archivo = UIFont(name: "Archivo-" + postScriptSuffix(for: weight), size: base.pointSize) {
            return archivo
        }
        return base.withWeight(weight)
    }

    private static func postScriptSuffix(for weight: UIFont.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light:   return "Regular"
        case .regular:                     return "Regular"
        case .medium:                      return "Medium"
        case .semibold:                    return "SemiBold"
        case .bold:                        return "Bold"
        case .heavy:                       return "ExtraBold"
        case .black:                       return "Black"
        default:                           return "Regular"
        }
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        return UIFont(descriptor: descriptor, size: 0)
    }
}

private struct AppTypographyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Archivo Regular as the app-wide default; `relativeTo: .body` keeps
            // Dynamic Type scaling that `.system(.body, …)` previously provided.
            .font(.custom("Archivo-Regular", size: 17, relativeTo: .body))
    }
}

extension View {
    func appTypography() -> some View {
        modifier(AppTypographyModifier())
    }

    func appSwitchStyle() -> some View {
        toggleStyle(AppSwitchStyle())
    }

    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissTapBridge())
    }
}

struct KeyboardDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("完成", systemImage: "keyboard.chevron.compact.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyUI.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct KeyboardDismissTapBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            installTapRecognizer(from: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            installTapRecognizer(from: uiView, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func installTapRecognizer(from view: UIView, coordinator: Coordinator) {
        guard let window = view.window, coordinator.window !== window else { return }
        coordinator.window?.gestureRecognizers?
            .filter { $0.name == Coordinator.recognizerName }
            .forEach { coordinator.window?.removeGestureRecognizer($0) }

        let recognizer = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.dismissKeyboard))
        recognizer.name = Coordinator.recognizerName
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = coordinator
        window.addGestureRecognizer(recognizer)
        coordinator.window = window
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        static let recognizerName = "OneLifeDismissKeyboardTapRecognizer"
        weak var window: UIWindow?

        @objc func dismissKeyboard() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else { return true }
            return !touchedView.isTextInputDescendant
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private extension UIView {
    var isTextInputDescendant: Bool {
        if self is UITextField || self is UITextView || self is UISearchTextField {
            return true
        }
        return superview?.isTextInputDescendant ?? false
    }
}

struct AppSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            HapticEngine.tap()
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 12)
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .fill(configuration.isOn ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .frame(width: 50, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(configuration.isOn ? Color.white : Color.secondary.opacity(0.55))
                            .frame(width: 20, height: 20)
                            .padding(5)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Haptic Engine

enum SoundEngine {
    // A short, lightweight system tick for confirmations.
    private static let confirmationSound: SystemSoundID = 1104

    static func confirmation() {
        guard FeedbackPreferences.shared.isSoundEffectsEnabled else { return }
        AudioServicesPlaySystemSound(confirmationSound)
    }
}

enum HapticEngine {
    static func tap() {
        guard FeedbackPreferences.shared.isHapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        guard FeedbackPreferences.shared.isHapticsEnabled else {
            SoundEngine.confirmation()
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        SoundEngine.confirmation()
    }
    static func warning() {
        guard FeedbackPreferences.shared.isHapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - App Spacing

enum AppSpacing {
    static let pageHorizontal: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cardPaddingLarge: CGFloat = 20
    static let sectionSpacing: CGFloat = 12
    static let formSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let rowIconSpacing: CGFloat = 12
    static let pageBottom: CGFloat = 24
}

// MARK: - App Corner Radius
//
// Legacy pair still live alongside FamilyUI (see HANDOFF §4). Squared to match
// Swiss Ledger's 0–4pt panel / 0–2pt control geometry.

enum AppCornerRadius {
    static let card: CGFloat = 2
    static let cardLarge: CGFloat = 4
    static let button: CGFloat = 0
    static let icon: CGFloat = 0
    static let iconLarge: CGFloat = 2
    static let progressBar: CGFloat = 0
    static let photo: CGFloat = 2
}

// MARK: - NutrientKey UI helpers
//
// Nutrient colors are *informational* color-coding, not signal color, so they stay
// multi-hue (per HANDOFF §5) rather than collapsing into the single accent. They are
// desaturated to sit on the cool paper/ink palette and used only at small scale
// (thin bar fills, tiny inline labels) — never large fills.

extension NutrientKey {
    var spotlightColor: Color {
        switch self {
        case .protein:     return Color(hex: "4a5f7e")   // muted slate blue
        case .carbs:       return Color(hex: "a06a30")   // muted amber
        case .fat:         return Color(hex: "8a7434")   // muted ochre
        case .fiber:       return Color(hex: "4d7a5e")   // muted sage
        case .sodium:      return Color(hex: "6f5279")   // muted plum
        case .sugar:       return Color(hex: "94566e")   // muted rose
        case .cholesterol: return Color(hex: "8c5a4f")   // muted brick (distinct from accent)
        case .caffeine:    return Color(hex: "6b5a4a")   // muted umber
        case .teaPolyphenols: return Color(hex: "4a6f57")  // muted forest
        default:           return FamilyUI.inkSoft
        }
    }

    var shortDisplayName: String {
        switch self {
        case .carbs:       return "碳水"
        case .fiber:       return "纤维"
        default:           return displayName
        }
    }
}

// MARK: - Family UI V2 — Swiss Ledger
//
// Cold, grid-first palette: cool paper, near-black ink, hairline rules, one signal
// accent. Borders are always 1px hairlines; panels carry no drop shadows.

enum FamilyUI {
    /// Paper / page background — light #FAFAF7, dark near-black.
    static let pageBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.075, blue: 0.067, alpha: 1)   // #131311
            : UIColor(red: 0.980, green: 0.980, blue: 0.969, alpha: 1)   // #FAFAF7
    })
    static let panelBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.102, blue: 0.094, alpha: 1)   // #1A1A18
            : UIColor.white
    })
    static let panelMutedBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.137, green: 0.137, blue: 0.125, alpha: 1)   // #232320
            : UIColor(red: 0.957, green: 0.957, blue: 0.945, alpha: 1)   // #F4F4F1
    })

    /// Ink — primary text, rules, and borders.
    static let ink = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.949, green: 0.949, blue: 0.925, alpha: 1)   // #F2F2EC
            : UIColor(red: 0.043, green: 0.043, blue: 0.039, alpha: 1)   // #0B0B0A
    })
    /// Soft ink — secondary text.
    static let inkSoft = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.627, green: 0.627, blue: 0.604, alpha: 1)   // #A0A09A
            : UIColor(red: 0.431, green: 0.431, blue: 0.408, alpha: 1)   // #6E6E68
    })
    /// Faint ink — tertiary text, inactive tab labels.
    static let inkFaint = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.451, green: 0.451, blue: 0.431, alpha: 1)   // #73736E
            : UIColor(red: 0.612, green: 0.608, blue: 0.565, alpha: 1)   // #9C9B90
    })

    /// Hairline borders: regular (panels/sections), subtle (row dividers), strong (tab bar).
    static let hairlineRegular = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor(red: 0.043, green: 0.043, blue: 0.039, alpha: 0.14)
    })
    static let hairlineSubtle = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor(red: 0.043, green: 0.043, blue: 0.039, alpha: 0.10)
    })
    static let hairlineStrong = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.16)
            : UIColor(red: 0.043, green: 0.043, blue: 0.039, alpha: 0.16)
    })

    static let panelBorder = hairlineRegular
    static let divider = hairlineSubtle

    /// Single signal color — print red, brightened for dark mode.
    static let accent = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.882, green: 0.294, blue: 0.212, alpha: 1)   // #E14B36
            : UIColor(red: 0.769, green: 0.196, blue: 0.122, alpha: 1)   // #C4321F
    })
    static let success = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.322, green: 0.541, blue: 0.451, alpha: 1)   // #528A73
            : UIColor(red: 0.212, green: 0.408, blue: 0.337, alpha: 1)   // #366853
    })
    static let warning = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.737, green: 0.541, blue: 0.208, alpha: 1)   // #BC8A35
            : UIColor(red: 0.584, green: 0.427, blue: 0.169, alpha: 1)   // #956D2B
    })
    /// Danger shares the single signal color rather than a second red.
    static let danger = accent
    static let subtleText = inkSoft

    /// Swiss Ledger is square: panels 0–4pt, controls/tags 0–2pt.
    static let panelCornerRadius: CGFloat = 2
    static let controlCornerRadius: CGFloat = 0
    static let badgeCornerRadius: CGFloat = 0
    static let iconBoxSize: CGFloat = 34
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Double

extension Double {
    var nutritionInt: String {
        "\(Int(self))"
    }

    var nutritionDecimal: String {
        String(format: "%.1f", self)
    }

    var kcalString: String {
        "\(Int(self)) kcal"
    }
}

// MARK: - Date

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .day)
    }

    var dayDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: self)
    }

    var timeDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    var sectionHeaderDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: self)
    }

    var isoDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
}
