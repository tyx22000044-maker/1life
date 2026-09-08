import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private var navigationHandler: ((AppTab) -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func registerNavigationHandler(_ handler: @escaping (AppTab) -> Void) {
        navigationHandler = handler
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func rescheduleRemindersIfNeeded(settings: UserSettings?) {
        guard let settings else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        if settings.isBreakfastReminderEnabled {
            scheduleMealReminder(id: "breakfast", hour: settings.breakfastReminderHour, title: "1Life", body: "该记录早餐了 🍳", tab: AppTab.ai)
        }
        if settings.isLunchReminderEnabled {
            scheduleMealReminder(id: "lunch", hour: settings.lunchReminderHour, title: "1Life", body: "午餐吃了什么？📝", tab: AppTab.ai)
        }
        if settings.isDinnerReminderEnabled {
            scheduleMealReminder(id: "dinner", hour: settings.dinnerReminderHour, title: "1Life", body: "记录一下晚餐吧 🍽", tab: AppTab.ai)
        }
        if settings.isWorkoutTargetReminderEnabled {
            scheduleWorkoutTargetReminder(
                weeklyTargetCount: settings.weeklyWorkoutTargetCount,
                weeklyTargetMinutes: settings.weeklyWorkoutTargetMinutes
            )
        }
        if settings.isWorkoutRestReminderEnabled {
            scheduleWorkoutRestReminder()
        }
    }

    func scheduleHabitReminder(habitID: UUID, name: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = name
        content.body = "该\(name)了"
        content.sound = .default
        content.userInfo = ["targetTab": AppTab.myLife.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "habit-\(habitID.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func removeHabitReminder(habitID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["habit-\(habitID.uuidString)"])
    }

    func scheduleWorkoutTargetReminder(weeklyTargetCount: Int, weeklyTargetMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "本周训练进度"
        content.body = "检查一下本周是否接近 \(weeklyTargetCount) 次 / \(weeklyTargetMinutes) 分钟目标。"
        content.sound = .default
        content.userInfo = ["targetTab": AppTab.myLife.rawValue]

        var dateComponents = DateComponents()
        dateComponents.weekday = 5
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "workout-weekly-target", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWorkoutRestReminder() {
        let content = UNMutableNotificationContent()
        content.title = "安排恢复"
        content.body = "如果最近连续训练，可以考虑安排一次休息或低强度恢复。"
        content.sound = .default
        content.userInfo = ["targetTab": AppTab.myLife.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "workout-rest-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func removeWorkoutReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["workout-weekly-target", "workout-rest-reminder"])
    }

    private func scheduleMealReminder(id: String, hour: Int, title: String, body: String, tab: AppTab) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["targetTab": tab.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "meal-\(id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let rawValue = response.notification.request.content.userInfo["targetTab"] as? Int
        Task { @MainActor in
            if let rawValue, let tab = AppTab(rawValue: rawValue) {
                navigationHandler?(tab)
            }
            completionHandler()
        }
    }
}
