import Foundation
import Observation

@MainActor
@Observable
final class GlobalBannerCenter {
    static let shared = GlobalBannerCenter()

    var currentBanner: AppBannerPayload?

    func show(title: String, message: String? = nil, tone: AppBannerTone = .error) {
        currentBanner = AppBannerPayload(title: title, message: message, tone: tone)
    }

    func dismiss() {
        currentBanner = nil
    }
}

struct AppBannerPayload: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String?
    let tone: AppBannerTone
}

@MainActor
@Observable
final class FeedbackPreferences {
    static let shared = FeedbackPreferences()

    private enum Keys {
        static let hapticsEnabled = "feedback.hapticsEnabled"
        static let soundEffectsEnabled = "feedback.soundEffectsEnabled"
    }

    var isHapticsEnabled: Bool
    var isSoundEffectsEnabled: Bool

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.hapticsEnabled) == nil {
            defaults.set(true, forKey: Keys.hapticsEnabled)
        }
        if defaults.object(forKey: Keys.soundEffectsEnabled) == nil {
            defaults.set(true, forKey: Keys.soundEffectsEnabled)
        }
        isHapticsEnabled = defaults.bool(forKey: Keys.hapticsEnabled)
        isSoundEffectsEnabled = defaults.bool(forKey: Keys.soundEffectsEnabled)
    }

    func apply(settings: UserSettings) {
        setHapticsEnabled(settings.isHapticsEnabled)
        setSoundEffectsEnabled(settings.isSoundEffectsEnabled)
    }

    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.hapticsEnabled)
    }

    func setSoundEffectsEnabled(_ enabled: Bool) {
        isSoundEffectsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.soundEffectsEnabled)
    }
}

@Observable
final class AppViewModel {
    var selectedTab: AppTab = .dashboard
    var pendingSettingsFocus: SettingsFocus?
    var selectedDate: Date = .now
    var isShowingOnboarding = false
    var myLifeFocus: MyLifeFocus?
    var foodFocusMealType: MealType?
    var foodScrollMealType: MealType?

    func navigateToFood(mealType: MealType? = nil) {
        foodFocusMealType = mealType
        foodScrollMealType = nil
        selectedTab = .food
    }

    func navigateToExistingMeal(_ mealType: MealType) {
        foodFocusMealType = nil
        foodScrollMealType = mealType
        selectedTab = .food
    }

    func navigateToAI() {
        selectedTab = .ai
    }

    func navigateToAISettings() {
        pendingSettingsFocus = .aiConfiguration
        selectedTab = .settings
    }

    func finishOnboarding() {
        isShowingOnboarding = false
    }
}

enum SettingsFocus: Hashable {
    case aiConfiguration
}

enum MyLifeFocus: String {
    case habits
    case workouts
    case journal
}
