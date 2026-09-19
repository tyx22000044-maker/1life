import Foundation

nonisolated enum CSVExportService {
    static func exportCSV(
        settings: UserSettings?,
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog],
        granularity: ExportService.CSVGranularity
    ) -> String {
        switch granularity {
        case .detail:
            return exportDetailCSV(meals: meals, bodyMeasurements: bodyMeasurements)
        case .dailySummary:
            return exportDailySummaryCSV(
                settings: settings,
                meals: meals,
                waterLogs: waterLogs,
                workouts: workouts,
                bodyMeasurements: bodyMeasurements,
                bowelLogs: bowelLogs
            )
        }
    }

    private static func exportDetailCSV(meals: [Meal], bodyMeasurements: [BodyMeasurement]) -> String {
        var csv = csvRow(["日期", "时间", "餐次", "食物名称", "份量", "单位", "克数", "热量", "蛋白质", "碳水", "脂肪", "纤维", "钠", "糖", "胆固醇", "咖啡因", "茶多酚", "钙", "镁", "钾", "铁", "锌", "维生素A", "维生素C", "维生素D", "维生素E", "维生素B1", "维生素B2", "烟酸", "维生素B6", "叶酸", "维生素B12", "体重kg", "体脂%", "来源", "营养数据依据", "标签基准量", "标签基准单位", "包装净含量", "包装单位", "实际食用量", "实际食用单位", "营养备注"])
        let sorted = meals.sorted { $0.date < $1.date }
        for meal in sorted {
            let measurement = latestBodyMeasurement(on: meal.date, from: bodyMeasurements)
            for item in (meal.foodItems ?? []) {
                var cols: [String] = []
                cols.append(formatISODate(meal.date))
                cols.append(formatTime(meal.date))
                cols.append(mealTypeName(meal.mealType))
                cols.append(item.name)
                cols.append(formatDecimal(item.amount))
                cols.append(item.unit)
                cols.append("\(Int(item.servingGrams))")
                cols.append("\(Int(item.calories))")
                cols.append(optNumber(item.protein))
                cols.append(optNumber(item.carbs))
                cols.append(optNumber(item.fat))
                cols.append(optNumber(item.fiber))
                cols.append(optNumber(item.sodium))
                cols.append(optNumber(item.sugar))
                cols.append(optNumber(item.cholesterol))
                cols.append(optNumber(item.caffeine))
                cols.append(optNumber(item.teaPolyphenols))
                cols.append(optNumber(item.calcium))
                cols.append(optNumber(item.magnesium))
                cols.append(optNumber(item.potassium))
                cols.append(optNumber(item.iron))
                cols.append(optNumber(item.zinc))
                cols.append(optNumber(item.vitaminA))
                cols.append(optNumber(item.vitaminC))
                cols.append(optNumber(item.vitaminD))
                cols.append(optNumber(item.vitaminE))
                cols.append(optNumber(item.vitaminB1))
                cols.append(optNumber(item.vitaminB2))
                cols.append(optNumber(item.niacin))
                cols.append(optNumber(item.vitaminB6))
                cols.append(optNumber(item.folate))
                cols.append(optNumber(item.vitaminB12))
                cols.append(optNumber(measurement?.weightKg))
                cols.append(optNumber(measurement?.bodyFatPercentage))
                cols.append(item.source.rawValue)
                cols.append(nutritionDataBasisName(item.nutritionDataBasis))
                cols.append(optNumber(item.labelBaseAmount))
                cols.append(item.labelBaseUnit ?? "")
                cols.append(optNumber(item.packageNetAmount))
                cols.append(item.packageNetUnit ?? "")
                cols.append(optNumber(item.consumedAmount))
                cols.append(item.consumedUnit ?? "")
                cols.append(item.nutritionDataNote ?? "")
                csv += csvRow(cols)
            }
        }
        return csv
    }

    private static func exportDailySummaryCSV(
        settings: UserSettings?,
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog]
    ) -> String {
        var csv = csvRow(["日期", "总热量", "蛋白质", "碳水", "脂肪", "纤维", "钠", "糖", "胆固醇", "咖啡因", "茶多酚", "钙", "镁", "钾", "铁", "锌", "维生素A", "维生素C", "维生素D", "维生素E", "维生素B1", "维生素B2", "烟酸", "维生素B6", "叶酸", "维生素B12", "饮水量ml", "餐数", "食物项数", "训练次数", "训练分钟", "训练消耗kcal", "排便次数", "排便类型", "体重kg", "体脂%", "BMI"])

        let grouped = Dictionary(grouping: meals) { formatISODate($0.date) }
        let waterGrouped = Dictionary(grouping: waterLogs) { formatISODate($0.date) }
        let workoutGrouped = Dictionary(grouping: workouts) { formatISODate($0.startDate) }
        let bowelGrouped = Dictionary(grouping: bowelLogs) { formatISODate($0.date) }
        let bodyDates = bodyMeasurements.map { formatISODate($0.date) }
        let allDates = Set(grouped.keys)
            .union(waterGrouped.keys)
            .union(workoutGrouped.keys)
            .union(bowelGrouped.keys)
            .union(bodyDates)

        for date in allDates.sorted() {
            let dayMeals = grouped[date] ?? []
            let items = dayMeals.flatMap { $0.foodItems ?? [] }
            let water = (waterGrouped[date] ?? []).reduce(0.0) { $0 + $1.amount }
            let dayWorkouts = workoutGrouped[date] ?? []
            let trainingWorkouts = dayWorkouts.filter { !$0.isRestDay }
            let workoutMinutes = trainingWorkouts.reduce(0.0) { $0 + $1.durationMinutes }
            let workoutCalories = trainingWorkouts.reduce(0.0) { $0 + ($1.caloriesBurned ?? 0) }
            let dayBowels = bowelGrouped[date] ?? []
            let measurement = latestBodyMeasurement(on: parseISODate(date) ?? .now, from: bodyMeasurements)
            let bmi = bmiValue(weightKg: measurement?.weightKg, heightCm: settings?.heightCm)

            var cols: [String] = []
            cols.append(date)
            cols.append(formatNumber(items.reduce(0) { $0 + $1.calories }))
            cols.append(formatNumber(items.compactMap(\.protein).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.carbs).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.fat).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.fiber).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.sodium).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.sugar).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.cholesterol).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.caffeine).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.teaPolyphenols).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.calcium).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.magnesium).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.potassium).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.iron).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.zinc).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminA).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminC).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminD).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminE).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminB1).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminB2).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.niacin).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminB6).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.folate).reduce(0, +)))
            cols.append(formatNumber(items.compactMap(\.vitaminB12).reduce(0, +)))
            cols.append("\(Int(water))")
            cols.append("\(dayMeals.count)")
            cols.append("\(items.count)")
            cols.append("\(trainingWorkouts.count)")
            cols.append(formatNumber(workoutMinutes))
            cols.append(formatNumber(workoutCalories))
            cols.append("\(dayBowels.count)")
            cols.append(dayBowels.map { bristolDisplayName(rawValue: $0.bristolTypeRaw) }.joined(separator: " / "))
            cols.append(optNumber(measurement?.weightKg))
            cols.append(optNumber(measurement?.bodyFatPercentage))
            cols.append(optNumber(bmi))
            csv += csvRow(cols)
        }
        return csv
    }

    private static func optNumber(_ value: Double?) -> String {
        value.map(formatNumber) ?? ""
    }

    private static func bmiValue(weightKg: Double?, heightCm: Double?) -> Double? {
        guard let weightKg, let heightCm, heightCm > 0 else { return nil }
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    /// Machine-readable fields never follow the device locale: a locale that writes
    /// decimals with a comma would otherwise inject the CSV separator into a number.
    static let machineLocale = Locale(identifier: "en_US_POSIX")

    static func formatDecimal(_ value: Double) -> String {
        String(format: "%.1f", locale: machineLocale, arguments: [value])
    }

    /// Local wall-clock time; the export copy in Settings states the timezone meaning.
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = machineLocale
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func formatISODate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = machineLocale
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func parseISODate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = machineLocale
        formatter.timeZone = .current
        return formatter.date(from: value)
    }

    private static func latestBodyMeasurement(on date: Date, from measurements: [BodyMeasurement]) -> BodyMeasurement? {
        let dayEnd = calendarDayEnd(for: date)
        return measurements
            .filter { $0.date <= dayEnd }
            .sorted { $0.date > $1.date }
            .first
    }

    private static func calendarDayEnd(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? date
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

    private static func nutritionDataBasisName(_ basis: NutritionDataBasis) -> String {
        switch basis {
        case .direct: return "直接录入"
        case .per100g: return "每100g标签换算"
        case .per100ml: return "每100ml标签换算"
        case .perServing: return "每份标签换算"
        case .estimated: return "估算"
        }
    }

    private static func csvRow(_ columns: [String]) -> String {
        columns.map(csvField).joined(separator: ",") + "\n"
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func formatNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.005 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.2f", locale: machineLocale, arguments: [value])
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
}
