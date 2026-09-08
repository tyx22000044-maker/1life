import Foundation

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
            let amount = json["amount"] as? Double ?? 250
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
            let value = json["value"] as? Double ?? 1
            return .addHabitLog(habitName: name, value: value)
        case "add_workout":
            return decodeWorkout(json)
        case "add_body_measurement":
            let weightKg = json["weight_kg"] as? Double
            let bodyFatPercentage = json["body_fat_percentage"] as? Double
            let note = json["note"] as? String ?? ""
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
        let duration = json["duration_minutes"] as? Double ?? 30
        let calories = json["calories_burned"] as? Double
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
        let amount = json["amount"] as? Double ?? 1
        let unit = json["unit"] as? String ?? "g"
        let calories = json["calories"] as? Double ?? 0
        let protein = json["protein"] as? Double
        let carbs = json["carbs"] as? Double
        let fat = json["fat"] as? Double
        let fiber = json["fiber"] as? Double
        let sodium = json["sodium"] as? Double
        let sugar = json["sugar"] as? Double
        let cholesterol = json["cholesterol"] as? Double
        let caffeine = json["caffeine"] as? Double
        let teaPolyphenols = json["tea_polyphenols"] as? Double
        let calcium = json["calcium"] as? Double
        let magnesium = json["magnesium"] as? Double
        let potassium = json["potassium"] as? Double
        let iron = json["iron"] as? Double
        let zinc = json["zinc"] as? Double
        let vitaminA = json["vitamin_a"] as? Double
        let vitaminC = json["vitamin_c"] as? Double
        let vitaminD = json["vitamin_d"] as? Double
        let vitaminE = json["vitamin_e"] as? Double
        let vitaminB1 = json["vitamin_b1"] as? Double
        let vitaminB2 = json["vitamin_b2"] as? Double
        let niacin = json["niacin"] as? Double
        let vitaminB6 = json["vitamin_b6"] as? Double
        let folate = json["folate"] as? Double
        let vitaminB12 = json["vitamin_b12"] as? Double
        let basisRaw = json["nutrition_data_basis"] as? String
        let basis = basisRaw.flatMap { NutritionDataBasis(rawValue: $0) } ?? .estimated
        let labelBaseAmount = json["label_base_amount"] as? Double
        let labelBaseUnit = json["label_base_unit"] as? String
        let packageNetAmount = json["package_net_amount"] as? Double
        let packageNetUnit = json["package_net_unit"] as? String
        let consumedAmount = json["consumed_amount"] as? Double
        let consumedUnit = json["consumed_unit"] as? String
        let nutritionDataNote = json["nutrition_data_note"] as? String
        let amountMin = json["amount_min"] as? Double
        let amountMax = json["amount_max"] as? Double
        let caloriesMin = json["calories_min"] as? Double
        let caloriesMax = json["calories_max"] as? Double
        let confidence = json["confidence"] as? String

        return AIParsedFoodItem(
            name: name, amount: amount, unit: unit,
            calories: calories, protein: protein, carbs: carbs, fat: fat,
            fiber: fiber, sodium: sodium, sugar: sugar, cholesterol: cholesterol,
            caffeine: caffeine,
            teaPolyphenols: teaPolyphenols,
            calcium: calcium, magnesium: magnesium, potassium: potassium,
            iron: iron, zinc: zinc, vitaminA: vitaminA, vitaminC: vitaminC,
            vitaminD: vitaminD, vitaminE: vitaminE, vitaminB1: vitaminB1,
            vitaminB2: vitaminB2, niacin: niacin, vitaminB6: vitaminB6,
            folate: folate, vitaminB12: vitaminB12,
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
