import Foundation

struct LocalAIIntentParser {
    let userFoods: [UserFood]
    let mealTemplates: [MealTemplate]
    let cupML: Double
    let bottleML: Double

    init(userFoods: [UserFood] = [],
         mealTemplates: [MealTemplate] = [],
         cupML: Double = 250,
         bottleML: Double = 500) {
        self.userFoods = userFoods
        self.mealTemplates = mealTemplates
        self.cupML = cupML
        self.bottleML = bottleML
    }

    func parse(_ text: String) -> AIChatIntentResult? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        let segments = actionSegments(of: input)
        if segments.count > 1 {
            var results: [AIChatIntentResult] = []
            for segment in segments {
                guard let result = parseSingle(segment) else {
                    results = []
                    break
                }
                results.append(result)
            }
            if results.count > 1 { return .batch(results) }
            if results.count == 1 { return results[0] }
        }

        return parseSingle(input)
    }

    /// “今天跑步30分钟，然后喝了500ml水” used to return only the workout and drop the
    /// water. Splitting is all-or-nothing: if any fragment fails to parse on its own the
    /// whole sentence is parsed as before, so “跑了35分钟，消耗300千卡” keeps its calories.
    private func actionSegments(of text: String) -> [String] {
        var normalized = text
        for connector in ["然后", "之後", "之后", "接着", "接著", "顺便", "順便", "另外", "并且", "並且", "同时", "同時"] {
            normalized = normalized.replacingOccurrences(of: connector, with: "，")
        }
        // A duration followed by 后 opens the next action: “跑步30分钟后喝水”.
        normalized = normalized.replacingOccurrences(
            of: #"([0-9]+(?:\s*(?:分钟|小时|秒))?)\s*后"#,
            with: "$1，",
            options: .regularExpression
        )

        return normalized
            .components(separatedBy: CharacterSet(charactersIn: "，,。；;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseSingle(_ text: String) -> AIChatIntentResult? {
        if let workout = parseWorkout(text) { return workout }
        if let bowel = parseBowelLog(text) { return bowel }
        if let bodyMeasurement = parseBodyMeasurement(text) { return bodyMeasurement }
        if let fitnessQuery = parseFitnessQuery(text) { return fitnessQuery }
        if let water = parseWater(text) { return water }
        if let journal = parseJournal(text) { return journal }
        // 创建模板的请求交给 AI 解析（create_template 意图），本地不拦截
        if mentionsTemplate(text), expressesTemplateCreation(text) { return nil }
        if let templateMeal = parseMealTemplate(text) { return templateMeal }
        if mentionsTemplate(text) {
            return .chat("没有在模板库找到这个模板。你可以先在模板库创建、或让我帮你生成模板（例如“帮我建一个早餐模板：鸡蛋2个+牛奶250ml”），也可以直接描述这次记录。")
        }
        if let meal = parseMeal(text) { return meal }
        return nil
    }

    // MARK: - Workout

    private func parseWorkout(_ text: String) -> AIChatIntentResult? {
        let keywords = ["跑步", "健身", "训练", "力量", "骑行", "游泳", "瑜伽", "HIIT", "步行", "散步", "运动"]
        guard keywords.contains(where: { text.contains($0) }) else { return nil }
        guard ["记录", "练了", "做了", "跑了", "骑了", "游了", "运动了", "训练了"].contains(where: { text.contains($0) }) else { return nil }

        let duration = extractMinutes(text) ?? 30
        let calories = extractCalories(text)
        return .addWorkout(AIParsedWorkout(
            workoutType: detectWorkoutType(text),
            durationMinutes: duration,
            caloriesBurned: calories,
            intensity: detectWorkoutIntensity(text),
            note: text
        ))
    }

    private func parseFitnessQuery(_ text: String) -> AIChatIntentResult? {
        if ["本周训练", "训练摘要", "运动摘要", "练了几次", "练了多久"].contains(where: { text.contains($0) }) {
            return .fitnessSummary
        }
        if ["摄入消耗", "热量缺口", "热量盈余", "今天消耗", "能量状态"].contains(where: { text.contains($0) }) {
            return .energyAnalysis
        }
        if ["训练后吃什么", "练后吃什么", "训练后营养", "补蛋白", "补碳"].contains(where: { text.contains($0) }) {
            return .postWorkoutNutritionAdvice
        }
        return nil
    }

    private func detectWorkoutType(_ text: String) -> WorkoutType {
        if text.contains("力量") || text.contains("健身") || text.contains("撸铁") { return .strength }
        if text.contains("跑") { return .running }
        if text.contains("骑") { return .cycling }
        if text.contains("游") { return .swimming }
        if text.contains("瑜伽") { return .yoga }
        if text.contains("HIIT") || text.contains("间歇") { return .hiit }
        if text.contains("球") { return .ballSports }
        if text.contains("走") || text.contains("散步") || text.contains("步行") { return .walking }
        return .other
    }

    private func detectWorkoutIntensity(_ text: String) -> WorkoutIntensity {
        if ["高强度", "很累", "冲刺", "大强度"].contains(where: { text.contains($0) }) { return .high }
        if ["低强度", "轻松", "恢复"].contains(where: { text.contains($0) }) { return .low }
        return .moderate
    }

    private func extractMinutes(_ text: String) -> Double? {
        if let value = firstCapture(#"(\d+(?:\.\d+)?)\s*(?:分钟|min)"#, in: text) {
            return value
        }
        if let value = firstCapture(#"(\d+(?:\.\d+)?)\s*(?:小时|h)"#, in: text) {
            return value * 60
        }
        return nil
    }

    private func extractCalories(_ text: String) -> Double? {
        firstCapture(#"(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡|卡)"#, in: text)
    }

    /// Reads the first capture group through `NSRegularExpression`.
    ///
    /// Two silent failure modes lived here before: `String.range(of:options:.regularExpression)`
    /// returns nil for patterns containing an optional group (`(\d+(?:\.\d+)?)…千克` matches
    /// under `NSRegularExpression` but not through that API), and `filter(\.isNumber)` kept the
    /// CJK unit characters 千/克, turning "300千卡" into "300千".
    private func firstCapture(_ pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let group = match.numberOfRanges > 1 ? 1 : 0
        guard let matched = Range(match.range(at: group), in: text) else { return nil }
        return Double(text[matched])
    }

    // MARK: - Body Measurement

    private func parseBowelLog(_ text: String) -> AIChatIntentResult? {
        let keywords = ["排便", "大便", "拉屎", "拉了", "便便", "肠胃"]
        guard keywords.contains(where: { text.contains($0) }) else { return nil }
        guard ["记录", "今天", "昨天", "刚刚", "早上", "晚上", "正常", "偏硬", "偏软", "稀", "水样"].contains(where: { text.contains($0) }) else { return nil }

        return .addBowelLog(AIParsedBowelLog(
            bristolType: detectBristolType(text),
            note: text
        ))
    }

    private func detectBristolType(_ text: String) -> BristolStoolType {
        if ["偏硬", "硬", "干", "颗粒", "费力", "便秘"].contains(where: { text.contains($0) }) { return .hard }
        if ["水样", "水便", "拉水"].contains(where: { text.contains($0) }) { return .watery }
        if ["稀", "腹泻", "拉肚子", "不成形"].contains(where: { text.contains($0) }) { return .loose }
        if ["偏软", "软便", "较软"].contains(where: { text.contains($0) }) { return .soft }
        return .normal
    }

    private func parseBodyMeasurement(_ text: String) -> AIChatIntentResult? {
        let keywords = ["体重", "体脂", "公斤", "kg", "%"]
        guard keywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) else { return nil }
        guard ["记录", "今天", "刚刚", "现在", "测了", "称了", "是", "为"].contains(where: { text.contains($0) }) else { return nil }

        let weight = firstCapture(#"(\d+(?:\.\d+)?)\s*(?:kg|公斤|千克)"#, in: text)
            ?? (text.contains("体重") ? extractNumber(after: "体重", in: text) : nil)
        let bodyFat = firstCapture(#"(\d+(?:\.\d+)?)\s*%"#, in: text)
            ?? (text.contains("体脂") ? extractNumber(after: "体脂", in: text) : nil)

        guard weight != nil || bodyFat != nil else { return nil }
        return .addBodyMeasurement(AIParsedBodyMeasurement(weightKg: weight, bodyFatPercentage: bodyFat, note: text))
    }

    private func extractNumber(after keyword: String, in text: String) -> Double? {
        guard let range = text.range(of: keyword) else { return nil }
        let suffix = String(text[range.upperBound...])
        if let match = suffix.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) {
            return Double(suffix[match])
        }
        return nil
    }

    // MARK: - Water

    private func parseWater(_ text: String) -> AIChatIntentResult? {
        let waterPatterns = ["喝了", "喝水", "喝一杯", "喝一瓶", "饮水"]
        guard waterPatterns.contains(where: { text.contains($0) }) else { return nil }

        let beverageKeywords = ["奶茶", "咖啡", "拿铁", "果茶", "果汁", "可乐", "雪碧", "酸奶",
                                "豆浆", "牛奶", "奶昔", "茶", "美式", "摩卡", "卡布奇诺",
                                "柠檬水", "冰红茶", "绿茶", "乌龙", "椰奶", "燕麦奶"]
        if beverageKeywords.contains(where: { text.contains($0) }) { return nil }

        if let amount = explicitWaterAmount(in: text) { return .addWater(amount) }
        if text.contains("一杯") || text.contains("喝水") { return .addWater(cupML) }

        return .addWater(cupML)
    }

    /// Explicit volume wins over a container count; “两杯水” is two cups, not one.
    private func explicitWaterAmount(in text: String) -> Double? {
        if let millilitres = firstCapture(#"([0-9]+(?:\.[0-9]+)?)\s*(?:ml|毫升)"#, in: text) {
            return millilitres
        }
        return containerServing(in: text)
    }

    private func containerServing(in text: String) -> Double? {
        let pattern = #"([0-9]+|[一二两三四五六七八九十])\s*[大小]?(杯|瓶)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text) else { return nil }
        guard let count = ChineseNumber.double(in: String(text[numberRange])), count > 0 else { return nil }
        return String(text[unitRange]) == "瓶" ? count * bottleML : count * cupML
    }

    // MARK: - Meal

    private func parseMealTemplate(_ text: String) -> AIChatIntentResult? {
        guard mentionsTemplate(text) else { return nil }
        guard ["吃", "用了", "使用", "记录", "补"].contains(where: { text.contains($0) }) else { return nil }

        let mealType = detectMealType(text)
        guard let template = matchMealTemplate(in: text) else { return nil }
        let items = template.foodItems.map { templateFoodItemToAIItem($0, originalText: text) }
        guard !items.isEmpty else { return nil }

        return .addMeal(AIParsedMeal(
            mealType: containsExplicitMealType(text) ? mealType : template.mealType,
            items: items,
            note: "数据来源：模板库「\(template.name)」"
        ))
    }

    private func mentionsTemplate(_ text: String) -> Bool {
        ["模板库", "模板", "模版", "餐食模板", "饮品模板"].contains { text.contains($0) }
    }

    private func expressesTemplateCreation(_ text: String) -> Bool {
        ["创建", "新建", "建一个", "建个", "生成", "做一个", "做个", "帮我建", "存为", "存成", "保存为", "保存成", "加一个", "加个"].contains { text.contains($0) }
    }

    private func containsExplicitMealType(_ text: String) -> Bool {
        ["早餐", "早饭", "午餐", "午饭", "晚餐", "晚饭", "夜宵", "宵夜", "零食", "水果"].contains { text.contains($0) }
    }

    private func matchMealTemplate(in text: String) -> MealTemplate? {
        mealTemplates.first { template in
            text.localizedCaseInsensitiveContains(template.name)
                || template.name.localizedCaseInsensitiveContains(text.replacingOccurrences(of: "模板", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func templateFoodItemToAIItem(_ item: TemplateFoodItem, originalText: String) -> AIParsedFoodItem {
        var parsed = AIParsedFoodItem(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            fiber: item.fiber,
            sodium: item.sodium,
            sugar: item.sugar,
            cholesterol: item.cholesterol,
            caffeine: item.caffeine,
            teaPolyphenols: item.teaPolyphenols,
            calcium: item.calcium,
            magnesium: item.magnesium,
            potassium: item.potassium,
            iron: item.iron,
            zinc: item.zinc,
            vitaminA: item.vitaminA,
            vitaminC: item.vitaminC,
            vitaminD: item.vitaminD,
            vitaminE: item.vitaminE,
            vitaminB1: item.vitaminB1,
            vitaminB2: item.vitaminB2,
            niacin: item.niacin,
            vitaminB6: item.vitaminB6,
            folate: item.folate,
            vitaminB12: item.vitaminB12,
            nutritionDataBasis: item.nutritionDataBasisRaw.flatMap { NutritionDataBasis(rawValue: $0) } ?? .direct,
            labelBaseAmount: item.labelBaseAmount,
            labelBaseUnit: item.labelBaseUnit,
            packageNetAmount: item.packageNetAmount,
            packageNetUnit: item.packageNetUnit,
            consumedAmount: item.consumedAmount,
            consumedUnit: item.consumedUnit,
            nutritionDataNote: templateNutritionDataNote(item.nutritionDataNote),
            confidence: "high"
        )
        applyTemplateDrinkAdjustment(originalText: originalText, to: &parsed)
        return parsed
    }

    private func templateNutritionDataNote(_ note: String?) -> String {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "数据来源：模板库" }
        guard !trimmed.contains("模板库") else { return trimmed }
        return "数据来源：模板库 | 原备注：\(trimmed)"
    }

    private func applyTemplateDrinkAdjustment(originalText: String, to item: inout AIParsedFoodItem) {
        guard isBeverageItem(item),
              shouldApplySugarAdjustment(to: item),
              let requestedSugar = DrinkAdjustmentPolicy.canonicalSugarLevel(in: originalText),
              requestedSugar != .noSugar else { return }

        let range = requestedSugar.calorieRange
        item.calories = max(item.calories + range.midpoint, 0)
        item.sugar = (item.sugar ?? 0) + range.midpoint / 4
        item.confidence = "medium"
        let note = "模板饮品按\(requestedSugar.rawValue)调整：\(range.displayText)"
        if let current = item.nutritionDataNote, !current.isEmpty {
            if !current.contains(note) {
                item.nutritionDataNote = "\(current) | \(note)"
            }
        } else {
            item.nutritionDataNote = note
        }
    }

    private func shouldApplySugarAdjustment(to item: AIParsedFoodItem) -> Bool {
        let normalizedName = DrinkAdjustmentPolicy.normalize(item.name)
        if ["无糖", "零糖", "0糖", "不另外加糖"].contains(where: { normalizedName.contains($0) }) {
            return true
        }
        return DrinkAdjustmentPolicy.canonicalSugarLevel(in: item.name) == nil
    }

    private func isBeverageItem(_ item: AIParsedFoodItem) -> Bool {
        let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["ml", "毫升", "杯"].contains(unit) { return true }
        let beverageWords = ["咖啡", "美式", "拿铁", "奶茶", "果茶", "茶", "豆浆", "牛奶", "酸奶", "饮料", "可乐", "水", "蛋白粉"]
        return beverageWords.contains { item.name.contains($0) }
    }

    private func parseJournal(_ text: String) -> AIChatIntentResult? {
        // Only substantive diary words trigger a journal entry. Phrases like
        // “记录今天”/“帮我记录” are bare record verbs: they accompany meal, water and
        // workout records just as often, and claiming them here swallowed
        // “记录今天吃了一个苹果” before parseMeal ever ran.
        let journalKeywords = ["状态", "复盘", "日记", "日志", "心情"]
        guard journalKeywords.contains(where: { text.contains($0) }) else { return nil }

        let content = cleanJournalContent(text)
        guard !content.isEmpty else { return nil }

        return .addJournal(
            content: content,
            mood: detectMood(text),
            tags: detectTags(text)
        )
    }

    private func cleanJournalContent(_ text: String) -> String {
        var cleaned = text
        let prefixes = [
            "帮我记录今天的状态", "帮我记录状态", "记录状态", "今日状态", "状态：", "状态:",
            "帮我复盘一下", "今日复盘", "复盘：", "复盘:",
            "帮我记录一篇日记", "帮我记录日记", "帮我记录一下", "记录一篇日记", "记录日记",
            "写一篇日记", "写一下日记", "记录今天", "今天日记", "日记：", "日记:", "日志：", "日志:"
        ]
        for prefix in prefixes {
            cleaned = cleaned.replacingOccurrences(of: prefix, with: "")
        }
        // Stripping the label leaves its separator behind: "状态：有点累" → "：有点累".
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "：:，,。.；;"))
    }

    private func detectMood(_ text: String) -> Mood? {
        if ["开心", "高兴", "快乐", "满意", "顺利", "兴奋"].contains(where: { text.contains($0) }) { return .happy }
        if ["平静", "安静", "稳定", "还好", "放松"].contains(where: { text.contains($0) }) { return .calm }
        if ["难过", "伤心", "低落", "沮丧", "失落"].contains(where: { text.contains($0) }) { return .sad }
        if ["生气", "愤怒", "烦躁", "不爽", "崩溃"].contains(where: { text.contains($0) }) { return .angry }
        if ["累", "疲惫", "困", "乏", "熬夜"].contains(where: { text.contains($0) }) { return .tired }
        return nil
    }

    private func detectTags(_ text: String) -> [ActivityTag] {
        var tags: [ActivityTag] = []
        if ["压力", "焦虑", "紧张", "烦", "崩溃", "压抑"].contains(where: { text.contains($0) }) { tags.append(.stress) }
        if ["睡眠", "睡觉", "早睡", "晚睡", "熬夜", "失眠", "午睡"].contains(where: { text.contains($0) }) { tags.append(.sleep) }
        if ["运动", "跑步", "健身", "训练", "散步"].contains(where: { text.contains($0) }) { tags.append(.exercise) }
        if ["工作", "开会", "项目", "加班", "客户"].contains(where: { text.contains($0) }) { tags.append(.work) }
        if ["加班", "赶工", "通宵", "ddl", "DDL"].contains(where: { text.contains($0) }) { tags.append(.overtime) }
        if ["外食", "外卖", "餐厅", "饭店", "聚餐", "下馆子"].contains(where: { text.contains($0) }) { tags.append(.diningOut) }
        if ["朋友", "聚会", "聊天", "家人", "约会"].contains(where: { text.contains($0) }) { tags.append(.social) }
        if ["旅行", "出差", "坐车", "飞机", "酒店"].contains(where: { text.contains($0) }) { tags.append(.travel) }
        if ["学习", "读书", "课程", "复习", "考试"].contains(where: { text.contains($0) }) { tags.append(.study) }
        if ["休息", "睡觉", "放松", "躺", "冥想"].contains(where: { text.contains($0) }) { tags.append(.rest) }
        if ["生病", "感冒", "发烧", "头疼", "胃疼", "不舒服"].contains(where: { text.contains($0) }) { tags.append(.sick) }
        if ["经期", "姨妈", "月经", "痛经"].contains(where: { text.contains($0) }) { tags.append(.period) }
        return tags.isEmpty ? [.other] : tags
    }

    private func parseMeal(_ text: String) -> AIChatIntentResult? {
        let eatKeywords = ["吃了", "吃的", "吃过", "喝了", "喝的", "喝过", "喝了一碗", "喝了一杯", "吃", "喝", "早餐", "午餐", "午饭", "晚餐", "晚饭", "早饭", "夜宵", "宵夜", "零食", "饮料", "奶茶", "咖啡", "果茶", "奶白", "拿铁"]
        guard eatKeywords.contains(where: { text.contains($0) }) else { return nil }

        let mealType = detectMealType(text)
        let foodNames = extractFoodNames(text)
        guard !foodNames.isEmpty else { return nil }

        let items = foodNames.map { name -> AIParsedFoodItem in
            if let uf = matchUserFood(name) {
                return userFoodToItem(uf)
            }
            return AIParsedFoodItem(name: name, amount: 100, unit: "g", calories: 0)
        }
        return .addMeal(AIParsedMeal(mealType: mealType, items: items, note: ""))
    }

    private func matchUserFood(_ name: String) -> UserFood? {
        userFoods.first { uf in
            uf.name == name || uf.name.contains(name) || name.contains(uf.name)
        }
    }

    private func userFoodToItem(_ uf: UserFood) -> AIParsedFoodItem {
        let profile = uf.servingProfile()
        var item = AIParsedFoodItem(
            name: uf.name,
            amount: profile.amount,
            unit: profile.unit,
            calories: profile.calories,
            nutritionDataBasis: .direct,
            nutritionDataNote: "数据来源：我的食物",
            confidence: "high"
        )
        for (key, value) in profile.nutrients {
            if let path = key.parsedItemKeyPath {
                item[keyPath: path] = value
            }
        }
        return item
    }

    private func detectMealType(_ text: String) -> MealType {
        if text.contains("早餐") || text.contains("早饭") || text.contains("早上") { return .breakfast }
        if text.contains("午餐") || text.contains("午饭") || text.contains("中午") { return .lunch }
        if text.contains("晚餐") || text.contains("晚饭") || text.contains("晚上") { return .dinner }
        if text.contains("夜宵") || text.contains("宵夜") { return .supper }

        let fruitKeywords = ["水果", "苹果", "香蕉", "橙子", "橘子", "葡萄", "西瓜", "草莓", "蓝莓",
                             "芒果", "桃子", "梨", "樱桃", "猕猴桃", "哈密瓜", "荔枝", "龙眼", "柚子",
                             "菠萝", "木瓜", "石榴", "火龙果", "榴莲", "牛油果", "桃", "杏", "李子",
                             "山竹", "百香果", "椰子", "柿子", "枣"]
        if fruitKeywords.contains(where: { text.contains($0) }) { return .fruit }

        let snackKeywords = ["零食", "薯片", "饼干", "蛋糕", "面包", "奶茶", "咖啡", "果汁", "酸奶",
                             "坚果", "巧克力", "糖果", "冰淇淋", "甜点", "布丁", "可乐", "奶酪",
                             "麻花", "辣条", "瓜子", "爆米花", "饮料", "奶昔", "蛋挞", "泡芙"]
        if snackKeywords.contains(where: { text.contains($0) }) { return .snack }

        let supperKeywords = ["烧烤", "撸串", "啤酒", "炸鸡", "小龙虾", "烤串", "麻辣烫", "串串",
                              "卤味", "炸串", "烤肉"]
        let hour = Calendar.current.component(.hour, from: .now)
        if supperKeywords.contains(where: { text.contains($0) }) && hour >= 21 { return .supper }

        return .guessByTime()
    }

    private func extractFoodNames(_ text: String) -> [String] {
        var cleaned = text
        let removeWords = ["吃了", "吃的", "吃过", "吃", "早餐", "午餐", "午饭", "晚餐", "晚饭", "早饭",
                           "夜宵", "宵夜", "加餐", "零食", "今天", "昨天", "前天", "中午", "早上", "晚上", "下午",
                           "喝了", "喝的", "喝过", "喝", "饮料", "记录", "帮我",
                           "正常糖", "全糖", "标准糖", "标准甜", "正常甜", "七分糖", "7分糖", "少糖",
                           "五分糖", "5分糖", "半糖", "三分糖", "3分糖", "无糖", "零糖", "0糖",
                           "不加糖", "不另外加糖", "无额外糖", "无额外糖浆",
                           "超大杯", "大杯", "中杯", "小杯", "标准杯",
                           "了", "的", "一份", "一碗", "一盘", "一块", "一杯", "一个", "一只", "一根"]
        for word in removeWords {
            cleaned = cleaned.replacingOccurrences(of: word, with: "")
        }

        let separators = CharacterSet(charactersIn: "和、，,跟+与 ")
        let parts = cleaned.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count >= 1 }

        return parts
    }
}
