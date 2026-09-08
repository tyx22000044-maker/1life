import Foundation
import UIKit

nonisolated enum NutritionPDFExportService {
    private static func calendarDayEnd(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? date
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func mealTypeName(_ mealType: MealType) -> String {
        switch mealType {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .fruit: return "水果"
        case .snack: return "零食"
        case .supper: return "夜宵"
        }
    }

    @MainActor
    static func exportNutritionPDF(
        settings: UserSettings?,
        nutritionGoals: [NutritionGoal],
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog],
        dateRange: ClosedRange<Date>
    ) throws -> Data {
        let days = dayRange(from: dateRange)
        guard !days.isEmpty else { throw ExportService.PDFExportError.invalidDateRange }

        let reports = days.map {
            buildPDFDayReport(
                date: $0,
                settings: settings,
                nutritionGoals: nutritionGoals,
                meals: meals,
                waterLogs: waterLogs,
                workouts: workouts,
                bodyMeasurements: bodyMeasurements,
                bowelLogs: bowelLogs
            )
        }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for report in reports {
                context.beginPage()
                drawPDFDayReport(report, pageRect: pageRect)
            }
        }
    }

    @MainActor
    private static func buildPDFDayReport(
        date: Date,
        settings: UserSettings?,
        nutritionGoals: [NutritionGoal],
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog]
    ) -> PDFDayReport {
        let dayEnd = calendarDayEnd(for: date)
        let dayMeals = meals
            .filter { $0.date.isSameDay(as: date) }
            .sorted {
                if $0.mealTypeSortOrder != $1.mealTypeSortOrder {
                    return $0.mealTypeSortOrder < $1.mealTypeSortOrder
                }
                return $0.date < $1.date
            }
        let dayWorkouts = workouts
            .filter { $0.startDate.isSameDay(as: date) }
            .sorted { $0.startDate < $1.startDate }
        let latestMeasurement = bodyMeasurements
            .filter { $0.date <= dayEnd }
            .sorted { $0.date > $1.date }
            .first
        let previousMeasurement = bodyMeasurements
            .filter { $0.date < (latestMeasurement?.date ?? .distantPast) }
            .sorted { $0.date > $1.date }
            .first
        let summary = NutritionService.dailySummary(meals: meals, waterLogs: waterLogs, for: date)
        let goal = nutritionGoal(for: date, in: nutritionGoals)
        let dayBowelLogs = bowelLogs
            .filter { $0.date.isSameDay(as: date) }
            .sorted { $0.date < $1.date }

        let fallbackCalories = settings?.recommendedCalories ?? 2000
        let fallbackMacros = settings?.recommendedMacroTargets(calories: fallbackCalories)
            ?? RecommendedMacroTargets(protein: 75, carbs: 300, fat: 56)
        let calorieTarget = goal?.dailyCalories ?? fallbackCalories
        let proteinTarget = goal?.dailyProtein ?? fallbackMacros.protein
        let carbsTarget = goal?.dailyCarbs ?? fallbackMacros.carbs
        let fatTarget = goal?.dailyFat ?? fallbackMacros.fat
        let waterTarget = settings?.dailyWaterGoalMl ?? 2000

        return PDFDayReport(
            date: date,
            summary: summary,
            meals: dayMeals,
            workouts: dayWorkouts,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            carbsTarget: carbsTarget,
            fatTarget: fatTarget,
            waterTarget: waterTarget,
            latestMeasurement: latestMeasurement,
            previousMeasurement: previousMeasurement,
            heightCm: settings?.heightCm,
            bowelLogs: dayBowelLogs
        )
    }

    private static func nutritionGoal(for date: Date, in goals: [NutritionGoal]) -> NutritionGoal? {
        let dayEnd = calendarDayEnd(for: date)
        return goals
            .filter { $0.effectiveDate <= dayEnd }
            .sorted { $0.effectiveDate > $1.effectiveDate }
            .first
    }

    private static func dayRange(from range: ClosedRange<Date>) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        guard start <= end else { return [] }
        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    @MainActor
    private static func drawPDFDayReport(_ report: PDFDayReport, pageRect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        ReportTheme.background.setFill()
        context?.fill(pageRect)

        let contentWidth = pageRect.width - ReportTheme.margin * 2
        drawReportHeader(report, pageRect: pageRect)

        let heroRect = CGRect(x: ReportTheme.margin, y: 120, width: contentWidth, height: 138)
        drawCard(heroRect, fill: ReportTheme.panel)

        let calorieDelta = report.summary.totalCalories - report.calorieTarget
        let deltaText: String
        let deltaColor: UIColor
        if calorieDelta > 1 {
            deltaText = "热量差 +\(Int(calorieDelta)) kcal"
            deltaColor = UIColor(red: 0.76, green: 0.22, blue: 0.19, alpha: 1)
        } else if calorieDelta < -1 {
            deltaText = "热量差 \(Int(calorieDelta)) kcal"
            deltaColor = UIColor(red: 0.15, green: 0.53, blue: 0.31, alpha: 1)
        } else {
            deltaText = "热量差 0 kcal"
            deltaColor = UIColor(red: 0.24, green: 0.37, blue: 0.78, alpha: 1)
        }

        drawText("摄入与目标", in: CGRect(x: 46, y: 136, width: 100, height: 16), font: .systemFont(ofSize: 11, weight: .semibold), color: ReportTheme.secondaryText)
        drawText("\(Int(report.summary.totalCalories))", in: CGRect(x: 46, y: 154, width: 120, height: 34), font: .systemFont(ofSize: 30, weight: .bold), color: ReportTheme.primaryText)
        drawText(" / \(Int(report.calorieTarget)) kcal", in: CGRect(x: 152, y: 166, width: 120, height: 20), font: .systemFont(ofSize: 14, weight: .medium), color: ReportTheme.secondaryText)
        drawBadge(deltaText, in: CGRect(x: 46, y: 202, width: 130, height: 24), fill: deltaColor.withAlphaComponent(0.12), textColor: deltaColor)

        let rightX = heroRect.maxX - 168
        drawReportHeroMetrics(report, rightX: rightX)

        let metricWidth = (contentWidth - 24) / 4
        let metricY: CGFloat = 274
        let metrics: [PDFMetricCard] = [
            .init(title: "蛋白质", current: report.summary.totalProtein ?? 0, target: report.proteinTarget, tint: UIColor(red: 0.18, green: 0.46, blue: 0.90, alpha: 1), unit: "g"),
            .init(title: "碳水", current: report.summary.totalCarbs ?? 0, target: report.carbsTarget, tint: UIColor(red: 0.93, green: 0.55, blue: 0.17, alpha: 1), unit: "g"),
            .init(title: "脂肪", current: report.summary.totalFat ?? 0, target: report.fatTarget, tint: UIColor(red: 0.82, green: 0.66, blue: 0.10, alpha: 1), unit: "g"),
            .init(title: "饮水", current: report.summary.totalWaterMl, target: report.waterTarget, tint: UIColor(red: 0.18, green: 0.67, blue: 0.76, alpha: 1), unit: "ml")
        ]

        for (index, metric) in metrics.enumerated() {
            let rect = CGRect(x: ReportTheme.margin + CGFloat(index) * (metricWidth + 8), y: metricY, width: metricWidth, height: 78)
            drawMetricCard(metric, rect: rect)
        }

        drawText("饮食明细", in: CGRect(x: ReportTheme.margin, y: 366, width: 120, height: 18), font: .systemFont(ofSize: 14, weight: .bold), color: ReportTheme.primaryText)
        var mealY: CGFloat = 392
        if report.meals.isEmpty {
            let emptyRect = CGRect(x: ReportTheme.margin, y: mealY, width: contentWidth, height: 72)
            drawCard(emptyRect, fill: ReportTheme.panel)
            drawText("当天还没有饮食记录", in: CGRect(x: 44, y: mealY + 18, width: 220, height: 18), font: .systemFont(ofSize: 14, weight: .semibold), color: UIColor.darkGray)
            drawText("导出范围会按天保留空白页，方便你回看哪些天缺记录。", in: CGRect(x: 44, y: mealY + 40, width: 360, height: 16), font: .systemFont(ofSize: 11, weight: .regular), color: UIColor.gray)
            mealY += 84
        } else {
            for meal in report.meals.prefix(3) {
                let rect = CGRect(x: ReportTheme.margin, y: mealY, width: contentWidth, height: 84)
                drawMealCard(meal, rect: rect)
                mealY += 92
            }
        }

        let bottomCardY = min(pageRect.height - 130, mealY + 4)
        let bottomRect = CGRect(x: ReportTheme.margin, y: bottomCardY, width: contentWidth, height: 92)
        drawCard(bottomRect, fill: ReportTheme.panel)
        drawText("补充观察", in: CGRect(x: 44, y: bottomCardY + 14, width: 90, height: 16), font: .systemFont(ofSize: 12, weight: .bold), color: ReportTheme.primaryText)
        let fiberText = "纤维 \(safeInt(report.summary.totalFiber))g"
        let sodiumText = "钠 \(safeInt(report.summary.totalSodium))mg"
        let workoutText = workoutSummaryText(report.workouts)
        let bodyDeltaText = bodyDeltaSummary(current: report.latestMeasurement, previous: report.previousMeasurement)
        let bowelText = bowelSummaryText(report.bowelLogs)
        let bmiText = bmiSummary(weightKg: report.latestMeasurement?.weightKg, heightCm: report.heightCm)
        let insight = "摄入/目标差值按摄入减目标计算；负值表示缺口，正值表示超出。\(fiberText) · \(sodiumText) · \(workoutText) · \(bodyDeltaText) · \(bmiText) · \(bowelText)"
        drawParagraph(insight, in: CGRect(x: 44, y: bottomCardY + 34, width: contentWidth - 32, height: 42), font: .systemFont(ofSize: 11, weight: .regular), color: ReportTheme.secondaryText)

        context?.restoreGState()
    }

    @MainActor
    private static func drawMealCard(_ meal: Meal, rect: CGRect) {
        drawCard(rect, fill: ReportTheme.panel)
        let items = (meal.foodItems ?? []).sorted { $0.calories > $1.calories }
        let itemLines = items.prefix(3).map { "\($0.name) \(Int($0.calories))kcal" }
        let moreCount = max(0, items.count - itemLines.count)
        let detailText = itemLines.joined(separator: " · ") + (moreCount > 0 ? " · +\(moreCount)项" : "")

        drawText(mealTypeName(meal.mealType), in: CGRect(x: rect.minX + 16, y: rect.minY + 12, width: 100, height: 18), font: .systemFont(ofSize: 13, weight: .bold), color: UIColor.black)
        drawText(formatTime(meal.date), in: CGRect(x: rect.minX + 78, y: rect.minY + 13, width: 70, height: 16), font: .systemFont(ofSize: 11, weight: .medium), color: UIColor.gray)
        drawText("\(Int(meal.totalCalories)) kcal", in: CGRect(x: rect.maxX - 110, y: rect.minY + 12, width: 94, height: 18), font: .systemFont(ofSize: 13, weight: .bold), color: UIColor(red: 0.18, green: 0.46, blue: 0.90, alpha: 1), alignment: .right)
        drawParagraph(detailText.isEmpty ? "无食物项明细" : detailText, in: CGRect(x: rect.minX + 16, y: rect.minY + 36, width: rect.width - 32, height: 18), font: .systemFont(ofSize: 11, weight: .medium), color: UIColor.darkGray)

        let protein = meal.totalProtein ?? 0
        let carbs = meal.totalCarbs ?? 0
        let fat = meal.totalFat ?? 0
        let macroLine = "P \(Int(protein))g   C \(Int(carbs))g   F \(Int(fat))g"
        drawText(macroLine, in: CGRect(x: rect.minX + 16, y: rect.minY + 58, width: 200, height: 14), font: .monospacedSystemFont(ofSize: 11, weight: .medium), color: UIColor.gray)
    }

    @MainActor
    private static func drawMetricCard(_ metric: PDFMetricCard, rect: CGRect) {
        drawCard(rect, fill: ReportTheme.panel)
        drawText(metric.title, in: CGRect(x: rect.minX + 12, y: rect.minY + 10, width: rect.width - 24, height: 14), font: .systemFont(ofSize: 11, weight: .semibold), color: ReportTheme.secondaryText)
        drawText("\(Int(metric.current))/\(Int(metric.target))", in: CGRect(x: rect.minX + 12, y: rect.minY + 28, width: rect.width - 24, height: 20), font: .systemFont(ofSize: 16, weight: .bold), color: ReportTheme.primaryText)
        drawText(metric.unit, in: CGRect(x: rect.minX + 12, y: rect.minY + 48, width: 40, height: 12), font: .systemFont(ofSize: 10, weight: .medium), color: ReportTheme.secondaryText)

        let barRect = CGRect(x: rect.minX + 12, y: rect.maxY - 16, width: rect.width - 24, height: 6)
        let progress = min(max(metric.current / max(metric.target, 1), 0), 1.0)
        let bgPath = UIBezierPath(roundedRect: barRect, cornerRadius: 3)
        UIColor(red: 0.92, green: 0.94, blue: 0.95, alpha: 1).setFill()
        bgPath.fill()
        let fillRect = CGRect(x: barRect.minX, y: barRect.minY, width: barRect.width * progress, height: barRect.height)
        metric.tint.setFill()
        UIBezierPath(roundedRect: fillRect, cornerRadius: 3).fill()
    }

    private static func drawCard(_ rect: CGRect, fill: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: ReportTheme.cardRadius)
        fill.setFill()
        path.fill()

        ReportTheme.border.setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }

    @MainActor
    private static func drawReportHeader(_ report: PDFDayReport, pageRect: CGRect) {
        let headerRect = CGRect(x: 0, y: 0, width: pageRect.width, height: 104)
        ReportTheme.panel.setFill()
        UIBezierPath(rect: headerRect).fill()

        drawText(
            "1Life 健康报告",
            in: CGRect(x: ReportTheme.margin, y: 24, width: 240, height: 26),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: ReportTheme.primaryText
        )
        drawText(
            "\(pdfDayTitle(report.date)) · 营养 / 训练 / 身体摘要",
            in: CGRect(x: ReportTheme.margin, y: 56, width: 320, height: 20),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: ReportTheme.secondaryText
        )

        drawBadge(
            "可复盘报告",
            in: CGRect(x: pageRect.width - ReportTheme.margin - 92, y: 34, width: 92, height: 26),
            fill: ReportTheme.accent.withAlphaComponent(0.12),
            textColor: ReportTheme.accent
        )
    }

    @MainActor
    private static func drawReportHeroMetrics(_ report: PDFDayReport, rightX: CGFloat) {
        let workoutMinutes = Int(report.workouts.reduce(0) { $0 + $1.durationMinutes })
        let bodyText = report.latestMeasurement?.weightKg.map { String(format: "%.1fkg", $0) } ?? "--"
        let bodySub = bmiSummary(weightKg: report.latestMeasurement?.weightKg, heightCm: report.heightCm)
        let bowelValue = report.bowelLogs.isEmpty ? "无" : "\(report.bowelLogs.count) 次"
        let bowelSub = report.bowelLogs.first.map { bristolDisplayName(rawValue: $0.bristolTypeRaw) } ?? "当天未记录"

        drawKeyMetric(title: "餐次", value: "\(report.summary.mealCount)", subtitle: "\(report.summary.foodItemCount) 项食物", origin: CGPoint(x: rightX, y: 140))
        drawKeyMetric(title: "饮水", value: "\(Int(report.summary.totalWaterMl)) ml", subtitle: "目标 \(Int(report.waterTarget)) ml", origin: CGPoint(x: rightX, y: 178))
        drawKeyMetric(title: "训练", value: report.workouts.isEmpty ? "无" : "\(workoutMinutes) 分钟", subtitle: report.workouts.isEmpty ? "当天未记录" : "\(report.workouts.count) 条记录", origin: CGPoint(x: rightX + 86, y: 140))
        drawKeyMetric(title: "身体", value: bodyText, subtitle: bodySub, origin: CGPoint(x: rightX + 86, y: 178))
        drawKeyMetric(title: "排便", value: bowelValue, subtitle: bowelSub, origin: CGPoint(x: rightX, y: 216))
    }

    private static func drawBadge(_ text: String, in rect: CGRect, fill: UIColor, textColor: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        fill.setFill()
        path.fill()
        drawText(text, in: rect.insetBy(dx: 8, dy: 4), font: .systemFont(ofSize: 11, weight: .bold), color: textColor, alignment: .center)
    }

    private static func drawKeyMetric(title: String, value: String, subtitle: String, origin: CGPoint) {
        drawText(title, in: CGRect(x: origin.x, y: origin.y, width: 70, height: 14), font: .systemFont(ofSize: 10, weight: .semibold), color: ReportTheme.secondaryText)
        drawText(value, in: CGRect(x: origin.x, y: origin.y + 14, width: 90, height: 18), font: .systemFont(ofSize: 15, weight: .bold), color: ReportTheme.primaryText)
        drawText(subtitle, in: CGRect(x: origin.x, y: origin.y + 32, width: 92, height: 14), font: .systemFont(ofSize: 10, weight: .regular), color: ReportTheme.secondaryText)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }

    private static func drawParagraph(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func pdfDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    private static func safeInt(_ value: Double?) -> Int {
        Int((value ?? 0).rounded())
    }

    private static func workoutSummaryText(_ workouts: [WorkoutLog]) -> String {
        guard !workouts.isEmpty else { return "无训练记录" }
        return workouts.prefix(2)
            .map { "\(workoutTypeName($0.workoutType))\(Int($0.durationMinutes))分钟" }
            .joined(separator: " · ")
    }

    private static func workoutTypeName(_ type: WorkoutType) -> String {
        switch type {
        case .walking: return "步行"
        case .running: return "跑步"
        case .cycling: return "骑行"
        case .strength: return "力量训练"
        case .swimming: return "游泳"
        case .yoga: return "瑜伽"
        case .hiit: return "HIIT"
        case .ballSports: return "球类"
        case .rest: return "休息"
        case .other: return "其他"
        }
    }

    private static func bodyMeasurementSourceName(_ source: BodyMeasurementSource) -> String {
        switch source {
        case .manual: return "手动记录"
        case .appleHealth: return "Apple Health"
        case .ai: return "AI 记录"
        }
    }

    private static func bodyDeltaSummary(current: BodyMeasurement?, previous: BodyMeasurement?) -> String {
        guard let current else { return "无身体数据" }
        var parts: [String] = []
        if let weight = current.weightKg {
            if let previousWeight = previous?.weightKg {
                parts.append(String(format: "体重 %.1fkg (%@%.1f)", weight, weight - previousWeight >= 0 ? "+" : "", weight - previousWeight))
            } else {
                parts.append(String(format: "体重 %.1fkg", weight))
            }
        }
        if let bodyFat = current.bodyFatPercentage {
            if let previousBodyFat = previous?.bodyFatPercentage {
                parts.append(String(format: "体脂 %.1f%% (%@%.1f)", bodyFat, bodyFat - previousBodyFat >= 0 ? "+" : "", bodyFat - previousBodyFat))
            } else {
                parts.append(String(format: "体脂 %.1f%%", bodyFat))
            }
        }
        return parts.isEmpty ? "无身体数据" : parts.joined(separator: " · ")
    }

    private static func bmiSummary(weightKg: Double?, heightCm: Double?) -> String {
        guard let weightKg, let heightCm, heightCm > 0 else { return "BMI 无数据" }
        let heightM = heightCm / 100
        return String(format: "BMI %.1f", weightKg / (heightM * heightM))
    }

    private static func bowelSummaryText(_ logs: [BowelLog]) -> String {
        guard !logs.isEmpty else { return "无排便记录" }
        let types = logs.map { bristolDisplayName(rawValue: $0.bristolTypeRaw) }.joined(separator: " / ")
        return "排便 \(logs.count) 次：\(types)"
    }

    nonisolated private static func bristolDisplayName(rawValue: String) -> String {
        switch BristolStoolType(rawValue: rawValue) ?? .normal {
        case .hard: return "偏硬"
        case .normal: return "正常"
        case .soft: return "偏软"
        case .loose: return "稀便"
        case .watery: return "水样"
        }
    }

    // MARK: - 饮品知识库 PDF

    @MainActor
    static func exportDrinkLibraryPDF(records: [DrinkRecord]) throws -> Data {
        guard !records.isEmpty else { throw ExportService.PDFExportError.emptyDrinkSelection }

        let groups = Dictionary(grouping: records) { $0.brand.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { (brand: $0.key, records: $0.value.sorted { lhs, rhs in
                if lhs.productName != rhs.productName {
                    return lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
                }
                return (lhs.sizeML ?? 0) < (rhs.sizeML ?? 0)
            }) }
            .sorted { $0.brand.localizedCompare($1.brand) == .orderedAscending }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let contentWidth = pageRect.width - ReportTheme.margin * 2
        let cardHeight: CGFloat = 94
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            var pageNumber = 0
            func startPage() {
                context.beginPage()
                pageNumber += 1
                ReportTheme.background.setFill()
                UIGraphicsGetCurrentContext()?.fill(pageRect)
                if pageNumber == 1 {
                    drawDrinkLibraryHeader(recordCount: records.count, brandCount: groups.count, pageRect: pageRect)
                } else {
                    drawLibraryContinuationHeader(title: "1Life 饮品营养图鉴", pageNumber: pageNumber, pageRect: pageRect)
                }
                drawLibraryFooter(pageNumber: pageNumber, pageRect: pageRect)
            }

            startPage()
            var y: CGFloat = 124

            func ensureSpace(_ height: CGFloat) {
                guard y + height > pageRect.height - 36 else { return }
                startPage()
                y = 72
            }

            for group in groups {
                ensureSpace(26 + cardHeight + 8)
                let brandTitle = group.brand.isEmpty ? "未标品牌" : group.brand
                drawLibraryBrandHeader(title: brandTitle, count: group.records.count, y: y, width: contentWidth, tint: ReportTheme.accent)
                y += 30

                for record in group.records {
                    ensureSpace(cardHeight + 8)
                    drawDrinkCard(record, rect: CGRect(x: ReportTheme.margin, y: y, width: contentWidth, height: cardHeight))
                    y += cardHeight + 8
                }
                y += 8
            }
        }
    }

    private static func drawDrinkLibraryHeader(recordCount: Int, brandCount: Int, pageRect: CGRect) {
        let headerRect = CGRect(x: 0, y: 0, width: pageRect.width, height: 104)
        ReportTheme.panel.setFill()
        UIBezierPath(rect: headerRect).fill()

        drawText(
            "1Life 饮品营养图鉴",
            in: CGRect(x: ReportTheme.margin, y: 24, width: 260, height: 26),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: ReportTheme.primaryText
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        drawText(
            "\(formatter.string(from: .now)) 导出 · \(brandCount) 个品牌 · \(recordCount) 个版本",
            in: CGRect(x: ReportTheme.margin, y: 56, width: 340, height: 20),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: ReportTheme.secondaryText
        )
        drawBadge(
            "饮品知识库",
            in: CGRect(x: pageRect.width - ReportTheme.margin - 92, y: 34, width: 92, height: 26),
            fill: ReportTheme.accent.withAlphaComponent(0.12),
            textColor: ReportTheme.accent
        )
    }

    private static func drawDrinkCard(_ record: DrinkRecord, rect: CGRect) {
        drawCard(rect, fill: ReportTheme.panel)
        drawLibraryCardAccent(in: rect, color: ReportTheme.accent)
        let x = rect.minX + 18
        let textWidth = rect.width - 150

        var specs: [String] = [cupSizeLabel(forML: record.sizeML)]
        if !record.sugarLevel.isEmpty { specs.append(record.sugarLevel) }
        if !record.toppings.isEmpty { specs.append("小料：\(record.toppings)") }
        let specLine = specs.joined(separator: " · ")

        drawText(
            record.productName.isEmpty ? "未命名饮品" : record.productName,
            in: CGRect(x: x, y: rect.minY + 10, width: textWidth, height: 17),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: ReportTheme.primaryText
        )
        drawText(
            specLine,
            in: CGRect(x: x, y: rect.minY + 28, width: textWidth, height: 14),
            font: .systemFont(ofSize: 10.5, weight: .medium),
            color: ReportTheme.secondaryText
        )

        var nutrients: [String] = []
        if let protein = record.protein { nutrients.append("P \(pdfNumber(protein))g") }
        if let carbs = record.carbs { nutrients.append("C \(pdfNumber(carbs))g") }
        if let fat = record.fat { nutrients.append("F \(pdfNumber(fat))g") }
        if let sugar = record.sugar { nutrients.append("糖 \(pdfNumber(sugar))g") }
        if let sodium = record.sodium { nutrients.append("钠 \(pdfNumber(sodium))mg") }
        drawText(
            nutrients.isEmpty ? "营养素未记录" : nutrients.joined(separator: "   "),
            in: CGRect(x: x, y: rect.minY + 46, width: textWidth, height: 13),
            font: .monospacedSystemFont(ofSize: 9.5, weight: .medium),
            color: ReportTheme.secondaryText
        )

        let caffeineText = record.caffeine.map { "咖啡因 \(pdfNumber($0))mg" } ?? "咖啡因 无数据"
        let teaPolyphenolsText = record.teaPolyphenols.map { "茶多酚 \(pdfNumber($0))mg" } ?? "茶多酚 无数据"
        drawText(
            "\(caffeineText)   \(teaPolyphenolsText)",
            in: CGRect(x: x, y: rect.minY + 70, width: textWidth, height: 13),
            font: .monospacedSystemFont(ofSize: 9.5, weight: .medium),
            color: ReportTheme.secondaryText
        )

        drawText(
            record.calories.map { "\(Int($0)) kcal" } ?? "热量未知",
            in: CGRect(x: rect.maxX - 130, y: rect.minY + 14, width: 114, height: 18),
            font: .systemFont(ofSize: 14, weight: .bold),
            color: ReportTheme.accent,
            alignment: .right
        )
        drawBadge(
            "可信 \(record.confidence.rawValue)",
            in: CGRect(x: rect.maxX - 76, y: rect.minY + 40, width: 60, height: 20),
            fill: ReportTheme.accent.withAlphaComponent(0.08),
            textColor: ReportTheme.secondaryText
        )
    }

    /// 与饮品营养识别的杯型估算档位保持一致（小杯300/中杯350/大杯480/超大杯650，按中点分档）
    private static func cupSizeLabel(forML sizeML: Double?) -> String {
        guard let sizeML else { return "杯型未知" }
        switch sizeML {
        case ..<325: return "小杯"
        case 325..<415: return "中杯"
        case 415..<565: return "大杯"
        default: return "超大杯"
        }
    }

    // MARK: - 补剂知识库 PDF

    @MainActor
    static func exportSupplementLibraryPDF(records: [SupplementRecord]) throws -> Data {
        guard !records.isEmpty else { throw ExportService.PDFExportError.emptySupplementSelection }

        let groups = Dictionary(grouping: records) { $0.brand.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { (brand: $0.key, records: $0.value.sorted { lhs, rhs in
                lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
            }) }
            .sorted { $0.brand.localizedCompare($1.brand) == .orderedAscending }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let contentWidth = pageRect.width - ReportTheme.margin * 2
        let cardHeight: CGFloat = 104
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            var pageNumber = 0
            func startPage() {
                context.beginPage()
                pageNumber += 1
                ReportTheme.background.setFill()
                UIGraphicsGetCurrentContext()?.fill(pageRect)
                if pageNumber == 1 {
                    drawSupplementLibraryHeader(recordCount: records.count, brandCount: groups.count, pageRect: pageRect)
                } else {
                    drawLibraryContinuationHeader(title: "1Life 补剂营养图鉴", pageNumber: pageNumber, pageRect: pageRect)
                }
                drawLibraryFooter(pageNumber: pageNumber, pageRect: pageRect)
            }

            startPage()
            var y: CGFloat = 124

            func ensureSpace(_ height: CGFloat) {
                guard y + height > pageRect.height - 36 else { return }
                startPage()
                y = 72
            }

            for group in groups {
                ensureSpace(26 + cardHeight + 8)
                let brandTitle = group.brand.isEmpty ? "未标品牌" : group.brand
                drawLibraryBrandHeader(title: brandTitle, count: group.records.count, y: y, width: contentWidth, tint: ReportTheme.accent)
                y += 30

                for record in group.records {
                    ensureSpace(cardHeight + 8)
                    drawSupplementCard(record, rect: CGRect(x: ReportTheme.margin, y: y, width: contentWidth, height: cardHeight))
                    y += cardHeight + 8
                }
                y += 8
            }
        }
    }

    private static func drawSupplementLibraryHeader(recordCount: Int, brandCount: Int, pageRect: CGRect) {
        let headerRect = CGRect(x: 0, y: 0, width: pageRect.width, height: 104)
        ReportTheme.panel.setFill()
        UIBezierPath(rect: headerRect).fill()

        drawText(
            "1Life 补剂营养图鉴",
            in: CGRect(x: ReportTheme.margin, y: 24, width: 260, height: 26),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: ReportTheme.primaryText
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        drawText(
            "\(formatter.string(from: .now)) 导出 · \(brandCount) 个品牌 · \(recordCount) 个版本",
            in: CGRect(x: ReportTheme.margin, y: 56, width: 340, height: 20),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: ReportTheme.secondaryText
        )
        drawBadge(
            "补剂知识库",
            in: CGRect(x: pageRect.width - ReportTheme.margin - 92, y: 34, width: 92, height: 26),
            fill: ReportTheme.accent.withAlphaComponent(0.12),
            textColor: ReportTheme.accent
        )
    }

    private static func drawSupplementCard(_ record: SupplementRecord, rect: CGRect) {
        drawCard(rect, fill: ReportTheme.panel)
        drawLibraryCardAccent(in: rect, color: ReportTheme.accent)
        let x = rect.minX + 18
        let textWidth = rect.width - 150

        var specs: [String] = []
        if !record.form.isEmpty { specs.append(record.form) }
        if !record.servingSize.isEmpty { specs.append("每份 \(record.servingSize)") }
        let specLine = specs.isEmpty ? "剂型/规格未知" : specs.joined(separator: " · ")

        drawText(
            record.productName.isEmpty ? "未命名补剂" : record.productName,
            in: CGRect(x: x, y: rect.minY + 10, width: textWidth, height: 17),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: ReportTheme.primaryText
        )
        drawText(
            specLine,
            in: CGRect(x: x, y: rect.minY + 28, width: textWidth, height: 14),
            font: .systemFont(ofSize: 10.5, weight: .medium),
            color: ReportTheme.secondaryText
        )

        var nutrients: [String] = []
        if let calories = record.calories { nutrients.append("热量 \(Int(calories))kcal") }
        if let protein = record.protein { nutrients.append("蛋白 \(pdfNumber(protein))g") }
        if let vitaminC = record.vitaminC { nutrients.append("VC \(pdfNumber(vitaminC))mg") }
        if let vitaminD = record.vitaminD { nutrients.append("VD \(pdfNumber(vitaminD))ug") }
        drawText(
            nutrients.isEmpty ? "标准营养素未记录" : nutrients.joined(separator: "   "),
            in: CGRect(x: x, y: rect.minY + 46, width: textWidth, height: 13),
            font: .monospacedSystemFont(ofSize: 9.5, weight: .medium),
            color: ReportTheme.secondaryText
        )

        let activeText = record.activeIngredientsNote.isEmpty ? "其它活性成分：未记录" : "其它活性成分：\(record.activeIngredientsNote)"
        drawParagraph(
            activeText,
            in: CGRect(x: x, y: rect.minY + 62, width: textWidth, height: 28),
            font: .systemFont(ofSize: 9.5, weight: .medium),
            color: ReportTheme.secondaryText
        )

        drawBadge(
            "可信 \(record.confidence.rawValue)",
            in: CGRect(x: rect.maxX - 76, y: rect.minY + 14, width: 60, height: 20),
            fill: ReportTheme.accent.withAlphaComponent(0.08),
            textColor: ReportTheme.secondaryText
        )
    }

    private static func drawLibraryContinuationHeader(title: String, pageNumber: Int, pageRect: CGRect) {
        ReportTheme.panel.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageRect.width, height: 54)).fill()
        drawText(title, in: CGRect(x: ReportTheme.margin, y: 16, width: 280, height: 18), font: .systemFont(ofSize: 13, weight: .bold), color: ReportTheme.primaryText)
        drawText("第 \(pageNumber) 页", in: CGRect(x: pageRect.width - ReportTheme.margin - 70, y: 17, width: 70, height: 16), font: .systemFont(ofSize: 10, weight: .medium), color: ReportTheme.secondaryText, alignment: .right)
    }

    private static func drawLibraryFooter(pageNumber: Int, pageRect: CGRect) {
        drawText("1Life · 个人营养资料库", in: CGRect(x: ReportTheme.margin, y: pageRect.height - 25, width: 180, height: 12), font: .systemFont(ofSize: 8.5, weight: .medium), color: ReportTheme.secondaryText)
        drawText("\(pageNumber)", in: CGRect(x: pageRect.width - ReportTheme.margin - 24, y: pageRect.height - 25, width: 24, height: 12), font: .monospacedSystemFont(ofSize: 8.5, weight: .medium), color: ReportTheme.secondaryText, alignment: .right)
    }

    private static func drawLibraryBrandHeader(title: String, count: Int, y: CGFloat, width: CGFloat, tint: UIColor) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(1.5)
        context?.setStrokeColor(tint.cgColor)
        context?.move(to: CGPoint(x: ReportTheme.margin, y: y + 20))
        context?.addLine(to: CGPoint(x: ReportTheme.margin + width, y: y + 20))
        context?.strokePath()
        drawText(title.uppercased(), in: CGRect(x: ReportTheme.margin + 8, y: y, width: width - 100, height: 18), font: .systemFont(ofSize: 11, weight: .bold), color: ReportTheme.primaryText)
        drawText("\(count) 条记录", in: CGRect(x: ReportTheme.margin + width - 90, y: y, width: 82, height: 18), font: .systemFont(ofSize: 9.5, weight: .medium), color: ReportTheme.secondaryText, alignment: .right)
    }

    private static func drawLibraryCardAccent(in rect: CGRect, color: UIColor) {
        color.setFill()
        UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 4, height: rect.height), cornerRadius: 2).fill()
    }

    private static func pdfNumber(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

nonisolated private struct PDFDayReport {
    let date: Date
    let summary: DailyNutritionSummary
    let meals: [Meal]
    let workouts: [WorkoutLog]
    let calorieTarget: Double
    let proteinTarget: Double
    let carbsTarget: Double
    let fatTarget: Double
    let waterTarget: Double
    let latestMeasurement: BodyMeasurement?
    let previousMeasurement: BodyMeasurement?
    let heightCm: Double?
    let bowelLogs: [BowelLog]
}

nonisolated private struct PDFMetricCard {
    let title: String
    let current: Double
    let target: Double
    let tint: UIColor
    let unit: String
}

nonisolated private enum ReportTheme {
    nonisolated static let margin: CGFloat = 28
    nonisolated static let cardRadius: CGFloat = 12
    nonisolated static let background = UIColor(red: 0.957, green: 0.945, blue: 0.922, alpha: 1)
    nonisolated static let panel = UIColor.white
    nonisolated static let border = UIColor(white: 0.86, alpha: 0.72)
    nonisolated static let primaryText = UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1)
    nonisolated static let secondaryText = UIColor(red: 0.36, green: 0.35, blue: 0.32, alpha: 1)
    nonisolated static let accent = UIColor(red: 0.12, green: 0.36, blue: 0.82, alpha: 1)
}
