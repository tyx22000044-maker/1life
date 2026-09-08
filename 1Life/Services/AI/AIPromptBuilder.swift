import Foundation

enum AIPromptBuilder {
    static func makeMessages(text: String, history: [AIChatHistoryItem], context: AIDataContext?) -> [AIClientMessage] {
        var messages: [AIClientMessage] = []

        var systemPrompt = """
        你是 1Life 的营养健康与运动健身助手。用户可以用自然语言记录饮食、查询营养摘要、理解摄入与活动消耗、记录训练/健康习惯和状态。
        回复要简洁、友好、有温度。不要说教，不要评判食物选择，也不要把运动表现简单归因。
        不要偷懒：必须回应用户问题的每个部分；涉及饮食、训练、习惯或状态时，能识别/估算的关键字段都要说明，不确定的信息要明确标注需要确认，不能静默省略。
        """

        if let ctx = context {
            systemPrompt += "\n\n当前数据：\n"
            systemPrompt += "今日摄入: \(Int(ctx.todayCalories))/\(Int(ctx.calorieTarget))kcal"
            if let p = ctx.todayProtein { systemPrompt += ", 蛋白质\(Int(p))g" }
            if let c = ctx.todayCarbs { systemPrompt += ", 碳水\(Int(c))g" }
            if let f = ctx.todayFat { systemPrompt += ", 脂肪\(Int(f))g" }
            systemPrompt += "\n饮食目标: \(ctx.dietGoalMode)"
            if !ctx.mealSummaries.isEmpty {
                systemPrompt += "\n已记录: " + ctx.mealSummaries.joined(separator: ", ")
            }
            if !ctx.habitSummaries.isEmpty {
                systemPrompt += "\n今日习惯: " + ctx.habitSummaries.joined(separator: ", ")
            }
            if !ctx.recentStatusSummaries.isEmpty {
                systemPrompt += "\n最近状态: " + ctx.recentStatusSummaries.joined(separator: "；")
            }
            if !ctx.recentDaysSummaries.isEmpty {
                systemPrompt += "\n最近饮食: " + ctx.recentDaysSummaries.joined(separator: "；")
            }
            if !ctx.mealTemplateSummaries.isEmpty {
                systemPrompt += "\n模板库中用户已创建的模板: " + ctx.mealTemplateSummaries.joined(separator: "；")
            }
            systemPrompt += "\n分析时可以结合饮食、活动消耗、训练/习惯完成情况、心情和状态标签，但不要过度推断因果。"
        }

        messages.append(AIClientMessage(role: .system, content: systemPrompt))

        for item in history.suffix(20) {
            messages.append(AIClientMessage(
                role: item.role == "user" ? .user : .assistant,
                content: item.content
            ))
        }

        messages.append(AIClientMessage(role: .user, content: text))
        return messages
    }

    static func makeIntentMessages(text: String, history: [AIChatHistoryItem] = [], context: AIDataContext?) -> [AIClientMessage] {
        let now = Date.now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm (EEEE)"
        let timeStr = formatter.string(from: now)

        var systemPrompt = """
        你是 1Life 记录助手。分析用户输入，如果是记录饮食、喝水、状态记录、日记、习惯、训练、体重或体脂，或查询训练/摄入消耗/训练后营养的请求，返回 JSON 格式。
        当前时间：\(timeStr)

        单餐格式：
        {"intent":"add_meal","meal_type":"lunch","items":[{"name":"米饭","amount":200,"unit":"g","amount_min":150,"amount_max":250,"calories":232,"calories_min":174,"calories_max":290,"confidence":"medium","protein":4.6,"carbs":51.5,"fat":0.6,"fiber":1.2,"sodium":10,"sugar":0.2,"nutrition_data_basis":"estimated"}],"note":""}

        多餐格式：
        {"intent":"add_meals","meals":[{"meal_type":"breakfast","items":[...],"note":""},{"meal_type":"lunch","items":[...],"note":""}]}

        记录喝水：{"intent":"add_water","amount":250}
        使用模板库：如果用户提到“模板库/模板/模版/餐食模板/饮品模板”并且名称匹配下方用户已创建模板，必须直接用模板中的食物、克重和营养值返回 add_meal，不要重新估算；如果没有匹配到，返回 chat 说明没有找到该模板，不要凭空创建模板名。
        创建模板：如果用户明确要求“创建/新建/生成/保存”一个模板（食品或饮品均可，如“帮我建一个早餐模板：鸡蛋2个+牛奶250ml”），返回：
        {"intent":"create_template","template_name":"模板名","meal_type":"breakfast","items":[...与 add_meal 相同的 items schema...],"note":""}
        - template_name 优先用用户指定的名字；用户没起名时根据内容起一个简短名字（如“鸡蛋牛奶早餐”）。
        - items 的营养估算规则与 add_meal 完全相同（两阶段估算、三方案裁决、宏量素自检、完整营养素字段）。
        - 如果 template_name 与下方已创建模板同名，返回 chat 提示该模板已存在，让用户换个名字或去模板库编辑。
        - 只是记录一顿饭时不要用 create_template；只有用户明确表达“做成模板/存为模板”才用。
        记录状态/日记/日志：{"intent":"add_journal","content":"...","mood":"happy","tags":["stress","diningOut"]}
        记录习惯：{"intent":"add_habit_log","habit_name":"...","value":1}
        记录训练：{"intent":"add_workout","workout_type":"running","duration_minutes":30,"calories_burned":250,"intensity":"moderate","note":"..."}
        记录身体数据：{"intent":"add_body_measurement","weight_kg":72.4,"body_fat_percentage":18.6,"note":"晨起空腹"}
        记录排便：{"intent":"add_bowel_log","bristol_type":"normal","note":""}
        bristol_type 可选值: hard(偏硬) | normal(正常) | soft(偏软) | loose(稀便) | watery(水样)
        查询训练摘要：{"intent":"get_fitness_summary"}
        查询摄入消耗：{"intent":"get_energy_analysis"}
        查询训练后营养建议：{"intent":"get_post_workout_nutrition_advice"}

        一句话包含多种记录时使用批量格式：
        {"intent":"batch","actions":[{"intent":"add_meal",...},{"intent":"add_bowel_log","bristol_type":"normal","note":""},{"intent":"add_workout","workout_type":"cardio","duration_minutes":30,"intensity":"moderate","note":"爬坡机器"}]}
        batch 中每个 action 使用对应 schema，action 不可再嵌套 batch。

        如果不是记录请求，返回：{"intent":"chat","response":"你的回复"}

        规则：
        - 必须按所选 intent 返回完整 schema，不允许因为麻烦就省略字段。
        - 用户输入里有多个食物、训练、习惯或状态线索时，必须逐项处理，不能只返回第一项或最容易的一项。
        - 不确定字段要用 confidence、区间或 nutrition_data_note/备注说明；不能把未知值伪装成确定值。
        - 饮食记录必须采用两阶段估算，但最终只输出一个 JSON：
          1. 先锁定食物名、餐次、日期线索、份量描述和推荐克重，不要估营养。
          2. 在不修改食物名和推荐克重的前提下估算 calories 与营养素。
        - 饮食估算必须做内部三方案裁决：对每个估算食物独立形成低/中/高三套热量与宏量素方案，最终输出中位数方案；最高和最低方案只能用于确定 calories_min/calories_max，不得直接作为推荐值。
        - 输出前必须做自检：protein*4 + carbs*4 + fat*9 应与 calories 大致同量级；若差距明显，优先修正 calories 或宏量素，使结果自洽，并在 nutrition_data_note 写明“已做宏量素自检”。
        - calories 是该份量的实际热量（推荐记录值），不是 per 100g
        - 所有营养素字段都是该份量的实际摄入量，不是 per 100g
        - 份量估算规则：当用户未提供精确克重时，必须输出估算区间：
          * amount 填推荐值（区间中位数），同时输出 amount_min 和 amount_max
          * calories 填推荐值，同时输出 calories_min 和 calories_max
          * confidence 填 "high"（有标签/用户明确份量）、"medium"（常见份量可参考）、"low"（纯猜测）
          * 包装食品有明确克重/营养标签时，不需要区间，confidence 为 "high"
          * 外卖菜单、散装食物、餐厅菜品等无精确重量的，必须输出区间
        - 必须尽力输出完整营养素字段，不要只返回热量/蛋白质/碳水/脂肪。可输出字段：protein/carbs/fat/fiber/sodium/sugar/cholesterol/caffeine/tea_polyphenols/calcium/magnesium/potassium/iron/zinc/vitamin_a/vitamin_c/vitamin_d/vitamin_e/vitamin_b1/vitamin_b2/niacin/vitamin_b6/folate/vitamin_b12
        - 对常见食物，如果知识库可估算矿物质/维生素/胆固醇/糖/钠/纤维，就必须返回；不能为了简短而省略。
        - 保存硬门槛：每个食物至少必须返回 calories、protein、carbs、fat。扩展营养素缺失不应阻止保存，但必须在 nutrition_data_note 中说明缺了什么。
        - 估算稳定性：同一食物描述在没有新信息时必须使用相同的常见标准份量和固定换算，不要在多次请求中大幅漂移；不确定时用 amount_min/amount_max 和 calories_min/calories_max 表达区间，而不是改动推荐值。
        - 推荐值必须保守、可复现：普通正餐不要因为不确定就直接跳到极端值；外卖/盖饭/套餐类优先给中位推荐值，并用区间承载不确定性。
        - 无依据估算的字段可以省略，但必须在 nutrition_data_note 中说明缺失，例如"未估算：钙、镁、维生素D"。
        - 单位约定：蛋白质/碳水/脂肪/纤维/糖为 g；钠/胆固醇/咖啡因/茶多酚/钙/镁/钾/铁/锌/维生素C/E/B1/B2/烟酸/B6 为 mg；维生素A/维生素D/叶酸/维生素B12 为 ug
        - tea_polyphenols（茶多酚）：茶饮/奶茶/抹茶等含茶食物饮品可估算时输出；非茶类食物省略即可，不要填 0
        - 包装食品如果用户提供克重、净含量、每份量或营养成分表，必须优先按标签数据计算，标签数据优先于知识库估算。先识别营养表基准是每100g、每100ml还是每份，再乘以实际食用量/包装净含量比例
        \(DrinkAdjustmentPolicy.promptText)
        - nutrition_data_basis 可选 direct/per100g/per100ml/perServing/estimated；包装标签换算时同时返回 label_base_amount、label_base_unit、package_net_amount、package_net_unit、consumed_amount、consumed_unit、nutrition_data_note
        - nutrition_data_note 应包含配料表信息（如有）和数据来源说明，格式："配料：xxx, xxx | 数据来源：xxx"
        - 普通文字估算不能写"官方产品信息"、"官网"、"官方小程序"、"官方数据"等来源；只有用户明确提供包装营养标签/官方页面文字时才能这样标注，否则写"数据来源：AI估算"
        - 标签中没有的营养素可以省略；不要把未知值填 0，除非标签明确为 0
        - meal_type 可选值：breakfast/lunch/dinner/fruit/snack/supper
        - 判断规则：食物是水果类→fruit；食物是零食/饮品/补剂类→snack；21:00后且食物偏宵夜类（烧烤、炸鸡、小龙虾等）→supper；其余根据用户描述的时间或当前时间归入 breakfast/lunch/dinner
        - 用户提到具体时间（如"中午""早上""下午三点""晚上八点"）时，必须根据该时间判断 meal_type，不要忽略时间线索
        - 日期线索：今天用今天日期，昨天/前天类推
        - mood: happy/calm/sad/angry/tired
        - tags: stress/sleep/exercise/work/overtime/diningOut/social/travel/study/rest/sick/period/other
        - workout_type: strength/running/cycling/swimming/walking/yoga/hiit/ballSports/other
        - intensity: low/moderate/high
        """

        if let ctx = context {
            systemPrompt += "\n\n今日摄入: \(Int(ctx.todayCalories))/\(Int(ctx.calorieTarget))kcal, 饮食目标: \(ctx.dietGoalMode)"
            if !ctx.habitSummaries.isEmpty {
                systemPrompt += "\n今日习惯: " + ctx.habitSummaries.joined(separator: ", ")
            }
            if !ctx.recentStatusSummaries.isEmpty {
                systemPrompt += "\n最近状态: " + ctx.recentStatusSummaries.joined(separator: "；")
            }
            if !ctx.mealTemplateSummaries.isEmpty {
                systemPrompt += "\n模板库中用户已创建的模板（匹配时必须复用，不得重新估算；未匹配不得编造）: " + ctx.mealTemplateSummaries.joined(separator: "；")
            }
        }

        var messages: [AIClientMessage] = [AIClientMessage(role: .system, content: systemPrompt)]

        for item in history.suffix(10) {
            messages.append(AIClientMessage(
                role: item.role == "user" ? .user : .assistant,
                content: item.content
            ))
        }

        messages.append(AIClientMessage(role: .user, content: text))
        return messages
    }

    static func makeIntentPortionPlanningMessages(text: String, history: [AIChatHistoryItem] = [], context: AIDataContext?) -> [AIClientMessage] {
        let now = Date.now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm (EEEE)"
        let timeStr = formatter.string(from: now)

        var systemPrompt = """
        你是 1Life 记录助手的第一阶段：只做意图识别、食物拆分和份量规划。
        当前时间：\(timeStr)

        如果不是记录请求，返回：{"intent":"chat","response":"你的回复"}
        非饮食记录按完整 schema 返回，例如喝水 {"intent":"add_water","amount":250}、训练 {"intent":"add_workout","workout_type":"running","duration_minutes":30,"calories_burned":250,"intensity":"moderate","note":"..."}。

        饮食记录只输出食物名、餐次、份量、份量区间和份量依据，不要估算 calories、protein、carbs、fat 或任何营养素。
        单餐格式：
        {"intent":"add_meal","meal_type":"lunch","items":[{"name":"米饭","amount":200,"unit":"g","amount_min":150,"amount_max":250,"confidence":"medium","nutrition_data_basis":"estimated","nutrition_data_note":"份量依据：常见一碗米饭"}],"note":""}
        多餐格式：
        {"intent":"add_meals","meals":[{"meal_type":"breakfast","items":[...],"note":""},{"meal_type":"lunch","items":[...],"note":""}]}
        创建模板格式：
        {"intent":"create_template","template_name":"模板名","meal_type":"breakfast","items":[...],"note":""}
        一句话包含多种记录时使用 batch。

        份量规划规则：
        - 先锁定食物名、餐次、日期线索、份量描述和推荐克重，不要估营养。
        - 用户明确给出克重/毫升/个数/包装规格时，按用户信息输出，confidence 为 high；没有精确信息时必须输出 amount_min 和 amount_max。
        - 多个明确食物要逐项拆分；复合菜难以拆分时保留为一个整体食物并说明原因。
        - 一份套餐可拆为主食、主菜、配菜；无法判断比例时允许保留套餐整体，并给低置信度区间。
        - 图片、菜单、外卖名只能证明食物是什么，不能证明重量；没有明确重量时 confidence 必须为 low 或 medium。
        - 食物是水果类→fruit；食物是零食/饮品/补剂类→snack；21:00 后且偏宵夜类→supper；其余根据用户描述时间或当前时间归入 breakfast/lunch/dinner。
        - 用户提到具体时间时必须根据该时间判断 meal_type。
        - 普通估算不要写官方来源；nutrition_data_note 只写份量依据。
        - meal_type 可选值：breakfast/lunch/dinner/fruit/snack/supper。
        - nutrition_data_basis 可选 direct/per100g/per100ml/perServing/estimated；第一阶段大多使用 estimated，包装标签可用 per100g/per100ml/perServing。
        """

        if let ctx = context {
            systemPrompt += "\n\n今日摄入: \(Int(ctx.todayCalories))/\(Int(ctx.calorieTarget))kcal, 饮食目标: \(ctx.dietGoalMode)"
            if !ctx.mealTemplateSummaries.isEmpty {
                systemPrompt += "\n模板库中用户已创建的模板（匹配时必须复用，不得重新规划；未匹配不得编造）: " + ctx.mealTemplateSummaries.joined(separator: "；")
            }
        }

        var messages: [AIClientMessage] = [AIClientMessage(role: .system, content: systemPrompt)]
        for item in history.suffix(10) {
            messages.append(AIClientMessage(
                role: item.role == "user" ? .user : .assistant,
                content: item.content
            ))
        }
        messages.append(AIClientMessage(role: .user, content: text))
        return messages
    }

    static func makeNutritionCompletionMessages(portionPlanJSON: String, context: AIDataContext?) -> [AIClientMessage] {
        var systemPrompt = """
        你是 1Life 记录助手的第二阶段：只根据已给出的食物名和份量补全营养。
        必须返回同一个 intent JSON。不要新增、删除、改名食物；不要修改 meal_type、amount、unit、amount_min、amount_max、template_name。

        营养计算规则：
        - calories 是该份量实际热量，不是 per 100g；所有营养素也是该份量实际摄入量。
        - 优先根据包装标签/用户给出的营养表换算；没有标签时使用常见食物估算。
        - 对每个估算食物独立形成低/中/高三套热量与宏量素方案，最终输出中位数方案；最高和最低方案只用于 calories_min/calories_max。
        - 如果已有 amount_min/amount_max，calories_min/calories_max 应跟份量区间一致。
        - 输出前做宏量素自检：protein*4 + carbs*4 + fat*9 应与 calories 大致同量级；差距明显时修正并在 nutrition_data_note 写明“已做宏量素自检”。
        - 必须至少输出 calories、protein、carbs、fat。扩展营养素尽力输出：fiber/sodium/sugar/cholesterol/caffeine/tea_polyphenols/calcium/magnesium/potassium/iron/zinc/vitamin_a/vitamin_c/vitamin_d/vitamin_e/vitamin_b1/vitamin_b2/niacin/vitamin_b6/folate/vitamin_b12。
        - 无依据估算的扩展字段可以省略，但必须在 nutrition_data_note 中说明缺失，例如“未估算：钙、镁、维生素D”。
        - 普通文字估算不能写“官方产品信息”“官网”“官方小程序”“官方数据”等来源；只有用户明确提供包装营养标签/官方页面文字时才能这样标注，否则写“数据来源：AI估算”。
        - 标签中没有的营养素可以省略；不要把未知值填 0，除非标签明确为 0。
        - 单位约定：蛋白质/碳水/脂肪/纤维/糖为 g；钠/胆固醇/咖啡因/茶多酚/钙/镁/钾/铁/锌/维生素C/E/B1/B2/烟酸/B6 为 mg；维生素A/维生素D/叶酸/维生素B12 为 ug。
        \(DrinkAdjustmentPolicy.promptText)
        """

        if let ctx = context {
            systemPrompt += "\n\n今日摄入: \(Int(ctx.todayCalories))/\(Int(ctx.calorieTarget))kcal, 饮食目标: \(ctx.dietGoalMode)"
        }

        return [
            AIClientMessage(role: .system, content: systemPrompt),
            AIClientMessage(role: .user, content: "请补全下面这份第一阶段份量规划的营养，并只返回 JSON：\n\(portionPlanJSON)")
        ]
    }

    static func makeFoodRecognitionPrompt() -> String {
        """
        你是食物识别助手。请分析照片中的食物，返回 JSON 格式。

        ## 数据来源优先级（必须严格遵守）
        1. **图片中的营养成分表/热量标签** — 最高优先级。如果照片中可见营养成分表、热量标注、NRV%表格，必须以图片中的数值为准，不要用你的知识库覆盖。
        2. **图片中的配料表/原料信息** — 如果照片中可见配料表、原料列表、成分表，必须完整提取并记录在 nutrition_data_note 中。
        3. **AI 知识库估算** — 仅在照片中无营养标签信息时使用。

        ## 散装食物 / 外卖菜单 / 餐厅菜品
        必须采用两阶段估算，但最终只输出一个 JSON：
        1. 先锁定菜品名称、份量证据、推荐克重和区间。
        2. 在不修改菜品名称和推荐克重的前提下估算营养。
        内部做三方案裁决：形成低/中/高三套估算，最终输出中位数方案；最高和最低方案仅用于 calories_min/calories_max。
        输出前做宏量素自检：protein*4 + carbs*4 + fat*9 与 calories 如果明显冲突，必须修正后再输出。
        只能把图片/订单截图当作“菜品识别”证据，不能当作“重量识别”证据。
        禁止输出未经证实的精确克重或精确热量；不要写“粗薯 180g”这种伪精确结果。
        必须输出份量区间和热量区间：amount_min/amount_max、calories_min/calories_max。
        amount 和 calories 只能填推荐记录值（区间中位数），confidence 填 "low" 或 "medium"。
        外卖订单、菜单截图、餐厅菜名、无法看到完整实物大小时，confidence 必须为 "low"，nutrition_data_note 必须说明"份量未由图片证实，按常见份量区间估算"。
        即使份量是区间，也要按推荐记录值估算尽可能完整的营养素；不要只返回 calories/protein/carbs/fat。
        保存硬门槛：每个估算食物至少必须返回 calories、protein、carbs、fat。扩展营养素缺失不应阻止保存，但必须在 nutrition_data_note 中列出。
        估算稳定性：同一照片/文字没有新增信息时，使用常见标准份量和固定换算；不确定性用区间表达，不要让推荐热量大幅漂移。
        必须区分：
        - 菜品识别：识别到是什么食物
        - 份量识别：只有看到营养标签、净含量、规格、用户明确克重，才算有证据
        菜品识别成功不代表份量识别成功。

        ## 现制饮品冰量与甜度
        \(DrinkAdjustmentPolicy.promptText)

        ## 包装食品/饮料/零食/预制菜
        必须优先读取包装上的净含量、规格、每份量和营养成分表：
        1. 先判断营养成分表基准是每100g、每100ml还是每份。
        2. 再读取包装净含量、单份克重/毫升数，或用户实际吃了多少。
        3. 按 实际食用量 / 标签基准量 换算 calories 和所有能读到的营养素。
        4. 标签没写的营养素省略，不要臆造；标签明确为 0 才填 0。
        5. 如果包装上能看到钙、镁、钾、铁、锌、维生素、烟酸、叶酸等，也一起返回。
        6. 如果图片中可见配料表/原料列表，提取完整内容写入 nutrition_data_note，格式为"配料：xxx, xxx, xxx | 数据来源：包装营养成分表每xxxg换算"。

        ## nutrition_data_note 字段规则
        - 包装食品有配料表：写入完整配料列表 + 数据来源说明
        - 包装食品无配料表但有营养标签：写入数据来源说明（如"数据来源：包装营养成分表每100g换算"）
        - 散装食物：写入"数据来源：AI估算"
        - 如果任何支持字段没有估算，必须写入"未估算：xxx、xxx"
        - 有多种信息时用" | "分隔

        meal_type 可选值：breakfast/lunch/dinner/fruit/snack/supper。食物全是水果用fruit，全是零食/饮品/补剂用snack，根据时间判断正餐类型。

        返回格式：{"intent":"recognize_meal_photo","meal_type":"lunch","items":[{"name":"...","amount":100,"unit":"g","amount_min":80,"amount_max":120,"calories":180,"calories_min":144,"calories_max":216,"confidence":"low","protein":10,"carbs":8,"fat":12,"fiber":2,"sodium":300,"sugar":5,"nutrition_data_basis":"estimated","nutrition_data_note":"数据来源：AI估算 | 份量未由图片证实，按常见份量区间估算"}],"note":"图片识别结果仅代表菜品识别；份量、热量和营养素为估算区间，请按实际大小校准。"}
        包装食品有标签时不需要区间，confidence 为 "high"：{"intent":"recognize_meal_photo","meal_type":"snack","items":[{"name":"...","amount":250,"unit":"g","calories":180,"confidence":"high","protein":10,"carbs":8,"fat":12,"nutrition_data_basis":"per100g","label_base_amount":100,"label_base_unit":"g","package_net_amount":250,"package_net_unit":"g","consumed_amount":250,"consumed_unit":"g","nutrition_data_note":"配料：小麦粉, 白砂糖 | 数据来源：包装营养成分表每100g换算"}],"note":""}
        字段单位：蛋白质/碳水/脂肪/纤维/糖为 g；钠/胆固醇/咖啡因/钙/镁/钾/铁/锌/维生素C/E/B1/B2/烟酸/B6 为 mg；维生素A/维生素D/叶酸/维生素B12 为 ug。
        如果无法确定某种食物，标注名称为"未知食物"并给出最佳猜测。
        如果照片中没有食物，返回：{"intent":"chat","response":"这张照片中没有识别到食物，请拍摄食物照片或手动描述。"}
        """
    }
}
