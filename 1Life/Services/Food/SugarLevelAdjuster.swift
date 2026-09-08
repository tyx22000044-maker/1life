import Foundation

enum SugarLevelAdjuster {
    struct Match {
        let label: String
        let multiplier: Double
        let forcesZeroSugar: Bool
    }

    static func match(in text: String) -> Match? {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "%", with: "％")

        let rules: [(patterns: [String], label: String, multiplier: Double, forcesZeroSugar: Bool)] = [
            (["无糖", "0糖", "零糖"], "无糖", 0, true),
            (["不加糖", "不另外加糖", "无额外糖", "无额外糖浆", "不额外加糖"], "不另外加糖", 1, false),
            (["三分糖", "3分糖", "30％糖", "30%糖"], "三分糖", 0.3, false),
            (["五分糖", "5分糖", "半糖", "50％糖", "50%糖"], "五分糖", 0.5, false),
            (["七分糖", "7分糖", "少糖", "70％糖", "70%糖"], "七分糖", 0.7, false),
            (["正常糖", "全糖", "标准糖", "标准甜", "正常甜"], "正常糖", 1, false)
        ]

        for rule in rules where rule.patterns.contains(where: { normalized.contains($0) }) {
            return Match(label: rule.label, multiplier: rule.multiplier, forcesZeroSugar: rule.forcesZeroSugar)
        }
        return nil
    }

    static func searchableFoodName(from text: String) -> String {
        var cleaned = text
        let words = [
            "正常糖", "全糖", "标准糖", "标准甜", "正常甜", "七分糖", "7分糖", "少糖",
            "五分糖", "5分糖", "半糖", "三分糖", "3分糖", "无糖", "零糖", "0糖",
            "不加糖", "不另外加糖", "无额外糖", "无额外糖浆",
            "超大杯", "大杯", "中杯", "小杯", "标准杯"
        ]
        for word in words {
            cleaned = cleaned.replacingOccurrences(of: word, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
