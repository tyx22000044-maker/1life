# 补剂库 / 餐食营养识别 / 补剂营养识别 完成方案

状态：✅ 已实施（2026-07-13）—— 代码已按本方案落地，未经 Xcode 编译验证，建议先在 Xcode 里把下方"新增文件"加入 target 后 build 一遍。
基准：饮品库（`DrinkRecord`）+ 饮品营养识别插件（`DrinkExtractorService` / `DrinkExtractSheet`）—— 目前家族体系里唯一已经完整跑通"识别 → 校对 → 入库 → AI 记录时自动引用"闭环的模块。
范围澄清：Settings →插件 目前有 4 个入口，其中 2 个已完成，不在本次范围内；本方案只覆盖仍处于"规划中"占位态的 2 个库 + 2 个识别插件里的 3 项。

| 入口 | 现状 | 是否本次范围 |
|---|---|---|
| 食物库 → 餐食库（`UserFood` + `MealLibraryHubView` + `UserFoodListView`） | ✅ 已完整实现 | 否，仅作为"目标库已存在"的既有事实 |
| 食物库 → 饮品库（`DrinkRecord` + `DrinkLibraryPluginView`） | ✅ 已完整实现 | 否，作为**基准模板** |
| 食物库 → 补剂库 | ❌ `SupplementLibraryPlaceholderView` 占位 | **是** |
| 插件 → 餐食营养识别 | ❌ `NutritionRecognitionPlaceholderView(kind: .meal)` 占位 | **是** |
| 插件 → 饮品营养识别（`DrinkNutritionRecognitionPluginView`） | ✅ 已完整实现 | 否，作为**基准模板** |
| 插件 → 补剂营养识别 | ❌ `NutritionRecognitionPlaceholderView(kind: .supplement)` 占位 | **是** |

---

## 1. 先拆解基准：饮品库/饮品识别到底是怎么搭的

补剂和餐食两条线严格复刻这套架构，所以先把骨架钉死，后面两节只讲"哪里跟这个不一样"。

```
Models/DrinkRecord.swift
├─ DrinkConfidence            枚举：高(官方)/中(第三方实测)/低(估算)
├─ DrinkAdjustmentPolicy      静态策略：糖度/冰量 → 热量增量区间 + 文本别名归一化
├─ DrinkRecord (@Model)       SwiftData 持久化实体，扁平字段，无嵌套关系
├─ DrinkLibraryEntry (struct) 值类型快照，供内存索引使用，避免跨 context 持有引用
├─ DrinkLibraryMatch          匹配结果：命中的 entry + 命中类型(精确版本/唯一商品/基线调整/默认版本)
└─ DrinkLibraryIndex (单例)   @MainActor 内存索引，App 生命周期内只从 SwiftData 加载一次，
                              写入/删除后 invalidate() 标记失效，下次查询自动重建

Services/AI/DrinkExtractorService.swift
├─ DrinkExtractedDraft        识别后、入库前的可编辑草稿（struct，非 @Model）
├─ DrinkCandidate             候选阶段的轻量结构（只有品牌/名称/规格，无营养值）
├─ DrinkSizeEstimator         规格缺失时的启发式估算（按大/中/小杯关键词回退，默认大杯）
├─ DrinkSugarEstimator        糖分缺失时按碳水或热量反推估算，按品类给不同换算比例
└─ DrinkExtractorService (struct)
   ├─ recognizeText()         阶段1：纯 OCR，只认字不换算，降低视觉模型负担
   ├─ identifyCandidates()    阶段2：从校对后文字里找出候选商品，供用户勾选范围
   ├─ extract(candidates:)    阶段3：只针对已确认候选提取结构化营养 JSON
   └─ 每阶段各自独立的 system prompt（ocrPrompt / candidatePrompt / targetedStructuringPrompt）

ViewModels/AIChatDrinkLibraryResolver.swift
└─ AI 对话解析出 addMeal 意图后，用原始文本反查 DrinkLibraryIndex，
   命中则用库内精确营养值覆盖/追加到 AIParsedFoodItem，并按用户说的糖度/冰量套用
   DrinkAdjustmentPolicy 做热量修正，写入 nutritionDataNote 说明数据来源。

Views/Plugins/DrinkExtractorView.swift（单文件容纳全部 UI，约 1900 行）
├─ DrinkLibraryViewMode        枚举 .library / .plugin，同一个 View 通过 mode 切换文案和"是否显示识别入口"
├─ DrinkLibraryPluginView      库管理页：搜索、按"品牌+商品"分组折叠列表、新增版本、
│                              编辑/删除、JSON导入导出、CSV导出、PDF导出
├─ DrinkNutritionRecognitionPluginView  插件入口页：说明卡片 + "开始识别"按钮（未配置AI时禁用）
├─ DrinkExtractSheet           7 阶段状态机 Sheet：
│                              input → readingText → textReview → identifyingCandidates
│                              → candidateReview → parsing → review
├─ DrinkRecordEditorSheet      手动新增/编辑一条已入库记录
├─ DrinkPDFExportSheet         PDF 导出范围选择
└─ DrinkRecordRow / DrinkRecordGroupSection 等展示组件

Services/Export/
├─ ExportService.exportDrinkLibraryJSON / importDrinkLibraryJSON   转发到 DrinkLibraryExportService
└─ NutritionPDFExportService.exportDrinkLibraryPDF                 独立的 PDF 绘制方法
```

关键设计原则（务必在补剂/餐食两条线保持一致，这是"完全参照"的核心）：

1. **三阶段识别，不是一步到位。** OCR 纯抄录 → 候选商品确认 → 结构化提取，每一步都给用户校对机会，AI 出错的代价被拆到最小颗粒度。
2. **草稿是普通 struct，不是 @Model。** 识别中间态（`DrinkExtractedDraft`）用值类型，用户确认保存那一刻才 `makeRecord()` 转成 SwiftData 实体，避免识别失败/取消污染数据库。
3. **库是扁平字段 + 一个自由文本兜底字段。** `DrinkRecord` 没有任何嵌套 Codable 结构，能枚举的营养素给固定字段，枚举不完的（小料、来源细节）塞进 `toppings`/`sourceNote` 自由文本。
4. **内存索引单例，写后失效。** 不是每次识别都查数据库，`DrinkLibraryIndex.shared` 常驻内存，`invalidate()` 是唯一的失效入口，任何增删记录的地方都要记得调用。
5. **AI 记录时是"客户端二次校正"，不是"把整个库塞进 prompt"。** AI 先按常识估算出一条 `addMeal`，`AIChatDrinkLibraryResolver` 再用原始文本对库做精确文本匹配，命中就覆盖掉 AI 的估算值。这是因为饮品库条目多（同一品牌几十个糖度/杯型版本），塞进 prompt 会让 token 爆炸且未必匹配准。
6. **未知字段一律 null，绝不编造。** 所有识别 prompt 反复强调"看不清/未标注就填 null"，宁可让用户在校对页手填，也不让 AI 编数据冒充官方来源。

---

## 2. 补剂库 + 补剂营养识别（完全对标饮品）

补剂和饮品的相似度最高：都是"品牌 + 商品名 + 规格版本"的知识库条目，都需要 AI 识别包装/成分表校对入库，AI 对话记录时都要精确匹配。**直接复刻饮品的六个文件，替换领域字段即可**，唯一的产品级难点在 2.1 节说明。

### 2.1 需要你先拍板的产品决策：补剂的"营养值"字段怎么定义

饮品的营养画像相对统一（热量/蛋白/碳水/脂肪/糖/钠/咖啡因/茶多酚 8 个固定字段就能覆盖 95% 的现制饮品）。补剂不一样，同一个"补剂库"要装下：

- **蛋白粉/代餐粉**：更像食物，需要热量/蛋白/碳水/脂肪
- **多维/单一维生素**：需要维生素 A/C/D/E/B 族、叶酸等微量营养素剂量
- **鱼油**：需要 EPA/DHA 毫克数（不是标准维生素矿物质字段）
- **肌酸/谷氨酰胺等运动补剂**：只需要"活性成分名 + 剂量"这一种通用结构
- **益生菌**：剂量单位是"CFU"（菌落数），不是克数或毫克数，和其它都不一样

饮品从没遇到过这种"同一张表要装下本质不同的量纲"的问题。我推荐的方案，沿用 `DrinkRecord` 的既有哲学（固定字段覆盖大多数场景 + 一个自由文本字段兜底长尾）：

- 固定标量字段复用 `UserFood` 已有的营养素命名（`caloriesPer...`→ 改成 per-serving 语义、`proteinPer...`、`vitaminAPer...` 等 15 个维生素矿物质字段），这样和餐食库的字段语义一致，未来做"今日营养素汇总"时不用写两套换算逻辑。
- 新增一个 `activeIngredientsNote: String` 自由文本字段，专门装标准字段覆盖不到的"肌酸一水合物 5g；EPA 180mg；DHA 120mg；益生菌 100 亿 CFU"这类描述——**这正是 `DrinkRecord.toppings` 的角色**，不是数据库设计缺陷，是刻意的长尾兜底。
- 结构化字段永远"宁缺毋滥"：一颗多维片剂如果同时含 12 种维生素，AI 识别不全就留空，不强行拆解进自由文本字段——自由文本字段只承接固定字段之外的成分，不做兜底重复记录。

**这一段需要你确认**：如果你希望补剂库对"活性成分"做更结构化的记录（比如未来要按活性成分筛选/汇总"我这个月吃了多少毫克 EPA"），那就不能只用自由文本，需要引入一个轻量的 `SupplementActiveIngredient` 值类型数组（Codable，存成 JSON 字符串字段，SwiftData 无法直接存数组关系，需要手动序列化）。这会比照抄饮品复杂一截，属于本方案唯一偏离"完全参照"基准的地方，建议先按自由文本上线，后续真有筛选需求再升级。

### 2.2 新增文件清单

```
Models/SupplementRecord.swift
```
镜像 `DrinkRecord.swift` 的四个类型，改名不改结构：

```swift
enum SupplementConfidence: String, CaseIterable, Codable, Identifiable {
    case high = "高"    // 官方营养标签/说明书拍照
    case medium = "中"  // 第三方检测报告、电商详情页
    case low = "低"     // 估算、来源不明
}

@Model
final class SupplementRecord {
    var id: UUID
    var brand: String
    var productName: String
    var form: String             // 剂型：片剂/胶囊/软糖/粉剂/液体/其他；未知为空字符串
    var servingSize: String      // 每份说明，如 "2粒"、"1勺(约5g)"、"10ml"；未知为空字符串
    // 以下均为"每份"数值，对齐说明书的计量口径，不做 per100g 折算
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var sodium: Double?
    var calcium: Double?
    var magnesium: Double?
    var potassium: Double?
    var iron: Double?
    var zinc: Double?
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminB1: Double?
    var vitaminB2: Double?
    var niacin: Double?
    var vitaminB6: Double?
    var folate: Double?
    var vitaminB12: Double?
    var activeIngredientsNote: String   // 自由文本兜底：肌酸/EPA/DHA/益生菌等非标准字段成分
    var sourceNote: String
    var sourceDate: Date
    var confidenceRaw: String
    var createdAt: Date
    var updatedAt: Date

    // displayName / dedupeKey 逻辑照抄 DrinkRecord，
    // dedupeKey 用 brand|productName|form|servingSize 四段
}

struct SupplementLibraryEntry { /* 照抄 DrinkLibraryEntry，字段换成上面这套 */ }
struct SupplementLibraryMatch { /* 照抄 DrinkLibraryMatch，MatchKind 复用同一套四档命中语义 */ }

@MainActor
final class SupplementLibraryIndex {
    static let shared = SupplementLibraryIndex()
    // rebuildIfNeeded / invalidate / match / matchResult / search 逻辑照抄 DrinkLibraryIndex，
    // 唯一差异：候选匹配不再需要"糖度/冰量"这一维度，
    // 改成按 form（剂型）做候选收窄——同品牌同商品名可能有片剂版和粉剂版，营养值不同。
}
```

不需要移植的部分：`DrinkAdjustmentPolicy`（糖度/冰量热量调整）没有补剂对应物，补剂的"份数"由用户在 AI 对话里直接说清楚（"吃了2粒"），不需要客户端二次调整热量——照抄 `AIParsedFoodItem.amount` 字段的份数倍乘即可，不用新写一套 Policy。

```
Services/AI/SupplementExtractorService.swift
```
三阶段结构与 `DrinkExtractorService` 完全一致（`recognizeText` / `identifyCandidates` / `extract(candidates:)`），system prompt 改写要点：

- OCR 阶段：抄录目标从"营养成分表/糖度/冰量"改为"品牌、商品名、剂型、每份剂量、营养成分表/活性成分表、建议摄入量"。
- 候选识别阶段：候选判定信号从"品牌+饮品名"改为"品牌+商品名+剂型"（同一盒复合维生素可能有"男士版/女士版"两个候选，剂型信息是区分候选的关键，务必保留）。
- 结构化提取阶段：最低入库门槛改为 `brand` + `name` 必须有，**不再强制 `calories_kcal` 必须有**（这是和饮品的关键差异——一瓶维生素 D 滴剂没有热量，只有 vitamin_d_iu，若照搬饮品"必须有热量才入库"的门槛，会导致纯维生素矿物质类补剂永远无法入库）。改为"至少有一个营养/活性成分字段非空"作为门槛。
- 新增 `active_ingredients_note` 字段的提取规则：只填写标准字段（上面列的 16 个营养素）无法承载的成分，且必须写明剂量和单位，不确定单位不要编。
- 不需要 `DrinkSizeEstimator`/`DrinkSugarEstimator` 那类启发式估算器——补剂缺规格就是缺规格，不像饮品"没写杯型就按大杯估算"有约定俗成的默认值，补剂强行估算风险更高（剂量estimation 对补剂类产品是敏感信息），**未知就留空，交给用户在校对页手填**。

```
ViewModels/AIChatSupplementLibraryResolver.swift
```
镜像 `AIChatDrinkLibraryResolver`：

- `applyMatch(to:originalText:modelContext:)`：AI 解析出 `addMeal` 后，用原始文本反查 `SupplementLibraryIndex`，命中则覆盖 `AIParsedFoodItem` 的营养字段。
- 不需要 `shouldPreferLibraryOnlyIntent` 那套"喝/吃"关键词消歧——补剂在库内命中的判定已经足够强（品牌+商品名精确出现在文本里），不需要额外的动词信号层。直接照抄 `match(text:)` 的核心逻辑即可，省掉饮品那层消歧包装。
- `makeFoodItem` 转换時 `mealType` 固定给 `.snack`（与饮品记录到 snack 的既有约定一致，`AIPromptBuilder.swift:124` 已经写明"零食饮品类→snack"，这条注释后续要顺带扩成"零食/饮品/补剂类→snack"）。
- 份数处理：补剂通常按"粒/份"计数而非连续计量，`AIParsedFoodItem.amount` 直接取用户说的份数（"吃了2粒"→amount=2），营养值按 `SupplementRecord` 的每份数值 × amount 计算，这一步饮品没有（饮品是整杯记录，不存在"喝了2杯"要乘 2 的场景，因为通常会拆成两条记录）——**这是唯一需要新写的换算逻辑**，不能照抄。

```
Views/Plugins/SupplementExtractorView.swift
```
镜像 `DrinkExtractorView.swift` 整个文件结构，对应关系：

| 饮品（基准） | 补剂（新增） | 差异 |
|---|---|---|
| `DrinkLibraryViewMode` | `SupplementLibraryViewMode` | 文案替换，逻辑不变 |
| `DrinkLibraryPluginView` | `SupplementLibraryPluginView` | 分组维度从"品牌+商品名"不变；组内版本排序从"糖度/小料"改成"剂型/规格" |
| `DrinkNutritionRecognitionPluginView` | `SupplementNutritionRecognitionPluginView` | 文案替换 |
| `DrinkExtractSheet` | `SupplementExtractSheet` | 7 阶段状态机完全照抄，字段表单换成补剂字段 |
| `DrinkRecordEditorSheet` | `SupplementRecordEditorSheet` | 表单字段换成补剂字段，分区建议：基本信息(品牌/商品/剂型/规格) / 常规营养(热量/三大营养素/钠) / 维生素矿物质(16个可折叠展开) / 其它活性成分(自由文本) / 来源与可信度 |
| `DrinkPDFExportSheet` | `SupplementPDFExportSheet` | 复用同一套日期范围选择 UI 骨架 |
| `LegacyDrinkTemplateMigrator` | **不需要** | 补剂没有"旧版模板"历史包袱，饮品这个迁移器是处理 App 早期版本遗留数据的一次性代码，补剂从第一天就是新库，不需要迁移逻辑 |

不需要移植的组件：`DrinkSizeEstimator`/`DrinkSugarEstimator` 相关 UI 提示文案（如"规格按大杯估算"角标）——补剂不做估算，校对页对应位置直接留空即可，不需要"已按 XX 估算"的提示角标逻辑。

### 2.3 导出/导入服务

```
Services/Export/ExportService.swift   新增两个转发方法
  exportSupplementLibraryJSON(_:) → SupplementLibraryExportService.exportJSON(_:)
  importSupplementLibraryJSON(_:into:existingRecords:) → SupplementLibraryExportService.importJSON(...)

Services/Export/SupplementLibraryExportService.swift   新文件，镜像 DrinkLibraryExportService
Services/Export/NutritionPDFExportService.swift         新增 exportSupplementLibraryPDF(records:) 方法
  照抄 drawDrinkLibraryHeader / drawDrinkCard 的排版逻辑，卡片内容换成补剂字段
```

### 2.4 Settings 接线（改动最小的一步，最后做）

`Views/Settings/SettingsView.swift`：

```diff
- NavigationLink { SupplementLibraryPlaceholderView() } label: {
+ NavigationLink { SupplementLibraryPluginView(mode: .library) } label: {
      AppSettingsRow(..., value: "\(supplementRecords.count) 条", ...)
  }
```
```diff
- NavigationLink { NutritionRecognitionPlaceholderView(kind: .supplement) } label: {
+ NavigationLink { SupplementNutritionRecognitionPluginView() } label: {
      AppSettingsRow(..., value: currentVisionSupport ? "支持图片" : "文字可用", ...)
  }
```
需要新增一个 `@Query private var supplementRecords: [SupplementRecord]` 到 `SettingsView`，照抄现有 `drinkRecords` 查询那一行。
完成后删除 `SupplementLibraryPlaceholderView` 结构体，以及 `NutritionRecognitionPlaceholderKind.supplement` 分支（`NutritionRecognitionPlaceholderView` 结构体本身要保留给餐食识别用，见第 3 节）。

---

## 3. 餐食营养识别插件（目标库是已有的 UserFood，不是新建模型）

这一条和补剂的性质不一样，容易踩坑，先讲清楚差异：

**餐食库（`UserFood`）已经是完整实现的功能**——`Views/Settings/UserFoodListView.swift` 已经能手动增删改查，`AIChatViewModel.swift:49-55` 已经把 `UserFood` 列表喂给 AI 对话上下文（AI 记录"吃了3个鸡蛋"时已经能参照用户已建好的食物库）。**唯一缺的是"拍照/拍营养成分表 → AI 识别 → 校对 → 存进 UserFood"这一条录入路径**，等价于给已经建好的房子补一扇没装的门，不是从零建一栋楼。所以本节工作量明显小于第 2 节。

### 3.1 关键差异：per-100g 口径 vs 饮品的整份口径

`UserFood` 的营养字段全部是 `xxxPer100g`（每 100 克/毫升），这是餐食库的既定口径（因为用户吃的份量是变量，早餐吃 50g 燕麦和 100g 燕麦要能用同一条库记录算出不同热量）。饮品库反过来是"整杯"口径，因为一杯奶茶通常整杯喝完，不存在"喝了 60% 杯"的常见场景。

这意味着 `MealNutritionExtractorService` 的结构化提取 prompt **不能照抄** `DrinkExtractorService.targetedStructuringPrompt`，必须新写换算规则：

- 中国大陆预包装食品营养标签强制要求同时标注"每 100g/100ml"和"每份"两栏，AI 识别时优先直接读取"每100g"那一栏；只有包装只标"每份"时才需要 AI 用"每份重量"换算成每100g（`per100g = perServing / servingGrams * 100`），这一步的换算提示要写清楚公式，避免 AI 算错。
- 不需要 `DrinkSizeEstimator` 那类"规格缺失按大杯估算"的兜底——`UserFood.defaultServingGrams` 已有默认值 100，识别不到规格时直接留给用户在校对页确认，不做启发式猜测。

### 3.2 新增文件清单

```
Services/AI/MealNutritionExtractorService.swift
```
三阶段结构照抄 `DrinkExtractorService`：

- `recognizeText(imageDataList:text:)`：OCR，抄录目标是"食品名称、配料表、营养成分表(每100g/每份两栏都要抄全)、净含量"。
- `identifyCandidates(fromConfirmedText:)`：候选识别，一张包装照片通常只有一个候选（不像奶茶菜单一张图可能有十几个候选），但要支持"一次拍多个食品"的场景（比如一次性把冰箱里 5 样食材都拍了）。
- `extract(fromConfirmedText:candidates:)`：结构化提取，输出字段直接对齐 `UserFood` 的 27 个 `xxxPer100g` 字段，JSON key 命名建议加 `_per100g` 后缀避免和"每份"混淆。
- 复用 `UserFood` 已有的 `defaultAmount`/`defaultUnit`/`defaultServingGrams` 三个字段承接"建议每份多少克/多少份"这个识别产出。

```
struct MealNutritionExtractedDraft   // 定义在同一个 Service 文件里，照抄 DrinkExtractedDraft 的角色
```
草稿字段对齐 `UserFood` 的 init 参数表，`isValid` 判定：`name` 非空 + `caloriesPer100g` 非空（这一点和饮品一致，餐食热量是硬门槛，不像补剂可以没有热量）。

```
Views/Plugins/MealNutritionExtractorView.swift
```

| 饮品（基准） | 餐食（新增） | 差异 |
|---|---|---|
| `DrinkNutritionRecognitionPluginView` | `MealNutritionRecognitionPluginView` | 文案替换；"当前饮品库"卡片改成"当前餐食库"，`\(userFoods.count) 条` |
| `DrinkExtractSheet` | `MealNutritionExtractSheet` | 7 阶段状态机照抄；review 阶段的保存动作改为 `UserFood(caloriesPer100g: ...)`（走现有 init），而不是新建一个 `@Model` |
| `DrinkRecordEditorSheet` | **不需要新建** | 已存在的 `UserFoodListView.swift` 里应该已经有编辑入口（若没有，只需给 `UserFoodListView` 补一个编辑 Sheet，而不是新写一个和饮品平行的编辑器——这是复用既有库管理页的关键一步） |
| `DrinkLibraryPluginView`（库管理页） | **不需要新建** | 直接用现有 `UserFoodListView.swift`，识别结果 confirm 后 `dismiss()` 回到餐食库列表即可看到新记录 |
| `DrinkPDFExportSheet` | **不需要新建** | 餐食库导出已有 `MealTemplateExportService`/`NutritionPDFExportService` 覆盖，不重复造轮子 |

也就是说餐食这条线实际只需要新增 **1 个 Service 文件 + 1 个识别入口 View + 1 个识别 Sheet**，比补剂那条线（1 个 Model + 1 个 Service + 1 个 Resolver + 1 个大 View 文件 + 1 个导出 Service）小得多。

### 3.3 需要确认一件事：识别产出重复食材怎么处理

饮品库允许同一品牌商品有多个"版本"（不同糖度各存一条），餐食库的 `UserFood` 目前看不到"同名多版本"的设计（`UserFoodListView` 大概率是按名称唯一管理）。如果 AI 识别出"鸡蛋"而库里已经有一条"鸡蛋"记录，`MealNutritionExtractSheet` 的保存动作需要判断：

- 直接新建一条重复记录（简单，但会让餐食库出现"鸡蛋"×2、"鸡蛋(2)"这类脏数据）
- 还是识别到重名时提示"是否更新已有记录的营养值"（需要 `UserFood` 增加一个类似 `dedupeKey` 的按名称查重逻辑）

建议采用后者，保存前查一次 `userFoods.first(where: { $0.name == draft.name })`，命中则询问"更新已有记录 / 另存为新记录"，这个交互饮品库没有对应物（因为饮品允许多版本并存），是本方案里少数几个"参照基准但要补一层饮品没有的判断"的地方。

### 3.4 Settings 接线

```diff
- NavigationLink { NutritionRecognitionPlaceholderView(kind: .meal) } label: {
+ NavigationLink { MealNutritionRecognitionPluginView() } label: {
      AppSettingsRow(..., value: currentVisionSupport ? "支持图片" : "文字可用", ...)
  }
```
完成后 `NutritionRecognitionPlaceholderKind.meal` 分支一并删除；若补剂那条线也做完了，`NutritionRecognitionPlaceholderView`/`NutritionRecognitionPlaceholderKind`/`SupplementLibraryPlaceholderView` 三个占位结构体可以整体从 `SettingsView.swift` 里删掉。

---

## 4. 共用基础设施核对（不用新建，确认现有组件够用）

| 需要的能力 | 现有组件 | 补剂/餐食是否可直接复用 |
|---|---|---|
| 拍照/多图选择 | `AIImagePicker.swift`、`Services/Image/ImageService.swift` | ✅ 直接复用，无需改动 |
| 全局 Toast 反馈 | `GlobalBannerCenter` | ✅ 直接复用 |
| 系统分享面板 | `Views/Settings/ShareSheet.swift` | ✅ 直接复用 |
| AI 视觉/文本请求封装 | `Services/AI/AIClient.swift`、`AIClients.swift` | ✅ 直接复用，新 Service 只需组装 prompt |
| 触感反馈 | `HapticEngine` | ✅ 保存成功 `.success()`，删除/清空 `.warning()` |

**是否应该把三条识别流程（饮品/补剂/餐食）的"7 阶段状态机"抽成一个共享的通用组件？** 不建议现在做。项目既有约定（`APP_FAMILY_CONTEXT.md` 第13节"不要过早泛化"同样的哲学在 1Life 内部也适用——`Services/Export/` 下 PDF/CSV/JSON/Backup 四个导出服务从没被合并成一个泛型服务）是优先保持每个领域文件独立、复制后按领域特化，等到第三个领域稳定跑起来后再评估是否值得抽公共骨架。现在补剂和餐食都是"复制饮品改字段"，抽象时机还没到，先照抄。

---

## 5. 测试

对照 `docs/ROADMAP.md` 现有"测试"清单（饮品知识库测试目前也还是空的，属于家族性欠账），本次新增功能建议至少补：

- [ ] `SupplementExtractorService` 解析测试：JSON 解析容错（markdown 包裹、字符串数字、null 处理）、`isValid` 门槛判定（无热量但有维生素 D 的记录应该能通过）
- [ ] `SupplementLibraryIndex` 匹配测试：品牌+商品名精确匹配、剂型消歧、唯一商品名兜底匹配
- [ ] `AIChatSupplementLibraryResolver` 测试：份数倍乘换算（"吃了2粒" → 营养值 ×2）
- [ ] `MealNutritionExtractorService` 解析测试：每100g/每份换算公式正确性、reuse `UserFood.defaultServingGrams` 默认值
- [ ] 重名 `UserFood` 更新 vs 新建的交互测试

---

## 6. 建议实施顺序

1. **餐食营养识别插件**（第3节）—— 工作量最小，且能最快验证"复用饮品识别骨架"这套方法论在新领域是否顺畅，作为补剂那条更复杂的线的探路者。
2. **补剂库数据模型 + Index**（2.1、2.2 前半）—— 先把 2.1 节的产品决策定下来（自由文本兜底 vs 结构化活性成分数组），这一步不确定会阻塞后面所有工作，建议最先对齐。
3. **补剂识别 Service + Resolver**（2.2 后半）
4. **补剂 View 层 + 导出服务**（2.2 View 部分、2.3）
5. **两条线一起做 Settings 接线并删除占位代码**（2.4、3.4）—— 放在最后，这样占位视图在开发期间始终可用，不会中途出现"点进去空白"的体验断档。

## 7. 验收标准

- [ ] 补剂库：能拍摄补剂说明书/营养标签，经 OCR 校对、候选确认、结构化提取三步后入库；同品牌不同剂型/规格可并存为多个版本；支持 JSON/CSV/PDF 导出与 JSON 导入
- [ ] 补剂营养识别插件页可独立进入，未配置 AI 时按钮禁用（与饮品一致的降级体验）
- [ ] AI 对话里说"吃了2粒 XX 牌鱼油"，能命中补剂库并按份数正确换算营养值，写入 `nutritionDataNote` 说明数据来源
- [ ] 餐食营养识别插件：拍摄食品营养成分表，识别产出的每100g数值经校对后存入 `UserFood`，随后能在餐食库列表和 AI 对话食物库上下文里看到
- [ ] 重复食材名识别时给出"更新已有 / 另存新记录"的选择，不静默产生重复库项
- [ ] `SettingsView.swift` 中三个占位结构体（`SupplementLibraryPlaceholderView`、`NutritionRecognitionPlaceholderView`、`NutritionRecognitionPlaceholderKind`）全部移除，`pluginSection`/`foodLibrarySection` 的 `value:` 从"规划中"变成真实计数
- [ ] `docs/ROADMAP.md` "用户食物与模板库"小节补上"补剂知识库"一行，标记完成日期
