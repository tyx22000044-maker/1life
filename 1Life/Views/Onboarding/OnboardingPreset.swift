import SwiftUI

enum OnboardingPreset: String, CaseIterable, Identifiable {
    case balanced = "均衡记录"
    case fatLoss = "减脂执行"
    case muscleGain = "增肌训练"
    case glucoseControl = "控糖饮食"
    case custom = "从空白开始"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .balanced: return "leaf.fill"
        case .fatLoss: return "flame.fill"
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .glucoseControl: return "drop.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var detail: String {
        switch self {
        case .balanced: return "稳定记录三餐、饮水、体重和日常习惯"
        case .fatLoss: return "轻热量缺口、高蛋白、称重和运动提醒"
        case .muscleGain: return "训练优先、更多蛋白和更高热量目标"
        case .glucoseControl: return "关注碳水、糖、饮水和餐后习惯"
        case .custom: return "不套用推荐，按自己的节奏配置"
        }
    }

    var dietGoalMode: DietGoalMode {
        switch self {
        case .balanced, .glucoseControl, .custom:
            return .balanced
        case .fatLoss:
            return .fatLoss
        case .muscleGain:
            return .muscleGain
        }
    }

    var proteinStrategy: ProteinTargetStrategy {
        switch self {
        case .fatLoss, .muscleGain:
            return .bodyWeight
        case .balanced, .glucoseControl, .custom:
            return .macroRatio
        }
    }

    var proteinMultiplier: Double {
        switch self {
        case .fatLoss: return 1.8
        case .muscleGain: return 2.0
        case .balanced, .glucoseControl, .custom: return 1.2
        }
    }

    var waterGoalMl: Double {
        switch self {
        case .balanced, .custom: return 2000
        case .fatLoss, .glucoseControl: return 2200
        case .muscleGain: return 2600
        }
    }

    var weeklyWorkoutTargetCount: Int {
        switch self {
        case .balanced, .glucoseControl, .custom: return 3
        case .fatLoss: return 4
        case .muscleGain: return 5
        }
    }

    var weeklyWorkoutTargetMinutes: Int {
        switch self {
        case .balanced, .custom: return 150
        case .fatLoss, .glucoseControl: return 180
        case .muscleGain: return 240
        }
    }

    var defaultReminderHours: (breakfast: Int, lunch: Int, dinner: Int) {
        switch self {
        case .balanced, .fatLoss, .glucoseControl, .custom:
            return (8, 12, 19)
        case .muscleGain:
            return (8, 13, 20)
        }
    }
}
