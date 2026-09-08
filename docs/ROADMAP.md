# 1Life 功能 Roadmap

> 最后更新：2026-07-14
> 状态说明：✅ 已完成 | ❌ 待开发 | 🔮 后续版本

---

## 2026-07-14 修复状态

- ✅ `SupplementRecord` 已注册进 `OneLifeApp.swift` 的 SwiftData model container。
- ✅ 三个识别插件在打开相机前主动收起键盘；`ContentView.swift` 中未经验证的固定 60pt Tab 补丁已移除。
- ✅ Onboarding 的提醒 Toggle 和 AI Provider Picker 已显式对齐家族样式。
- ✅ 日志斜体快捷键已改为单星号 Markdown 语法。
- ✅ 训练周目标非法输入不再静默丢弃，会保留输入并显示合法范围提示。
- ✅ 导出 CSV/PDF、JSON 备份、JSON 恢复和清空数据补齐站内状态提示；训练和身体数据的 Apple Health 导入统一使用站内 Banner。
- ✅ 新增训练明细 CSV 与训练专用 JSON 导出入口。
- ✅ 动态 TDEE 目标校准：Apple Health 只动态调整热量目标，宏量素和其余营养目标保持已保存的固定值；Dashboard、饮食页和设置页不再把动态宏量素写回目标。
- ✅ 已新增隐私说明、App Store 审核说明、截图计划和医疗/营养免责声明草案，并同步加入 README 文档索引。

## 仍需运行环境验证

- ⚠️ 当前环境只做了 Swift 静态语法、差异和代码链路核验，没有 build、真机、模拟器或 XCTest 运行验证。
- ⚠️ 需要在 Xcode 中验证 SwiftData 容器迁移、相机/键盘 Tab 高度、HealthKit 权限、导出分享、备份恢复和清空数据流程。
- ⚠️ 现有单元测试仍未在真实工程中编译和运行；UI smoke tests、HealthKit 集成测试和 AI 网络集成测试仍未覆盖。

## 2026-07-13 已知问题（已处理）

在写 `docs/structure/01_启动与Onboarding.md` 逐行核对代码时顺带发现，记录在这里避免遗漏：

- ✅ **`SupplementRecord` 模型注册**——已加入 `OneLifeApp.swift` 的 `.modelContainer(for: [...])`，仍需运行时验证容器迁移和补剂库读写。
- ✅ **Onboarding 控件样式**——提醒 Toggle 已显式使用 `AppSwitchStyle`，AI Provider Picker 已显式使用家族强调色和 menu 样式。

在写 `docs/structure/05_Tab4_回顾MyLife.md` 时新发现：

- ✅ **日志斜体快捷按钮**——已改为追加单个 `*`，生成标准 Markdown 斜体语法。
- ✅ **Apple Health 导入反馈**——身体数据和训练导入均使用 `GlobalBannerCenter` 反馈成功、无新数据和失败状态。
- ✅ **训练周目标输入**——非法值现在显示范围提示，不再静默丢弃。

在写 `docs/structure/06_Tab5_设置.md` 时新发现（尚未修复）：

- ❌ **`SettingsDataCoordinator.clearAllData` 遗漏了 `DrinkRecord` 模型**——该方法逐个 `modelContext.delete(model:)` 删除了 14 个模型类型（含 `SupplementRecord`），唯独没有 `DrinkRecord.self`。实际影响：用户点"清空所有数据"后，饮品库记录会被完整保留下来，与提示文案"删除饮食、习惯、日志、模板和聊天历史"承诺的范围不符。
- ❌ **`ProfileEditorSheet` 的头像同样未压缩**——`Views/Settings/ProfileEditorSheet.swift` 里 `PhotosPickerItem.loadTransferable` 读出的原始 Data 直接赋给 `avatarData`，和 Onboarding 头像未压缩是同一个问题的第二个复现点，说明"头像录入"这条功能线整体没有接入 `ImageService.compress`，不止 Onboarding 一处。
- ❌ **`UserFoodListView` 的批量删除没有二次确认**——`Views/Settings/UserFoodListView.swift` 里多选模式下的"删除 N 条"按钮直接执行 `modelContext.delete`，没有任何确认弹窗，是全 App 目前唯一一处"能一次性删除多条记录、却比单条删除（走 `contextMenu` 二次点击）更缺乏保护"的路径。

对照 2026-07-13 站内信重新核对代码时新发现：

- ❌ **`UserFood` 有两条写入路径、两种营养口径，未完全统一**——`Views/Food/AddFoodView.swift` 里 `AddFoodSheet`"收藏到我的食物"勾选后走的是旧的 `caloriesPer100g` 反推口径（只写这一个字段）；`Views/Settings/UserFoodListView.swift` 的 `UserFoodEditorView`（餐食库自己的编辑器）走的是新的"每份营养"口径（写入 `servingNutrition` JSON 字典）。读取侧靠 `food.servingNutrition["calories"] ?? food.caloriesPer100g` 兜底热量字段，但蛋白/碳水/脂肪等其它营养素未必有同样的兜底逻辑，需要确认从 Food Tab"收藏"产生的 `UserFood` 记录在餐食库和其它读取路径下营养素展示是否完整。

2026-07-14 做全 App 视觉一致性全量普查（对照家族设计对齐系列，非抽样，逐类关键词全量 grep 后逐条核实）新发现，均为具体、独立、单点可修的问题：

- ❌ **`SupplementExtractorView.swift:1133` 的补剂图标漏加 `.fill`**——写的是 `"pills"`，同文件其余 6 处（168/439/676/739 行等）全部是 `"pills.fill"`，是复制代码时的孤立疏漏。
- ❌ **`DrinkExtractorView.swift:1207` 的饮品图标漏加 `.fill`**——写的是 `"cup.and.saucer"`，全项目其余 13 处（含 `SettingsView.swift`/`MealTemplateListView.swift`/`Models/SharedTypes.swift`）全部是 `"cup.and.saucer.fill"`，同类疏漏。
- ❌ **`AIChatMealEditors.swift:119` 的 Sheet 关闭按钮文案是"关闭"，全 App 其余 27 处同类按钮统一叫"取消"**——是全项目唯一一处措辞孤例（`ParsedFoodItemEditorSheet` 的取消按钮）。
- ❌ **"新增"概念的图标语言全 App 并存三套**：(1) 面板内嵌 34×34 黑方块+裸 `"plus"`（家族规范，最常见）；(2) `"plus.circle"` 线框图标+文字 Label，出现在三个识别插件的"新增版本/添加食物/添加饮品/添加补剂"按钮（`SupplementExtractorView.swift:582,1149`、`MealNutritionExtractorView.swift:557`、`DrinkExtractorView.swift:653,1223`、`MealTemplateListView.swift:1165`、`MealCardView.swift:193`）；(3) `"plus.circle.fill"` 实心圆，只在 `SupplementExtractorView.swift:640` 和 `DrinkExtractorView.swift:711` 两处——同一类"新增版本"按钮，一处线框一处实心，是具体的孤立不一致，建议统一成同一种。
- ⚠️ **圆角裸数字里有 12 处存在"改 token 不会联动"的风险**——全项目 `cornerRadius:` 裸数字统计里，有 7 处硬编码 `10`（和 `FamilyUI.controlCornerRadius` 数值相同）、5 处硬编码 `12`（和 `FamilyUI.panelCornerRadius` 数值相同），混在大量正确引用 token 的代码中间，肉眼分辨不出哪些是硬编码、哪些是 token 引用；以后调整这两个 token 的数值时，这 12 处不会跟着变。裸数字 `8`（89处，图标盒圆角）和 `6`（33处，等同 `badgeCornerRadius`）已经是全 App 公认的手写惯例，风险相对低，不算在内。
- ✅ **确认不是问题**：`tracking(1)` 只有 4 处（`ContentView.swift:160`、`DashboardView.swift:226,953`、`FoodTimelineView.swift:677`），逐条核实后确认是和 `tracking(1.2)`（29处，SystemPanel 标题级）平行的第二级"微标签"字距体系，统一搭配 `font(.system(size: 10, weight: .semibold))`，不是遗漏统一数值。
- ⚠️ **`caption2` 字号下混用四种字重**（`.semibold` 53处/`.bold` 29处/`.black` 25处/`.medium` 3处），抽样显示 `.black` 多用于数值/强调场景，但 `.semibold` 与 `.bold` 两档之间没有确认出清晰的语义分工规则，待进一步排查是否需要收敛。
- 裸色系统色字面量全量核实后精确清单为 6 处（此前"57处"是粗略 grep 计数含误报，已重新核实）：`AIChatComponents.swift:245`、`AIChatMealReviewComponents.swift:143,629`（AI 营养估算提示，橙色）、`FoodTimelineComponents.swift:128,131,134`（`MacroRatioBar` 蛋白/碳水/脂肪三色横条，未走 `FamilyUI`）。
- 动效 `duration` 参数全项目有 8 种不同数值（0.18/0.2×10/0.22×2/0.25×5/0.28/0.34×2/0.4/0.5），人工 loading 延迟有 3 种（120ms×5/160ms×2/180ms），均未定义成共享常量，非 bug 但建议后续收敛成 token 便于统一调整节奏感。

---

## 2026-07-10 单元测试基础设施补齐

1Life 此前没有真正的 XCTest target —— README/ROADMAP 里"业务单元测试"是既有描述但代码库里从未落地（`project.pbxproj` 里只有 `com.apple.product-type.application` 一个 target）。本轮把它补上。

### 已完成 ✅

- 新增 `1LifeTests` target：由于 1Life（不同于 1Parcel）没有 `project.yml`/xcodegen，改为直接手工编辑 `project.pbxproj` 追加一个 `bundle.unit-test` target（`PBXNativeTarget` + 对应的 build phases、`PBXTargetDependency`、`XCConfigurationList`），沿用工程本身的 Xcode 16 file-system-synchronized-group 格式（新增文件放进 `1LifeTests/` 目录即自动纳入编译，不需要逐个登记 `PBXBuildFile`）。同时给主 App target 显式加了 `PRODUCT_MODULE_NAME = OneLife`（之前依赖 Xcode 对以数字开头的 `PRODUCT_NAME` 的隐式改名，`@testable import` 需要一个确定的模块名）。
- 新增 16 个测试文件、约 136 个测试方法，覆盖：
  - `SugarLevelAdjuster`（糖度/杯型规则解析）
  - `HabitService`（每日/每周连续打卡、达标率计算）
  - `WorkoutService`（训练日宏量调整、周报、连续训练天数、赛前/赛后建议文案）
  - `NutritionService`（每日营养汇总、BMR 公式）
  - `AppSettings` 的 BMR/TDEE/宏量目标计算（含按体重倍数 vs 按比例两种蛋白策略、HealthKit 动态 TDEE 分支）
  - `LocalAIIntentParser`（本地规则识别：运动/排便/体测/喝水/模板匹配/日记情绪与标签/餐食解析，含"奶茶不算喝水"这类排除逻辑）
  - `AIIntentDecoder`（AI 返回 JSON 的意图解码，含 batch/多餐/create_template/未知 intent 兜底）
  - `DrinkAdjustmentPolicy` + `DrinkLibraryIndex`（糖冰量热量调整、饮品知识库模糊匹配优先级）
  - `AIChatRecordDateResolver`（"昨天/昨晚/早上10点"等相对时间解析）
  - `AIParsedMealPersistenceMapper`（单位换算克数、写入 `FoodItem`/`TemplateFoodItem`）
  - `AIChatMealValidation`（宏量与热量互相校验、未经证实的"官方数据"来源降级、拍照识别份量区间估算）
  - `AIChatDrinkLibraryResolver` 的 `waterAmount`/`shouldPreferLibraryOnlyIntent`
  - `CSVExportService`（明细/日汇总两种粒度、CSV 转义、BMI 计算）
  - `BackupRecords`（`FoodItemRecord`/`MealRecord`/`HabitRecord`/`HabitLogRecord`/`WaterRecord`/`BackupFile` 的 JSON 往返和 `.model()` 重建时 id 是否保留）
  - `Meal`/`MealTemplate`/`Habit`/`DrinkRecord` 等 `@Model` 的计算属性
- 处理了这个 target 引入的一个实际约束：主 App target 开了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（Approachable Concurrency），大部分未显式标 `nonisolated` 的类型（`LocalAIIntentParser`、`AIIntentDecoder`、`HabitService`、`WorkoutService`、`AppSettings` 等）默认按 MainActor 隔离；测试类相应加了 `@MainActor`，只有 `DrinkAdjustmentPolicy`、`AIChatMealValidation`、`CSVExportService` 这几个源码里显式 `nonisolated` 的例外不需要。

### 尚未覆盖 / 已知风险 ❌

- **这轮测试代码从未被真正编译或运行过**——受限于当前环境不能跑 `xcodebuild`/模拟器，所有 136 个测试方法都是基于通读源码后手工推演的预期结果，还没有被编译器和真实运行验证过。第一步必须是在 Xcode 里 `Cmd+B` 编译，再 `Cmd+U` 跑一遍，把失败的用例贴回来定位。
- `BackupRestoreService`、`AIChatViewModel`、`NotificationManager`、`HealthKitService`、`ImageService` 等依赖真实 SwiftData 持久化/系统权限/网络调用的模块仍未覆盖——这批测试都是纯逻辑单元测试，没有集成测试。
- UI smoke tests 仍然是 0；上面这条待办本质没变，只是"业务逻辑单元测试"这部分从"缺失"变成"存在但未验证"。
- 其余 7 个 AI 服务商的真实网络调用路径（`AIClient`/`AIClients.swift`）没有测试覆盖，需要真实 API Key 才能做集成测试，本轮未处理。

---

## 2026-07-03 App Family Reference 更新

本轮把 1Life 从“V1.0 功能收尾”推进为 1App family 的参考实现，重点是模块边界、导出能力、AI 可靠性和 Family UI V2。

### 已完成 ✅

- 新增 `SystemPanel` 和错误横幅等 Family UI V2 原语，Settings 与二级面板视觉更统一。
- AI Chat 拆分为数据上下文构建、意图记录、餐食记录、餐食校验、日期解析、饮品库解析和 insight 回复构建等 ViewModel 协作模块。
- 新增饮品记录模型和饮品提取服务，AI 可围绕饮品知识库做结构化识别。
- Food Timeline 拆出餐食写入、食物行、批量添加、模板选择、餐食详情、营养编辑字段等组件。
- Settings 数据区拆出 `SettingsDataCoordinator`、`SettingsDataSection`、PDF 导出范围、ShareSheet、资料编辑、提醒设置等独立模块。
- 导出服务扩展为 JSON 备份、CSV、餐食模板导出和营养 PDF 导出等分层服务。
- 新增 `BodyMeasurement`，身体参数和历史测量数据具备继续深化空间。
- 强化清空数据流程，降低误删风险并改善失败处理。
- App Icon 与 Splash Icon 更新到 family 统一资产方向，补充深色 Splash 图。
- 新增 `AI_REFACTOR_LOG.md` 和 `docs/UI_STYLE_GUIDE_V2.md` 记录重构与视觉标准。

### 仍需继续 ❌

- 将导出、备份、恢复和清空数据流程接入更完整的 App Inbox / operation status。
- 补 Food/AI/Export 的集成测试和 UI smoke tests（2026-07-10 已补上纯逻辑层的单元测试，见下方新条目；集成测试和 UI smoke tests 仍是 0）。
- 完成隐私文档、App Store 截图、审核说明和医疗/营养免责声明。
- 继续把 1Life 的 reference 模式沉淀到 `APP_FAMILY_CONTEXT.md`，供 1Cash/1Track/1Pet 复用。

---

## V1.0 — 首次发布

### 项目基础

- [x] App 入口重命名：`_LifeApp` → `OneLifeApp` ✅
- [x] Info.plist 权限：NSCameraUsageDescription、NSMicrophoneUsageDescription、NSSpeechRecognitionUsageDescription、NSPhotoLibraryUsageDescription、NSHealthShareUsageDescription ✅
- [x] Schema 版本：`currentDataSchemaVersion = 4` ✅
- [x] JSON 备份版本：`ExportService.supportedBackupVersion = 5` ✅

### SwiftData 模型（13 个）

- [x] `AppSettings`：单例，身体参数全 Optional，Apple Health 状态，饮水设置，AI 配置，Onboarding 状态 ✅
- [x] `NutritionGoal`：带 effectiveDate，支持历史目标 ✅
- [x] `Meal`：精确到分钟，mealTypeSortOrder 排序，`@Attribute(.externalStorage)` 照片 ✅
- [x] `FoodItem`：calories 必填，其余营养素 `Double?`，servingGrams 份量换算 ✅
- [x] `UserFood`：用户自定义食物，使用频次排序 ✅
- [x] `UserFood` / `MealTemplate` / `DrinkRecord`：用户自建食物、模板和饮品知识库 ✅
- [x] `MealTemplate`：JSON 快照，防御性解码 ✅
- [x] `WaterLog`：轻量独立模型 ✅
- [x] `Habit`：frequencyTypeRaw + frequencyCount ✅
- [x] `HabitLog`：完成记录 ✅
- [x] `JournalEntry`：固定活动标签枚举 ✅
- [x] `JournalPhoto`：最多 9 张，`@Attribute(.externalStorage)` ✅
- [x] `AIChatMessage`：`nonisolated`，悬空引用标记 ✅
- [x] `SharedTypes`：所有枚举定义 ✅

### App 骨架

- [x] `OneLifeApp.swift`：ModelContainer 配置 + SplashView ✅ 2026-06-25
- [x] `ContentView.swift`：TabView + Onboarding 路由 ✅ 2026-06-25
- [x] `AppViewModel`：selectedTab + selectedDate ✅ 2026-06-25
- [x] `AppTab` 枚举：dashboard / food / ai / myLife / settings ✅ 2026-06-25
- [x] `SeedData`：AppSettings 兜底 + NutritionGoal 默认值 ✅ 2026-06-25
- [x] `Extensions.swift`：AppTypography + HapticEngine 等 ✅ 2026-06-25

### Tab 1 — 今日（Dashboard）

- [x] 日期导航（左右箭头，今天右侧禁用，点击标题弹日历）✅ 2026-06-25
- [x] 英雄卡（热量进度环 + 大数字 + 三大宏量素进度条）✅ 2026-06-25
- [x] 均衡模式：进度环不变红 ✅ 2026-06-25
- [x] 营养素详细列表（默认折叠，点击展开）✅ 2026-06-25
- [x] 三餐摘要条（紧凑一行热量数字）✅ 2026-06-25
- [x] 饮水进度卡（+1杯 + 撤销SnackBar）✅ 2026-06-25
- [x] 习惯完成度卡 ✅ 2026-06-25
- [x] 最新日志摘要 ✅ 2026-06-25
- [x] 空状态引导 ✅ 2026-06-25

### Tab 2 — 饮食（Food Timeline）

- [x] 日期导航（与首页联动 selectedDate）✅ 2026-06-25
- [x] 餐食卡片（餐次标签 + 时间 + 总热量 + 照片）✅ 2026-06-25
- [x] 手动添加食物（搜索 UserFood → 最近记录 → 手动输入）✅ 2026-06-25
- [x] 我的食物（UserFood CRUD）✅ 2026-06-25
- [x] 餐食模板（保存/使用）✅ 2026-06-25
- [x] 手动添加餐食（选餐次 → 空Meal）✅ 2026-06-25
- [x] 编辑/删除（滑动操作）✅ 2026-06-25
- [x] 搜索与筛选 ✅ 2026-06-25
- [x] 每日营养汇总底栏 ✅ 2026-06-25
- [x] 空状态 ✅ 2026-06-25

### Tab 3 — AI

- [x] 气泡对话 UI（对齐 1Cash）✅ 2026-06-25
- [x] 聊天历史持久化 ✅ 2026-06-25
- [x] 拍照识别入口（PhotosPicker 相机按钮）✅ 2026-06-25
- [x] 相机权限 ✅ 2026-06-25
- [x] AI 拍照加载态 ✅ 2026-06-25
- [x] AI 拍照超时（45 秒）✅ 2026-06-25
- [x] AI 结构化意图（10 种）✅ 2026-06-25
- [x] AI 餐食确认卡片（可编辑 + 确认/取消）✅ 2026-06-25
- [x] 多餐确认卡片 ✅ 2026-06-25
- [x] 悬空引用处理 ✅ 2026-06-25
- [x] AI 初始空状态（4 张功能卡片）✅ 2026-06-25
- [x] 快捷建议 Chips ✅ 2026-06-25
- [x] AI 上下文注入 ✅ 2026-06-25
- [x] AI 未配置状态 ✅ 2026-06-25
- [x] 语音输入 ✅ 2026-06-25
- [x] 8 服务商 + AIVisionClient（Claude/OpenAI/Kimi/Qwen/Doubao/腾讯混元/小米 MiMo 的视觉模型支持图片识别；DeepSeek 不作为图片识别入口）✅ 2026-06-26
- [x] LocalAIIntentParser ✅ 2026-06-25

### Tab 4 — 我的（My Life）

- [x] 上下分区布局（习惯网格 + 日志时间线）✅ 2026-06-26
- [x] 习惯列表（布尔型勾选 + 数量型+1 + Streak + 归档）✅ 2026-06-26
- [x] 新增习惯（名称/图标/颜色/频率类型+次数/目标/提醒）✅ 2026-06-26
- [x] 习惯详情（热力图 + Streak + 完成率 + 编辑/归档/删除）✅ 2026-06-26
- [x] Streak 计算（每天型：连续天数 / 每周型：连续自然周数）✅ 2026-06-26
- [x] 日志列表（按天分组 + 搜索 + 心情/活动标签筛选 + 多照片缩略图）✅ 2026-06-26
- [x] 写日志（心情 + 活动标签(固定13种) + 正文 + 多照片最多9张）✅ 2026-06-26
- [x] 日志详情（编辑/删除）✅ 2026-06-26
- [x] 空状态 ✅ 2026-06-26

### Tab 5 — 设置

- [x] 个人资料（UserAvatarView + 昵称）✅ 2026-06-26
- [x] 身体参数（性别/年龄/身高/体重/活动水平 → 重新推荐营养目标）✅ 2026-06-26
- [x] Apple Health 动态 TDEE（授权、读取、状态展示）✅ 2026-06-26
- [x] 营养目标（热量 + 多营养素 + 饮食目标模式）✅ 2026-06-26
- [x] 饮水设置（每日目标 / 一杯量 / 一瓶量）✅ 2026-06-26
- [x] 我的食物库管理 ✅ 2026-06-26
- [x] 餐食模板管理 ✅ 2026-06-26
- [x] 提醒设置（三餐时间开关）✅ 2026-06-26
- [x] AI 配置（对齐 1Cash + Vision 能力状态）✅ 2026-06-26
- [x] 数据（CSV 两种粒度 / JSON 备份 / 导入 / 清空）✅ 2026-06-26
- [x] 外观（跟随系统/浅色/深色）✅ 2026-06-26
- [x] 关于（隐私 / 用户手册 / 反馈 / 版本）✅ 2026-06-26

### Onboarding

- [x] 欢迎页（Logo + 三个价值点）✅ 2026-06-26
- [x] 语言选择 ✅ 2026-06-26
- [x] 个人资料（PhotosPicker + 昵称）✅ 2026-06-26
- [x] 身体参数（可跳过，用于 BMR 计算）✅ 2026-06-26
- [x] 饮食目标（减脂/增肌/维持/均衡，个性化推荐）✅ 2026-06-26
- [x] 每日热量目标（TDEE 计算推荐值）✅ 2026-06-26
- [x] 提醒节奏（三餐时间）✅ 2026-06-26
- [x] AI 配置（可跳过，API Key 写入 Keychain）✅ 2026-06-26
- [x] 设置完成 ✅ 2026-06-25
- [x] 进度指示器 + 返回上一步 ✅ 2026-06-25

### 通知

- [x] 三餐提醒 ✅ 2026-06-25
- [x] 习惯提醒 ✅ 2026-06-25
- [x] 深链接处理 ✅ 2026-06-25

### 用户食物与模板库

- [x] 我的食物：用户手动创建或从记录收藏 ✅ 2026-06-25
- [x] 模板库：用户创建餐食/饮品模板，支持复用与导入导出 ✅ 2026-06-26
- [x] 饮品知识库：由用户通过插件识别、校对后入库 ✅ 2026-06-26
- [x] 空 App 不预置家常菜、品牌食品或官方饮品记录 ✅ 2026-07-02
- [x] 餐食营养识别插件：拍照/文字识别，校对后写入已有的餐食库（UserFood）✅ 2026-07-13
- [x] 补剂知识库：由用户通过补剂营养识别插件识别、校对后入库，AI 记录补剂时按份数自动引用 ✅ 2026-07-13

### 测试

- [x] AI 意图解析测试 ✅ 2026-06-25
- [ ] 营养计算测试（BMR/份量换算/nil处理）
- [ ] 数据持久化测试（CRUD/级联删除/悬空引用）
- [ ] 用户食物/模板/饮品知识库测试
- [ ] UserFood 测试
- [ ] MealTemplate 测试
- [ ] WaterLog 测试
- [ ] Habit Streak 测试（每天型/每周型）
- [ ] 导出测试（CSV/JSON）
- [ ] 图片处理测试

---

## Coming Soon

- [x] **营养趋势报告**：blur 预览 ✅ 2026-06-25
- [x] **运动健身报告**：动态 TDEE / 活动消耗 / 训练习惯联合分析预留 ✅ 2026-06-26
- [x] **AI 深度营养分析**：基础文字回复 ✅ 2026-06-25
- [x] **iCloud 同步**：禁用 + 「即将推出」✅ 2026-06-25
- [x] **习惯深度洞察**：热力图 ✅ 2026-06-25

---

## 1.1 — 运动健康基础闭环

> 本节只列当前 App 尚未实现的运动健康健身功能；已实现的身体参数、动态 TDEE、Apple Health 活动/静息热量读取、饮食目标、运动习惯打卡和日志标签不重复列入。

| # | 优先级 | 功能 | 说明 |
|---:|:---:|---|---|
| 1 | P0 ✅ | WorkoutLog 训练记录模型 | 新增独立训练数据，不再只依赖习惯或日志标签表达运动。✅ 2026-06-26 |
| 2 | P0 ✅ | WorkoutType 训练类型体系 | 支持力量、跑步、骑行、游泳、步行、瑜伽、HIIT、球类等分类。✅ 2026-06-26 |
| 3 | P0 ✅ | 手动新增训练 | 记录类型、开始时间、时长、强度、消耗热量、备注。✅ 2026-06-26 |
| 4 | P0 ✅ | 训练编辑与删除 | 支持修正历史训练数据。✅ 2026-06-26 |
| 5 | P0 ✅ | 训练详情页 | 展示单次训练的时长、强度、热量和营养关联。✅ 2026-06-26 |
| 6 | P0 ✅ | 训练时间线 | 按日期展示训练历史，和饮食时间线分离。✅ 2026-06-26 |
| 7 | P0 ✅ | 训练日历 | 以月视图展示训练日、休息日和连续性。✅ 2026-06-26 |
| 8 | P0 ✅ | Apple Health 训练导入 | 读取已完成 workout 记录，不只读取能量摘要。✅ 2026-06-26 |
| 9 | P0 ✅ | 每日步数卡片 | 在首页展示步数趋势和目标差距。✅ 2026-06-26 |
| 10 | P0 ✅ | 每日活动分钟 | 汇总当天主动运动分钟数。✅ 2026-06-26 |
| 11 | P0 ✅ | 每日训练时长 | 汇总手动和 HealthKit 导入训练的总时长。✅ 2026-06-26 |
| 12 | P0 ✅ | 训练消耗热量汇总 | 区分训练消耗和普通活动消耗。✅ 2026-06-26 |
| 13 | P0 ✅ | 摄入 vs 消耗主卡 | 把饮食摄入、TDEE、活动消耗放在同一个判断面板。✅ 2026-06-26 |
| 14 | P0 ✅ | 热量缺口/盈余仪表 | 显示今日处于减脂缺口、维持区间还是增肌盈余。✅ 2026-06-26 |
| 15 | P0 ✅ | 自动训练日识别 | 根据训练记录标记训练日。✅ 2026-06-26 |
| 16 | P0 ✅ | 手动休息日标记 | 用户可明确标记恢复日，避免被连续性误判。✅ 2026-06-26 |
| 17 | P0 ✅ | 训练日宏量目标调整 | 训练日自动提高蛋白质或碳水建议。✅ 2026-06-26 |
| 18 | P0 ✅ | 休息日宏量目标调整 | 休息日给出更稳的热量和碳水建议。✅ 2026-06-26 |
| 19 | P0 ✅ | 训练后蛋白缺口 | 结合当日摄入判断训练后蛋白是否不足。✅ 2026-06-26 |
| 20 | P0 ✅ | 训练后碳水建议 | 根据训练类型和强度提示补碳范围。✅ 2026-06-26 |
| 21 | P1 ✅ | 训练前进食时间建议 | 根据训练开始时间提醒是否需要提前补能。✅ 2026-06-26 |
| 22 | P1 ✅ | 训练饮水建议 | 根据时长、强度和饮水记录调整饮水目标。✅ 2026-06-26 |
| 23 | P1 ✅ | 每周训练次数目标 | 用户可设置每周训练次数。✅ 2026-06-26 |
| 24 | P1 ✅ | 每周训练时长目标 | 用户可设置每周训练分钟数。✅ 2026-06-26 |
| 25 | P1 ✅ | 训练目标提醒 | 接近周末但目标未完成时提醒。✅ 2026-06-26 |
| 26 | P1 ✅ | 休息日提醒 | 连续训练后提示安排恢复。✅ 2026-06-26 |
| 27 | P1 ✅ | 训练连续天数 | 独立于习惯 Streak 的训练连续性。✅ 2026-06-26 |
| 28 | P1 ✅ | 训练稳定度评分 | 统计一周或一月内训练频率稳定性。✅ 2026-06-26 |
| 29 | P1 ✅ | 周运动摘要 | 汇总次数、时长、消耗和达标情况。✅ 2026-06-26 |
| 30 | P1 ✅ | 摄入消耗周报 | 每周复盘热量缺口/盈余和训练完成度。✅ 2026-06-26 |
| 31 | P1 ✅ | AI 记录训练意图 | 用户可自然语言新增训练记录。✅ 2026-06-26 |
| 32 | P1 ✅ | AI 查询训练摘要 | 用户可问本周练了几次、练了多久。✅ 2026-06-26 |
| 33 | P1 ✅ | AI 摄入消耗分析 | 结合饮食和训练解释今天能量状态。✅ 2026-06-26 |
| 34 | P1 ✅ | AI 训练后营养建议 | 结合训练类型、时间和当日摄入给建议。✅ 2026-06-26 |
| 35 | P2 ✅ | 训练数据导出 | 独立导出训练明细 CSV；完整 JSON 备份包含训练记录。✅ 2026-07-14 |

## 1.2 — 训练细节、身体指标与报告

> 现状：1.2 仍是下一阶段功能，不把当前已有的基础 WorkoutLog/BodyMeasurement 字段误计为力量训练细节。建议按“数据模型 → 记录编辑 → 趋势报告”三个垂直切片推进，避免一次性改动基础模型造成备份与迁移风险。

### 建议落地顺序

1. **力量训练切片**：动作库与自定义动作 → 单次训练的动作/组记录 → 训练模板 → PR 与肌群统计。
2. **身体指标切片**：扩展 BodyMeasurement 的围度字段 → 编辑与历史列表 → 体重/体脂/围度趋势图。
3. **报告切片**：月度汇总服务 → PDF/JSON/CSV 导出 → Dashboard 入口与空状态。

每个切片都必须同时补：SwiftData 迁移策略、导入导出字段、删除级联规则、静态解析和运行时验证清单。

| # | 优先级 | 功能 | 说明 |
|---:|:---:|---|---|
| 36 | P0 | 动作库 | 内置常见力量训练动作。 |
| 37 | P0 | 自定义动作 | 用户可创建自己的训练动作。 |
| 38 | P0 | 力量训练构建器 | 按动作组织一次力量训练。 |
| 39 | P0 | 组数/次数/重量记录 | 支持每组 set、rep、weight。 |
| 40 | P0 | 组间休息计时器 | 训练中快速计时。 |
| 41 | P0 | 训练模板 | 保存常用训练计划。 |
| 42 | P0 | 模板排期 | 将训练模板安排到未来日期。 |
| 43 | P0 | 肌群训练量统计 | 按胸、背、腿、肩、手臂、核心等汇总。 |
| 44 | P0 | 肌群分类体系 | 每个动作绑定主要/辅助肌群。 |
| 45 | P0 | 个人纪录识别 | 自动发现重量、次数、总量 PR。 |
| 46 | P1 | 个人纪录历史 | 查看 PR 时间线和突破次数。 |
| 47 | P1 | 有氧距离记录 | 跑步、骑行、步行等记录距离。 |
| 48 | P1 | 有氧配速记录 | 自动计算平均配速。 |
| 49 | P1 | 有氧分段数据 | 支持公里或英里分段表现。 |
| 50 | P1 | 有氧平均心率字段 | 先支持手动记录，为后续 HealthKit 心率导入铺路。 |
| 51 | P1 | RPE 主观强度 | 记录 1-10 分训练强度。 |
| 52 | P1 | 疲劳评分 | 训练后记录疲劳程度。 |
| 53 | P1 | 酸痛部位记录 | 记录 DOMS 和不适部位。 |
| 54 | P1 | 恢复备注 | 为训练和睡眠状态补充恢复说明。 |
| 55 | P0 | 体重历史模型 | 当前只有设置里的体重，需要可追踪的历史记录。 |
| 56 | P0 | 体脂率记录 | 支持手动录入体脂率。 |
| 57 | P1 | 腰围记录 | 支持减脂用户追踪围度。 |
| 58 | P1 | 胸围记录 | 支持体型变化追踪。 |
| 59 | P1 | 臂围记录 | 支持增肌用户追踪围度。 |
| 60 | P1 | 臀围记录 | 支持体态和体型追踪。 |
| 61 | P1 | 腿围记录 | 支持下肢训练变化追踪。 |
| 62 | P0 | 身体指标趋势图 | 体重、体脂和围度可视化。 |
| 63 | P1 | 目标体重预测 | 根据近期趋势估算达成日期。 |
| 64 | P1 | 减脂/增肌进度评估 | 结合体重、热量缺口和训练频率判断进展。 |
| 65 | P0 | 月度营养健身报告 | 汇总饮食、训练、体重和达标情况。 |
| 66 | P1 | 蛋白质达标趋势 | 统计训练日和非训练日蛋白完成率。 |
| 67 | P1 | 训练达标趋势 | 按周/月统计训练目标完成率。 |
| 68 | P1 | 结构化睡眠记录 | 从日志标签升级为可统计的睡眠时长记录。 |
| 69 | P1 | 睡眠质量评分 | 手动记录睡眠质量。 |
| 70 | P1 | 压力评分 | 手动记录压力，和饮食/训练报告联动。 |

## 1.3 — 高级健康分析与系统能力

> 现状：1.3 暂无完整实现。本阶段依赖 HealthKit 授权边界和系统扩展 target，不能仅靠现有主 App 页面补齐；先完成 HealthKit 读取服务与隐私设置，再分别建设 Watch、Shortcuts/ Siri、Widget 和 iCloud target。

### 建议落地顺序

1. **HealthKit 只读切片**：睡眠、心率、HRV、静息心率的授权/读取/缓存/失败反馈。
2. **分析切片**：恢复与训练负荷的纯计算服务，先用明确的“估算”标签，避免医疗结论。
3. **系统能力切片**：App Intents/Shortcuts → WidgetKit → Watch target → CloudKit 同步。

在用户确认每个 target 和数据权限范围前，不直接新增系统扩展或开启 iCloud 容器。

| # | 优先级 | 功能 | 说明 |
|---:|:---:|---|---|
| 71 | P0 | Apple Health 睡眠导入 | 读取睡眠时长和睡眠阶段。 |
| 72 | P0 | Apple Health 心率导入 | 读取训练和全天心率数据。 |
| 73 | P0 | 静息心率趋势 | 追踪恢复和疲劳状态。 |
| 74 | P0 | HRV 导入 | 读取心率变异性数据。 |
| 75 | P0 | HRV 趋势 | 观察长期恢复变化。 |
| 76 | P0 | 心率区间 | 按用户年龄和静息心率估算区间。 |
| 77 | P1 | Zone 2 分钟数 | 统计低强度有氧有效时长。 |
| 78 | P1 | 训练负荷评分 | 结合时长、强度、心率和 RPE 估算负荷。 |
| 79 | P1 | 恢复评分 | 综合睡眠、HRV、静息心率、疲劳和酸痛。 |
| 80 | P1 | 过度训练风险提示 | 长期高负荷低恢复时提示降强度。 |
| 81 | P1 | Deload 建议 | 根据训练负荷和恢复状态建议减量周。 |
| 82 | P1 | 营养周期化 | 根据训练日、休息日和目标周期调整营养建议。 |
| 83 | P1 | 长期目标计划 | 支持减脂、增肌、维持、赛事或体态目标拆解。 |
| 84 | P1 | Apple Watch 快速记录 | Watch 端快速记录训练、饮水和体重。 |
| 85 | P2 | Apple Watch 表盘组件 | 展示今日热量差、蛋白缺口和训练状态。 |
| 86 | P1 | Siri 记录训练 | 通过语音添加训练记录。 |
| 87 | P1 | App Shortcuts 健身摘要 | 快捷指令查询今日和本周训练健康摘要。 |
| 88 | P1 | 桌面健身小组件 | 展示摄入消耗差、训练目标和蛋白达标。 |
| 89 | P2 | 锁屏健康小组件 | 展示今日运动和恢复状态。 |
| 90 | P1 | 每周健康报告推送 | 每周自动生成营养和训练摘要通知。 |
| 91 | P1 | 蛋白缺口智能提醒 | 训练日蛋白明显不足时提醒。 |
| 92 | P1 | 恢复/饮水智能提醒 | 结合训练负荷和饮水状态提醒。 |
| 93 | P0 | 健康训练数据 iCloud 同步 | 同步训练记录、身体指标和健康设置。 |
| 94 | P0 | 健康数据隐私导出控制 | 用户可单独选择训练、身体指标、HealthKit 摘要是否导出。 |
| 95 | P1 | 训练 CSV 导入 | 支持从其他工具迁移训练历史。 |
| 96 | P1 | 身体指标 CSV 导入 | 支持导入体重、体脂和围度历史。 |
| 97 | P0 | 训练健康数据迁移 | JSON 备份版本升级，兼容新增模型。 |
| 98 | P1 | 健康图表无障碍 | VoiceOver 和 Dynamic Type 适配所有趋势图。 |
| 99 | P1 | 公制/英制单位 | 支持 kg/lb、cm/in、km/mi 切换。 |
| 100 | P1 | AI 长期目标预测 | 根据饮食、训练、体重和恢复趋势预测目标进度。 |

---

## 不在规划中

- 社交功能（分享饮食、好友排行）
- 食谱推荐
- 与健康硬件连接（体重秤、手环）
- 卡路里扫描仪（实时 AR）

---

## 设计说明

- 进度环颜色：主色正常 / 橙色接近目标 / 红色超标。均衡模式全程主色
- 营养素三色：蛋白质蓝 / 碳水橙 / 脂肪黄，全 App 统一
- 触感反馈：tap（切换/选择/打卡）/ success（记录成功/目标达成）/ warning（删除/清空）
- 成功动画：绿色成功覆层 0.8s（对齐 1Cash）
- 中式菜肴：UI 显示 `≈` 前缀，底部提示估算说明

---

*此文件用于记录功能状态和后续规划；每次功能更新后同步维护。*
