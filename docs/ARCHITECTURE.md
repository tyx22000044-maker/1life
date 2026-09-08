# 1Life 架构说明

更新日期：2026-06-26

## 总览

1Life 是 SwiftUI + SwiftData 构建的个人营养健康与运动健身 App。核心能力是饮食营养记录、营养目标管理、TDEE/活动消耗估算和 AI 营养分析；日志和习惯追踪用于辅助记录状态、训练行为和长期复盘。架构对齐 1Cash：本地优先，SwiftData 持久化，服务层负责营养计算、HealthKit 读取、食物识别、图片处理、AI 配置和导出，SwiftUI View 负责界面状态和交互。

## 项目基础

- **App 入口结构体**：`OneLifeApp`（文件名 `OneLifeApp.swift`）。Xcode 模板生成的 `_LifeApp` 需要重命名，对齐家族命名（1Cash 用 `OneCashApp`）。
- **最低部署目标**：iOS 17.0（SwiftData 和 `@Observable` 宏要求）。
- **Schema 版本**：`AppSettings` 中定义 `static let currentDataSchemaVersion = 4`，用于本地数据版本标记和未来迁移。
- **JSON 备份版本**：`ExportService.supportedBackupVersion = 5`。导入时只接受当前支持版本，避免旧结构静默写入不完整数据。
- **Info.plist 权限描述键**：
  - `NSCameraUsageDescription`：拍照识别食物
  - `NSMicrophoneUsageDescription`：语音输入
  - `NSSpeechRecognitionUsageDescription`：语音识别
  - `NSPhotoLibraryUsageDescription`：保存照片
  - `NSHealthShareUsageDescription`：读取 Apple Health 活动热量、静息热量、步数、训练记录、体重和身高，用于动态估算 TDEE、训练摘要和营养目标

与 1Cash 的核心差异：
- 数据模型有一对多关系（Meal → FoodItem），1Cash 的 Transaction 是扁平的
- AI 层支持多模态（图片 + 文字），1Cash 只有文字
- 新增图片处理管线（压缩、缩略图、存储）
- 新增用户自建食物、模板库和饮品知识库
- 新增 Apple Health 读取层，用于用户授权后的动态 TDEE、活动消耗展示和营养/训练目标推荐

## CloudKit 兼容性约定

所有 `@Model` 的 `id: UUID` 作为普通属性，**不使用 `@Attribute(.unique)`**。1Cash V1.1 已验证 `@Attribute(.unique)` 与 CloudKit 不兼容。SwiftData 内部使用 `PersistentIdentifier` 做唯一标识，不需要额外的 unique 约束。

## App 启动与初始化流程

`ContentView.onAppear` 中按顺序执行（对齐 1Cash 的 `SeedData.installDefaultsIfNeeded` 模式）：

```swift
.onAppear {
    SeedData.installDefaultsIfNeeded(settings: settings, context: modelContext)
    SeedData.installDefaultNutritionGoalIfNeeded(goals: nutritionGoals, context: modelContext)
    NotificationManager.shared.rescheduleRemindersIfNeeded(settings: settings.first)
}
```

1. **`SeedData.installDefaultsIfNeeded`**：检查 `settings.isEmpty`，为空则插入默认 AppSettings（`hasCompletedOnboarding: false`）。保证单例始终存在，清空数据后重新打开也不会崩。
2. **`SeedData.installDefaultNutritionGoalIfNeeded`**：检查 NutritionGoal 是否存在，为空则插入默认目标（2000 kcal 均衡模式）。
3. **`NotificationManager.rescheduleRemindersIfNeeded`**：根据 AppSettings 的提醒设置重新调度三餐和习惯的本地通知。

`SeedData` 使用 `@MainActor enum`（对齐 1Cash 模式），所有方法为 static。

## 全局日期状态

App 级别持有 `@Observable` 的 `AppViewModel`，包含：

```swift
@Observable
final class AppViewModel {
    var selectedTab: AppTab = .dashboard
    var selectedDate: Date = .now      // 首页和饮食页共享
}
```

首页和饮食页绑定同一个 `selectedDate`。用户在首页切换日期后，切到饮食 Tab 看到同一天的数据。"我的"和"设置"Tab 不受日期影响。AppViewModel 通过 `.environment(appViewModel)` 注入 View 树。

## SwiftData 模型

所有 `@Model` 类均包含 `var id: UUID`（init 中赋值 `UUID()`）和 `var createdAt: Date`（赋值 `.now`）。需要更新时间的模型额外包含 `var updatedAt: Date`。

- `AppSettings`：`id: UUID`，`static let currentDataSchemaVersion = 4`，`dataSchemaVersion: Int`，饮食目标模式（`dietGoalModeRaw: String`），语言，外观，头像昵称，头像照片数据，AI 配置状态，通知设置，Onboarding 状态，用户身体参数（`genderRaw: String?`、`age: Int?`、`heightCm: Double?`、`weightKg: Double?`、`activityLevelRaw: String?` — 全部 Optional，用户可跳过），Apple Health 状态（`isHealthKitEnabled`、`useHealthKitForDynamicTDEE`），饮水设置（`dailyWaterGoalMl: Double = 2000`、`defaultCupMl: Double = 250`、`defaultBottleMl: Double = 500`），训练目标设置（每周次数、每周分钟、目标提醒、恢复提醒），`createdAt`，`updatedAt`。单例，App 生命周期内只有一条记录。
- `NutritionGoal`：每日热量、蛋白质、碳水、脂肪、纤维、钠、糖、胆固醇目标值，`effectiveDate` 生效日期。独立模型，支持按日期设定不同阶段的目标（如用户从减脂切换到增肌时，旧目标保留历史记录，新目标从指定日期生效）。查询时取 `effectiveDate <= 当天` 的最新一条。
- `Meal`：`id: UUID`，`date: Date`（精确到分钟，如 14:30。按天分组时使用 `Calendar.startOfDay`。保留分钟精度用于同餐次多个 Meal 的排序和卡片时间展示），餐次（`mealTypeRaw: String`，breakfast/lunch/dinner/snack），`mealTypeSortOrder: Int`（早餐 0/午餐 1/晚餐 2/加餐 3，用于排序），照片原图数据（`@Attribute(.externalStorage) var photoData: Data?`），照片缩略图数据（`var photoThumbnail: Data?`），备注，来源（`sourceRaw: String`，manual/aiText/aiPhoto），`createdAt`。与 FoodItem 为一对多关系。同一餐次允许创建多个 Meal 实例（如上午加餐和下午加餐各一个）。
- `FoodItem`：`id: UUID`，食物名称、份量数值、单位（g/ml/份/个）、份量对应克数（`servingGrams`，用于营养素换算的标准化基准）、热量（`Double`，必填）、蛋白质/碳水/脂肪/纤维/钠/糖/胆固醇（全部 `Double?`，nil=未填写，0=确实为0）、来源（`sourceRaw: String`，manual/ai/preset — 独立于 Meal.source，因为同一餐里可能有 AI 识别的和用户手动补充的食物项）、`createdAt`。属于某个 Meal。
- `UserFood`：用户自定义或从历史记录中收藏的食物。名称、默认份量、单位、默认份量对应克数、每 100g 营养数据、使用次数、最近使用时间。用于"我的食物"和"最近使用"功能。
- `WaterLog`：饮水记录。日期时间、饮水量（ml）。独立轻量模型，不走 Meal + FoodItem 路径。
- `Habit`：习惯名称、图标 SF Symbol、颜色 Hex、频率类型（`frequencyTypeRaw: String`，daily/weekly）、频率次数（`frequencyCount: Int`，每周型使用，如每周 3 次的 3；每天型固定为 1）、目标数量、单位名称、提醒时间、归档状态。与 HabitLog 为一对多关系。
- `HabitLog`：完成日期、完成数量。属于某个 Habit。
- `JournalEntry`：`id: UUID`，日期，心情标签（`moodRaw: String`），活动标签数组（`tags: [String]`，V1.0 使用固定枚举：压力/睡眠/运动/工作/加班/外食/社交/旅行/学习/休息/生病/经期/其他，不支持自定义），正文内容，`createdAt`，`updatedAt`。与 JournalPhoto 为一对多关系（最多 9 张）。
- `JournalPhoto`：`id: UUID`，`@Attribute(.externalStorage) var photoData: Data`，`var thumbnailData: Data`，`sortOrder: Int`。属于某个 JournalEntry。
- `MealTemplate`：常用餐食模板。模板名称、餐次、食物条目快照（JSON 编码的 `[TemplateFoodItem]`）、使用次数、最近使用时间。用户可从已记录的 Meal 保存为模板，或直接创建。
- `AIChatMessage`（`nonisolated final class`，对齐 1Cash 多线程安全）：`id: UUID`，AI 对话消息，服务商，工具/结构化解析信息，关联餐食 ID（`createdMealID: UUID?`），关联数据是否已删除标记（`isLinkedDataDeleted: Bool`），`createdAt`。

## 模型关系

```
Meal ──1:N──→ FoodItem          (deleteRule: .cascade)
Habit ──1:N──→ HabitLog         (deleteRule: .cascade)
JournalEntry ──1:N──→ JournalPhoto  (deleteRule: .cascade)
```

三个一对多关系均使用 `.cascade` 删除规则。孤儿记录没有独立存在的意义。

其余模型之间无直接关系。

AIChatMessage 通过 `createdMealID: UUID?` 弱引用关联已创建的 Meal。当关联的 Meal 被删除时，删除逻辑必须同步设置 `isLinkedDataDeleted = true`，聊天历史中的卡片显示为「该记录已删除」灰色状态，撤销按钮隐藏。

## 营养素可空设计

FoodItem 的营养素字段使用 `Double?` 而非 `Double`：

```swift
var calories: Double      // 热量是必填，不可空
var protein: Double?      // nil = 用户未填写，0 = 确实为 0（如白糖）
var carbs: Double?
var fat: Double?
var fiber: Double?
var sodium: Double?
var sugar: Double?
var cholesterol: Double?
```

`calories` 是唯一的必填营养素（记录一餐至少要有热量）。其余全部可空。

汇总计算时：nil 值不计入汇总，但 0 值计入。如果某天所有 FoodItem 的 protein 都是 nil，首页蛋白质进度条显示「数据不完整」而非 0g。

## 时间与时区策略

- `Meal.date`、`HabitLog.date`、`JournalEntry.date`、`WaterLog.date` 存储的是 **UTC Date**（Swift 的 Date 本身就是 UTC）。
- 所有"今日"判断使用**用户设备当前时区**将 UTC Date 转换为本地日历日。
- 如果用户跨时区旅行（如从北京飞到纽约），已记录的 Meal 保持原始 UTC 时间不变。「今日」视图按新时区重新分组——北京早上 8 点吃的早餐（UTC 00:00）在纽约时区会显示为"昨天"。这符合用户直觉：打开手机看到的"今天"就是当地的今天。
- 不额外存储用户创建时的时区偏移。如果未来需要"旅行视图"（按出发地时区展示），再扩展。

## NutritionGoal 生效与冲突策略

- 查询当前生效目标：`effectiveDate <= today`，按 `effectiveDate` 降序取第一条。
- 用户修改身体参数后选择「重新推荐营养目标」时：
  - 如果今天已有一条 NutritionGoal（effectiveDate == today），直接**更新**该条记录的值。
  - 如果今天没有，**创建新条目**（effectiveDate = today），旧目标自然失效（不删除，保留历史）。
  - 不会出现同一天两条目标的冲突。
- 查看历史目标：设置页可展示所有 NutritionGoal 列表（按 effectiveDate 降序），用户可了解自己的目标变迁。

## MealTemplate 版本策略

`MealTemplate.foodItemsJSON` 存储的 `[TemplateFoodItem]` 使用防御性解码：

```swift
struct TemplateFoodItem: Codable {
    let name: String
    let amount: Double
    let unit: String
    let servingGrams: Double
    let calories: Double
    let protein: Double?   // 所有营养素用 decodeIfPresent
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sodium: Double?
    let sugar: Double?
    let cholesterol: Double?
}
```

所有非必须字段使用 `decodeIfPresent`（Codable 默认对 Optional 字段已如此）。未来新增营养素字段时，旧模板 JSON 中缺失的 key 自动解码为 nil，不会 throw error。不需要额外的 schema 版本号。

## 营养汇总性能策略

NutritionService 的每日汇总不使用全量重算：

- **当日数据**：每次查询只检索 `Meal.date` 在今日范围内的记录，SwiftData 的 `#Predicate` 按日期过滤。一天的 Meal 数量通常 ≤10，FoodItem ≤30，性能不是问题。
- **不缓存**：当日数据频繁变化（每次记录、编辑、删除都会改变汇总），缓存的失效逻辑比直接查询更复杂。直接查询的成本足够低（毫秒级），不值得引入缓存层。
- **历史数据**（报表/趋势图）：如果未来需要 30 天趋势图，每天一次汇总查询 × 30 天可能较慢。届时引入 `DailyNutritionSnapshot` 每日快照模型，在用户完成当天最后一次记录后异步生成。V1.0 不实现。

## Tab 结构与页面布局

```
Tab 1: 今日 (Dashboard)     — 热量进度环 + 营养素 + 三餐摘要 + 饮水 + 习惯 + 日志
Tab 2: 饮食 (Food Timeline) — 按餐次的餐食卡片列表 + 搜索 + 模板
Tab 3: AI (中央)            — 全屏聊天 + 拍照识别 + 语音输入
Tab 4: 我的 (My Life)       — 上下分区布局（不用 Segmented Control）：
                               上半部分: 习惯追踪紧凑网格（约 40%），可折叠
                               下半部分: 日志时间线（可滚动列表）
Tab 5: 设置 (Settings)      — 家族标准分组列表
```

Tab 枚举定义（对齐 1Cash 的 `AppTab`）：

```swift
enum AppTab: Int, CaseIterable, Hashable, Identifiable {
    case dashboard
    case food
    case ai
    case myLife
    case settings
    var id: Int { rawValue }
}
```

## AI 结构化意图完整列表

| 意图 | 功能 | 触发方式 |
|------|------|---------|
| `add_meal` | 记录单餐 | 文字描述 |
| `add_meals` | 一次记录多餐 | 文字描述涉及多个餐次 |
| `recognize_meal_photo` | 拍照识别单餐 | 照片发送 |
| `add_journal` | 记录日志 | 文字描述 |
| `add_habit_log` | 记录习惯完成 | 文字描述 |
| `add_water` | 记录饮水 | 文字描述 |
| `use_meal_template` | 从模板创建餐食 | 文字描述 |
| `get_today_nutrition` | 查询今日营养摘要 | 问答 |
| `get_nutrition_analysis` | 营养分析 | 问答 |
| `get_meal_history` | 查询饮食记录 | 问答 |
| `chat` | 非结构化回复 | 无法解析为意图时 |

## AI 错误处理

| 错误类型 | 用户提示 | 行为 |
|---------|---------|------|
| API Key 无效 | "API Key 无效，请在设置中重新配置" | 显示「去设置」按钮 |
| 网络超时（文字 30s / 拍照 45s） | "请求超时，请检查网络后重试" | 显示「重试」按钮 |
| AI 无法识别照片 | "无法识别这张照片中的食物，请拍摄更清晰的照片或手动描述" | 保留照片气泡 |
| AI 返回格式异常 | "AI 返回格式异常，请重新描述" | 记录 os.Logger 日志 |
| 服务商不支持 Vision | 相机按钮灰显 + "当前 AI 服务商不支持拍照识别" | 引导切换服务商 |
| AI 未配置 | "未配置 AI" + 「去设置」按钮 | 本地解析仍可用 |

## 通知与深链接

三餐提醒和习惯提醒使用 `UNCalendarNotificationTrigger(repeats: true)` 每天重复。

通知的 `userInfo` 包含 `targetTab` 字段：

```swift
content.userInfo = ["targetTab": AppTab.ai.rawValue]       // 三餐提醒 → AI Tab
content.userInfo = ["targetTab": AppTab.myLife.rawValue]    // 习惯提醒 → 我的 Tab
```

ContentView 通过 `UNUserNotificationCenter.delegate` 的 `didReceive` 回调解析 `targetTab`，设置 `appViewModel.selectedTab` 实现跳转。

习惯归档时必须取消对应的 pending notification（`UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)`）。

## Onboarding 导航

- 支持自由前后切换步骤（返回按钮 + 左滑返回手势），已填写的内容保留在内存中
- 顶部进度指示器（圆点，共 9 步）
- "可跳过"步骤的跳过按钮在「下一步」按钮下方
- 完成页点击"开始记录"时一次性写入所有数据（AppSettings + NutritionGoal + 通知调度）

## 服务层边界

- `NutritionService`：今日/指定日期的营养素汇总计算（含水分摄入）、目标对比、按餐次分组统计、基础代谢估算（Mifflin-St Jeor 公式）。
- `FoodRecognitionService`：封装 AI Vision 调用，接收图片数据，返回识别出的食物列表和营养估算。调用 AIService 的多模态接口。
- `UserFood` / `MealTemplate` / `DrinkRecord`：用户自建食物、餐食模板和饮品知识库。新安装的空 App 不预置家常菜、品牌食品或官方饮品记录。
- `ImageService`：照片压缩（目标 ≤1MB）、缩略图生成（200px）、格式转换。
- `HabitService`：Streak 计算（每天型：连续完成的自然天数，昨天未完成则归零；每周型：连续完成的自然周数，自然周为周一至周日，某周完成次数 ≥ frequencyCount 则该周算完成，周中不判断当前周）、完成率统计、提醒调度。
- `ExportService`：CSV 导出（支持明细粒度和每日汇总两种模式）和 JSON 完整备份。
- `NotificationManager`：三餐提醒和习惯提醒的本地推送调度。
- `AIConfigurationService` / `AIClientFactory` / `AIService`：AI Key 管理、服务商客户端选择、聊天和结构化意图解析。对齐 1Cash，AIService 通过协议扩展增加可选的多模态能力（见「多模态 AI 扩展」）。
- `SpeechInputController`：AI 输入框语音识别控制器。对齐 1Cash。

## AI 调用流程

### 文字记录流程（与 1Cash 对齐）

1. 用户在 AI Tab 输入自然语言（如「午饭吃了一碗米饭和鸡胸肉」）。
2. `LocalAIIntentParser` 先尝试本地规则解析常见中文饮食句式。
3. 如果本地解析失败，`ConfiguredAIService` 调用已配置服务商。
4. 结构化记录由 Prompt JSON 返回，再由 `AIIntentDecoder` 解码。
5. 解析结果进入确认卡片，用户确认后才写入 SwiftData。

### 本地解析器能力边界（LocalAIIntentParser）

1Life 的本地解析比 1Cash 复杂得多。能力分三层：

**可本地解析（不需要 AI）：**
- 单食物 + 份量：「吃了 200g 鸡胸肉」→ 优先匹配用户创建的我的食物
- 常见句式拆分：「米饭和鸡胸肉」→ 按「和/、/，」拆成多个食物名，逐个匹配我的食物
- 餐次识别：「早餐/午饭/晚饭/夜宵」关键词
- 日期识别（对齐 1Cash）：「今天/昨天/前天」→ 对应日期；其他日期表达（如「周三」「上周五」）走 AI
- 水分记录：「喝了一杯水/500ml水」→ 创建 WaterLog

**可部分解析（匹配用户数据成功时可用，否则回退 AI）：**
- 无份量的食物名：「吃了鸡胸肉」→ 匹配我的食物后使用用户保存的默认份量
- 明确提到模板库/饮品模板 → 匹配用户创建的 MealTemplate，复用模板营养数据
- 奶茶、咖啡、果茶等饮品 → 匹配用户通过插件校对入库的 DrinkRecord，按甜度/冰量策略调整

**必须走 AI 的：**
- 用户本地数据未命中的食物名（如「妈妈做的红烧排骨」）
- 复杂描述（如「昨天中午在公司食堂吃的那顿」）
- 拍照识别（必须有网络和 AI 配置）
- 营养分析问答（如「我这周蛋白质够吗」）

**回退策略：**
- AI 未配置且本地解析失败时：提示用户手动创建我的食物/模板，或手动输入营养数据
- AI 已配置但网络不可用时：同上
- 拍照识别在 AI 未配置或无网时：相机按钮灰显并提示原因

### AI 上下文注入压缩策略

为避免占用过多 token（低端模型如 moonshot-v1-8k 上下文窗口有限），AI 上下文注入分级压缩：

**精简级（≤500 token，默认用于结构化意图解析）：**
```
今日摄入: 1240/2000kcal, 蛋白质62/100g, 碳水156/275g, 脂肪45/56g
已记录: 早餐420kcal(3项), 午餐540kcal(4项), 晚餐未记录
饮食目标: 减脂
```

**标准级（≤1500 token，用于营养分析问答）：**
```
今日详情:
- 早餐 420kcal: 燕麦200g(156kcal), 牛奶250ml(162kcal), 蓝莓50g(29kcal)
- 午餐 540kcal: 鸡胸肉150g(165kcal), 米饭200g(232kcal), 西兰花100g(34kcal)
近3天每日汇总: 昨天1860kcal/蛋白质89g, 前天2105kcal/蛋白质76g, 大前天1720kcal/蛋白质92g
```

不发送每个 FoodItem 的全部 8 个营养素，只发热量。三天历史只发每日汇总一行，不发食物明细。习惯列表只发名称和今日状态，不发历史 Streak。

### 拍照识别流程（1Life 独有）

1. 用户点击输入框旁的相机按钮，拍照或选择照片。
2. `ImageService` 压缩图片至 ≤1MB，生成缩略图。
3. 照片以用户气泡展示。AI 消息区域立即显示"正在识别食物…"+ 脉冲动画（对齐 1Cash 的 AI 思考状态）。
4. `FoodRecognitionService` 调用 `AIService.sendMultimodalMessage()`，将图片和识别 system prompt 发送给支持 Vision 的 AI 服务商。
5. AI 返回 JSON 格式的食物识别结果。
6. `AIIntentDecoder` 解码为 `AIParsedMeal`（含多个 `AIParsedFoodItem`）。
7. 每个食物项保留 AI 识别结果，并通过确认卡片让用户校对份量、热量和来源备注。
8. 结果展示为结构化餐食确认卡片，每个食物项可编辑，底部有「+ 添加遗漏的食物」按钮。
9. 用户确认后，创建 Meal + N 个 FoodItem，来源标记为 `.aiPhoto`。

**拍照识别 System Prompt 要点**：
```
你是食物识别助手。请分析照片中的食物，返回 JSON 格式。
对于每种食物，估算：名称（中文）、份量（克或常用单位）、热量（kcal）、蛋白质（g）、碳水（g）、脂肪（g）。
如果无法确定某种食物，标注名称为"未知食物"并给出最佳猜测。
如果照片中没有食物，返回 {"intent": "chat", "response": "这张照片中没有识别到食物..."}。
```
完整 prompt 在 `AIPromptBuilder.makeFoodRecognitionPrompt()` 中维护。

**超时处理**：拍照识别的网络超时设为 45 秒（比普通文字请求的 30 秒更长，因为图片 payload 更大）。超时后显示错误消息并建议重试或手动输入。

### 多模态 AI 扩展

现有家族 `AIClient` 协议只有纯文字的 `send(_ request:)` 方法。1Life 通过**可选协议扩展**增加多模态能力，不 fork 家族基础代码：

```swift
// 新增协议，与家族 AIClient 并行，不修改 AIClient
protocol AIVisionClient {
    var supportsVision: Bool { get }
    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse
}

struct AIVisionRequest {
    let messages: [AIClientMessage]
    let image: AIImageAttachment
    let model: String
    let apiKey: String
}

struct AIImageAttachment {
    let data: Data          // 压缩后的图片数据
    let mediaType: String   // "image/jpeg"
}
```

各服务商在 1Life 的 `AIClients.swift` 中同时遵循 `AIClient`（家族共享）和 `AIVisionClient`（1Life 扩展）：

```swift
// 1Life 的 ClaudeClient 遵循两个协议
struct ClaudeClient: AIClient, AIVisionClient {
    var supportsVision: Bool { true }
    // send() 方法与家族完全一致，直接复用
    // sendWithImage() 方法新增 image content block
}
```

**Vision 能力判断**：按服务商和具体模型双重判断。Claude、OpenAI、Kimi K2.5/K2.6、moonshot vision-preview、Qwen-VL/Qwen-OCR、豆包视觉、混元 Vision、MiMo-V2.5 等可返回 `true`；DeepSeek 当前主 API 和纯文本模型返回 `false`，UI 层据此灰显拍照按钮。

**家族同步策略**：1Cash / 1Track 的 `AIClients.swift` 只遵循 `AIClient`，不受影响。如果未来家族需要多模态，只需让其他 App 的 Client 也遵循 `AIVisionClient`——协议已经设计好，不需要改接口。

## 营养计算口径

- 每日营养汇总 = 当天所有 Meal 下所有 FoodItem 的各营养素之和 + WaterLog 的饮水量。
- 不存在「换算」概念（不像 1Cash 的多币种），所有营养素直接相加。
- 三大宏量素热量换算：蛋白质 4kcal/g，碳水 4kcal/g，脂肪 9kcal/g。此换算仅用于百分比展示，不覆盖 FoodItem 自身的热量值。

### 营养数值显示精度

| 场景 | 精度 | 示例 |
|------|------|------|
| 热量（英雄卡/卡片/列表） | 整数 | 1,240 kcal |
| 宏量素进度条 | 整数 | 62 / 100g |
| 扩展营养素列表 | 整数 | 纤维 18 / 25g |
| 钠（mg 级） | 整数 | 1,520 / 2,000mg |
| FoodItem 行内热量 | 整数 | 165 kcal |
| 手动输入/编辑字段 | 最多 1 位小数 | 31.5g |
| 内部计算/存储 | Double 原始精度 | 不四舍五入 |

显示时使用 `Int()` 截断（不是四舍五入），避免 99.7g 显示为 100g 造成误解。存储和计算不损失精度。

### 份量与克数换算

UserFood 以**每 100g** 为基准提供营养数据。关键换算链路：

```
用户输入「1 份鸡胸肉」
  → 我的食物查到 defaultServingGrams = 150g
  → FoodItem.servingGrams = 150
  → 热量 = UserFood.caloriesPer100g × 150 / 100

用户输入「200g 米饭」
  → 单位是 g，直接使用
  → FoodItem.servingGrams = 200
  → 热量 = AI 估算值或用户手动输入值
```

每种非克单位（份/个/杯/碗/片/块）如果来自 UserFood 或模板，需要有对应的 `defaultServingGrams`。如果用户手动输入的食物单位不是 g/ml，系统要求用户同时输入「1 份 = 多少克」。

- FoodItem 存储的营养素值是**该份量的实际值**（已经按克数换算完成），不是 per 100g 的原始值。
- 用户创建的我的食物、模板库和饮品知识库优先于 AI 估算值：匹配成功时复用本地数据，未匹配时才使用 AI 估算。

### 基础代谢估算

Onboarding 和设置中使用 Mifflin-St Jeor 公式估算每日基础代谢率（BMR），作为热量目标的推荐基准：

```
男性 BMR = 10 × 体重(kg) + 6.25 × 身高(cm) - 5 × 年龄 + 5
女性 BMR = 10 × 体重(kg) + 6.25 × 身高(cm) - 5 × 年龄 - 161
TDEE = BMR × 活动系数（久坐 1.2 / 轻度 1.375 / 中度 1.55 / 重度 1.725）
```

推荐热量 = TDEE × 目标系数（减脂 0.8 / 维持 1.0 / 增肌 1.15）。用户可覆盖。

### 营养数据来源

新安装的空 App 不内置食物营养记录。营养数据来自用户手动输入、用户创建的我的食物/模板/饮品知识库、包装标签换算，或 AI 估算。AI 估算必须在确认卡片中校对后才会保存。

## 图片存储策略

- `Meal.photoData` 和 `JournalEntry.photoData` 使用 `@Attribute(.externalStorage)` 标记。SwiftData 会自动将大二进制数据存储在外部文件中，避免查询时将整行加载进内存导致列表卡顿。对外部的使用方透明——读写仍然像普通 `Data?` 属性。
- 原图压缩后存入 `photoData`（≤1MB JPEG），缩略图存入 `photoThumbnail`（≤50KB JPEG，200px）。缩略图不标记 `externalStorage`，因为体积小，内联存储更利于列表快速加载。
- 列表展示用缩略图，详情页用压缩原图。
- JSON 备份导出时，用户选择"含照片"或"不含照片"。不含照片的 JSON 约 1-5MB，含照片可能 100MB+。默认选"不含照片"。含照片时，照片 base64 编码在对应模型的 JSON 字段中。

## Haptic 触发映射

对齐家族 haptics spec（APP_FAMILY_CONTEXT.md §8）：

| 触发类型 | 场景 |
|---------|------|
| `tap` | 切换 Tab、选择餐次、选择食物、选择心情标签、习惯打卡（+1）、+1杯水、picker 确认 |
| `success` | 餐食记录成功、AI 识别完成确认、习惯今日目标达成、Onboarding 完成、导出完成、模板保存 |
| `warning` | 删除餐食、删除食物、删除习惯、清空聊天历史、清空所有数据、删除日志 |

## 水分追踪策略

- 饮水使用独立的 `WaterLog` 轻量模型，不走 Meal + FoodItem 路径。
- `WaterLog` 只有两个字段：`date: Date` 和 `amount: Double`（毫升）。
- 每次记录喝水只创建一条 WaterLog，不创建 Meal 对象。
- 每日饮水总量 = 当天所有 WaterLog 的 amount 之和。
- 首页「今日」可展示饮水进度（默认目标 2000ml，可在设置中修改）。
- AI 快捷指令「记录喝水」和本地解析「喝了一杯水」都创建 WaterLog。
- 「一杯」默认 250ml，「一瓶」默认 500ml，可在设置中自定义。

## NutritionGoal 与 AppSettings 联查

首页进度环需要同时查询两个模型：
- `NutritionGoal`：获取当前生效的营养目标数值
- `AppSettings.dietGoalModeRaw`：判断当前模式是否为"均衡"

如果 `dietGoalMode == .balanced`，进度环全程主色不变红，目标数字旁标注「参考」。DashboardViewModel 同时持有这两个查询结果。

## Onboarding 完成时的数据创建

Onboarding 最后一步"开始记录"按钮的回调中：
1. 更新 `AppSettings.hasCompletedOnboarding = true` + 写入用户选择的所有设置
2. 创建第一条 `NutritionGoal`（effectiveDate = today，值来自身体参数+饮食目标计算结果）
3. 调度三餐提醒通知

不在 SeedData 中创建 NutritionGoal——SeedData 只负责 AppSettings 的兜底默认值。NutritionGoal 的首次创建由 Onboarding 流程负责。如果用户清空数据后重新 Onboarding，会重新创建。

## ContentView 顶层查询策略

ContentView 只查询必要的模型，其他模型在各 Tab View 内部查询：

```swift
@Query private var settings: [UserSettings]   // Onboarding 检查
// 不查询 Meal、FoodItem、Habit 等 —— 各自 Tab 负责
```

对比 1Cash 在 ContentView 里查询 6 个模型的做法，1Life 精简到只查 AppSettings。NutritionGoal 由 DashboardView 内部查询。SeedData 检查也只需要 settings。

## 用户食物与模板加载策略

新安装的空 App 不内置食物或饮品营养记录。我的食物、模板库和饮品知识库均来自用户手动创建、从历史记录保存、导入 JSON，或通过饮品营养识别插件校对后入库。AIChat 和饮食页只查询这些 SwiftData 模型，不会从静态品牌食品库自动命中。

## Meal 排序规则

饮食页的 Meal 列表排序：先按餐次权重，同权重按 `createdAt`：

| 餐次 | 权重 |
|------|------|
| 早餐 | 0 |
| 午餐 | 1 |
| 晚餐 | 2 |
| 加餐 | 3 |

用户 14:00 补记的早餐（createdAt=14:00）仍排在午餐（createdAt=12:30）上方，因为早餐权重 0 < 午餐权重 1。同一餐次的多个 Meal（如两个加餐）按 `createdAt` 先后排列。

## 食物搜索优先级

手动添加食物时的搜索顺序：

1. **UserFood**（用户自定义食物）— 按使用频次降序，搜索结果标注「我的」标签
2. **最近使用**（最近 7 天记录过的 FoodItem，去重）— 按最近使用时间降序

没有命中用户数据时，用户需要手动输入营养数据，或通过 AI 估算后确认保存。

## Meal 创建与取消策略

用户点击"+ 添加一餐"并选择餐次后，立即创建空 Meal。添加食物在这个 Meal 上操作。如果用户取消（dismiss Sheet）且 Meal 下没有任何 FoodItem，自动删除这个空 Meal。通过 Sheet 的 `onDismiss` 回调检查并清理。

## FoodItem 与 UserFood 的关系

FoodItem 创建后与 UserFood 断开关联，各自独立。用户从 UserFood "鸡胸肉 (150g)" 创建了一个 FoodItem，然后编辑为 200g，这次编辑不会反向同步到 UserFood 的默认份量。FoodItem 是一次性的消费记录，UserFood 是可复用的模板。

## 相机与照片权限

- **相册选择**：使用 `PhotosPicker`（SwiftUI 原生），不需要显式权限请求（系统自动处理有限访问）。
- **相机拍照**：使用 `UIImagePickerController`（sourceType: .camera），需要 `NSCameraUsageDescription`。
- **权限请求时机**：第一次点击相机按钮时触发系统权限弹窗。不在 Onboarding 中预请求，避免首次体验弹太多权限弹窗。
- **权限被拒绝后**：相机按钮仍可点击，但点击后显示引导卡片：「需要相机权限才能拍照识别食物」+ 「去系统设置」按钮。

## WaterLog 撤销机制

首页"+1杯"按钮点击后，底部显示 3 秒的 SnackBar：

```
「已记录 250ml · 撤销」
```

点击「撤销」则删除刚创建的 WaterLog，SnackBar 消失。3 秒后 SnackBar 自动消失，撤销机会结束。避免误点连点造成的多余记录。

## AI 聊天消息分页策略

AIChatMessage 跨会话持久化，不设自动清理。加载策略：

- 打开 AI Tab 时，`@Query` 使用 `SortDescriptor(\AIChatMessage.createdAt, order: .reverse)` + `fetchLimit: 50` 加载最近 50 条。
- 用户滚动到顶部时触发加载更多（向前 50 条），通过修改 `fetchOffset` 或手动查询 `ModelContext`。
- 500 条以上的历史消息建议用户手动清空（设置页入口），不自动删除。

## 同步策略

当前版本为本地存储，iCloud 同步入口禁用并标注「即将推出」。与 1Cash 一致。

## 测试策略

1Life 从第一天开始包含测试（家族规范要求）。

- AI 意图解析测试：本地解析器（单食物、多食物拆分、水分识别、餐次识别）+ 解码器
- 营养计算测试：每日汇总、目标对比、宏量素百分比、BMR 公式、份量换算
- 数据持久化测试：Meal + FoodItem 的 CRUD、一对多关系完整性、Meal 删除级联 FoodItem、AIChatMessage 悬空引用清理
- UserFood 测试：创建、使用次数递增、最近使用排序
- MealTemplate 测试：从 Meal 保存为模板、从模板创建 Meal + FoodItem
- WaterLog 测试：创建、每日汇总、默认杯量计算
- 习惯 Streak 测试：连续天数计算、跨天边界
- 导出测试：CSV 明细粒度 + 每日汇总粒度、JSON 备份恢复
- 图片处理测试：压缩尺寸、缩略图生成、externalStorage 备份编码
