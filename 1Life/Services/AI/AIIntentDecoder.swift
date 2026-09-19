import Foundation

/// Model output is untrusted input: prompts can nudge it, they cannot bound it.
/// Anything non-finite, negative or physically impossible is dropped here so it never
/// reaches the review card, let alone the store.
nonisolated enum AIValueBounds {
    static let waterML: ClosedRange<Double> = 1...3_000
    static let workoutMinutes: ClosedRange<Double> = 1...1_440
    static let workoutCalories: ClosedRange<Double> = 0...5_000
    static let habitValue: ClosedRange<Double> = 0...10_000
    static var weightKg: ClosedRange<Double> { BodyMeasurementLimits.weightKg }
    static var bodyFatPercent: ClosedRange<Double> { BodyMeasurementLimits.bodyFatPercent }
    static let foodAmount: ClosedRange<Double> = 0...5_000
    static let mealCalories: ClosedRange<Double> = 0...10_000

    static func nutrient(_ key: NutrientKey) -> ClosedRange<Double> {
        switch key.unit {
        case "g": return 0...5_000
        case "mg": return 0...100_000
        default: return 0...100_000
        }
    }

    /// Returns nil when the value is unusable, leaving the caller to fall back or omit.
    static func clamped(_ value: Double?, to range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }

    static func clamped(_ value: Double?, to range: ClosedRange<Double>, otherwise fallback: Double) -> Double {
        clamped(value, to: range) ?? fallback
    }
}

struct AIIntentDecoder {
    func decode(from text: String) -> AIChatIntentResult? {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return decodeJSON(json, fallback: text)
    }

    private func decodeJSON(_ json: [String: Any], fallback: String = "") -> AIChatIntentResult? {
        guard let intent = json["intent"] as? String else { return nil }

        switch intent {
        case "add_meal", "recognize_meal_photo":
            return decodeSingleMeal(json)
        case "add_meals":
            return decodeMultipleMeals(json)
        case "create_template":
            return decodeCreateTemplate(json)
        case "add_water":
            guard let amount = AIValueBounds.clamped(json["amount"] as? Double ?? 250, to: AIValueBounds.waterML) else {
                return .chat("这个水量数值不合理，我没有写入。请确认毫升数后再说一次。")
            }
            return .addWater(amount)
        case "add_journal":
            let content = json["content"] as? String ?? ""
            let moodStr = json["mood"] as? String
            let mood = moodStr.flatMap { Mood(rawValue: $0) }
            let tagStrs = json["tags"] as? [String] ?? []
            let tags = tagStrs.compactMap { ActivityTag(rawValue: $0) }
            return .addJournal(content: content, mood: mood, tags: tags)
        case "add_habit_log":
            let name = json["habit_name"] as? String ?? ""
            let value = AIValueBounds.clamped(json["value"] as? Double ?? 1, to: AIValueBounds.habitValue, otherwise: 1)
            return .addHabitLog(habitName: name, value: value)
        case "add_workout":
            return decodeWorkout(json)
        case "add_body_measurement":
            let weightKg = AIValueBounds.clamped(json["weight_kg"] as? Double, to: AIValueBounds.weightKg)
            let bodyFatPercentage = AIValueBounds.clamped(json["body_fat_percentage"] as? Double, to: AIValueBounds.bodyFatPercent)
            let note = json["note"] as? String ?? ""
            guard weightKg != nil || bodyFatPercentage != nil else {
                return .chat("这次的体重或体脂数值超出合理范围，我没有写入，请确认后重新记录。")
            }
            return .addBodyMeasurement(AIParsedBodyMeasurement(weightKg: weightKg, bodyFatPercentage: bodyFatPercentage, note: note))
        case "add_bowel_log":
            let typeRaw = json["bristol_type"] as? String ?? "normal"
            let type = BristolStoolType(rawValue: typeRaw) ?? .normal
            let note = json["note"] as? String ?? ""
            return .addBowelLog(AIParsedBowelLog(bristolType: type, note: note))
        case "batch":
            guard let actions = json["actions"] as? [[String: Any]] else { return .chat(fallback) }
            let results = actions.compactMap { decodeJSON($0) }
            guard !results.isEmpty else { return .chat(fallback) }
            return results.count == 1 ? results[0] : .batch(results)
        case "get_fitness_summary":
            return .fitnessSummary
        case "get_energy_analysis":
            return .energyAnalysis
        case "get_post_workout_nutrition_advice":
            return .postWorkoutNutritionAdvice
        case "chat":
            let response = json["response"] as? String ?? fallback
            return .chat(response)
        default:
            return .chat(fallback)
        }
    }

    private func decodeWorkout(_ json: [String: Any]) -> AIChatIntentResult? {
        let typeRaw = json["workout_type"] as? String ?? "other"
        let type = WorkoutType(rawValue: typeRaw) ?? .other
        let duration = AIValueBounds.clamped(json["duration_minutes"] as? Double ?? 30,
                                            to: AIValueBounds.workoutMinutes,
                                            otherwise: 30)
        let calories = AIValueBounds.clamped(json["calories_burned"] as? Double, to: AIValueBounds.workoutCalories)
        let intensityRaw = json["intensity"] as? String ?? "moderate"
        let intensity = WorkoutIntensity(rawValue: intensityRaw) ?? .moderate
        let note = json["note"] as? String ?? ""
        return .addWorkout(AIParsedWorkout(
            workoutType: type,
            durationMinutes: duration,
            caloriesBurned: calories,
            intensity: intensity,
            note: note
        ))
    }

    private func decodeSingleMeal(_ json: [String: Any]) -> AIChatIntentResult? {
        guard let meal = parseMealObject(json) else { return nil }
        return .addMeal(meal)
    }

    private func decodeCreateTemplate(_ json: [String: Any]) -> AIChatIntentResult? {
        let name = (json["template_name"] as? String ?? json["name"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let meal = parseMealObject(json) else { return nil }
        return .createTemplate(name: name, meal: meal)
    }

    private func decodeMultipleMeals(_ json: [String: Any]) -> AIChatIntentResult? {
        guard let mealsArray = json["meals"] as? [[String: Any]] else { return nil }
        let meals = mealsArray.compactMap { parseMealObject($0) }
        guard !meals.isEmpty else { return nil }
        if meals.count == 1 { return .addMeal(meals[0]) }
        return .addMeals(meals)
    }

    private func parseMealObject(_ json: [String: Any]) -> AIParsedMeal? {
        let mealTypeStr = json["meal_type"] as? String ?? ""
        let mealType = MealType(rawValue: mealTypeStr) ?? .guessByTime()
        let note = json["note"] as? String ?? ""

        guard let itemsArray = json["items"] as? [[String: Any]] else { return nil }
        let items = itemsArray.compactMap { parseFoodItem($0) }
        guard !items.isEmpty else { return nil }

        return AIParsedMeal(mealType: mealType, items: items, note: note)
    }

    private func parseFoodItem(_ json: [String: Any]) -> AIParsedFoodItem? {
        guard let name = json["name"] as? String, !name.isEmpty else { return nil }
        let amount = AIValueBounds.clamped(json["amount"] as? Double, to: AIValueBounds.foodAmount, otherwise: 1)
        let unit = json["unit"] as? String ?? "g"
        let calories = AIValueBounds.clamped(json["calories"] as? Double, to: AIValueBounds.mealCalories, otherwise: 0)

        var nutrients: [NutrientKey: Double] = [:]
        for key in NutrientKey.allCases {
            nutrients[key] = AIValueBounds.clamped(json[key.jsonKey] as? Double, to: AIValueBounds.nutrient(key))
        }
        func nutrient(_ key: NutrientKey) -> Double? { nutrients[key] }

        let basisRaw = json["nutrition_data_basis"] as? String
        let basis = basisRaw.flatMap { NutritionDataBasis(rawValue: $0) } ?? .estimated
        let labelBaseAmount = AIValueBounds.clamped(json["label_base_amount"] as? Double, to: AIValueBounds.foodAmount)
        let labelBaseUnit = json["label_base_unit"] as? String
        let packageNetAmount = AIValueBounds.clamped(json["package_net_amount"] as? Double, to: AIValueBounds.foodAmount)
        let packageNetUnit = json["package_net_unit"] as? String
        let consumedAmount = AIValueBounds.clamped(json["consumed_amount"] as? Double, to: AIValueBounds.foodAmount)
        let consumedUnit = json["consumed_unit"] as? String
        let nutritionDataNote = json["nutrition_data_note"] as? String
        let amountMin = AIValueBounds.clamped(json["amount_min"] as? Double, to: AIValueBounds.foodAmount)
        let amountMax = AIValueBounds.clamped(json["amount_max"] as? Double, to: AIValueBounds.foodAmount)
        let caloriesMin = AIValueBounds.clamped(json["calories_min"] as? Double, to: AIValueBounds.mealCalories)
        let caloriesMax = AIValueBounds.clamped(json["calories_max"] as? Double, to: AIValueBounds.mealCalories)
        let confidence = json["confidence"] as? String

        return AIParsedFoodItem(
            name: name, amount: amount, unit: unit,
            calories: calories,
            protein: nutrient(.protein), carbs: nutrient(.carbs), fat: nutrient(.fat),
            fiber: nutrient(.fiber), sodium: nutrient(.sodium), sugar: nutrient(.sugar),
            cholesterol: nutrient(.cholesterol), caffeine: nutrient(.caffeine),
            teaPolyphenols: nutrient(.teaPolyphenols),
            calcium: nutrient(.calcium), magnesium: nutrient(.magnesium), potassium: nutrient(.potassium),
            iron: nutrient(.iron), zinc: nutrient(.zinc), vitaminA: nutrient(.vitaminA),
            vitaminC: nutrient(.vitaminC), vitaminD: nutrient(.vitaminD), vitaminE: nutrient(.vitaminE),
            vitaminB1: nutrient(.vitaminB1), vitaminB2: nutrient(.vitaminB2),
            niacin: nutrient(.niacin), vitaminB6: nutrient(.vitaminB6),
            folate: nutrient(.folate), vitaminB12: nutrient(.vitaminB12),
            nutritionDataBasis: basis,
            labelBaseAmount: labelBaseAmount,
            labelBaseUnit: labelBaseUnit,
            packageNetAmount: packageNetAmount,
            packageNetUnit: packageNetUnit,
            consumedAmount: consumedAmount,
            consumedUnit: consumedUnit,
            nutritionDataNote: nutritionDataNote,
            amountMin: amountMin,
            amountMax: amountMax,
            caloriesMin: caloriesMin,
            caloriesMax: caloriesMax,
            confidence: confidence
        )
    }

    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }
}
