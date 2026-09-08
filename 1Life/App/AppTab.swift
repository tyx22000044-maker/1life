import Foundation

enum AppTab: Int, CaseIterable, Hashable, Identifiable {
    case dashboard
    case food
    case ai
    case myLife
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "今日"
        case .food: return "饮食"
        case .ai: return "AI"
        case .myLife: return "回顾"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .food: return "fork.knife"
        case .ai: return "sparkles"
        case .myLife: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }
}
