# 1Life 结构文档 02：Tab 1 · 今日（Dashboard）

> 系列文档共 6 篇，本篇是第 2 篇。方法论、置信度标注规则见 [01_启动与Onboarding.md](01_启动与Onboarding.md) 开头「0. 文档说明」，本篇不再重复。

## 0. 涉及文件

```text
1Life/Views/Dashboard/DashboardView.swift   Tab 1 唯一的界面文件，1021 行，本篇 95% 内容来自这一个文件
1Life/ViewModels/AppViewModel.swift          跨 Tab 共享状态（selectedTab/selectedDate/导航焦点），本篇引用一次，后续几篇不再重复解释
1Life/Views/MyLife/MyLifeView.swift          BowelLogEditorSheet（排便记录编辑弹窗）定义在这个文件里，被 Dashboard 调用——是本篇唯一一处「界面定义在别的 Tab 文件里，但入口在 Dashboard」的情况
1Life/Services/Food/NutritionService.swift   dailySummary/mealSummaries 静态计算方法
1Life/Services/Workout/WorkoutService.swift  dailySummary/adjustedProteinTarget/adjustedCarbsTarget
1Life/Services/Health/HealthKitService.swift energySummary/activitySummary/sleepHours/daylightMinutes
1Life/Models/NutrientDefinitions.swift        NutrientGroup/NutrientKey 枚举，营养素展开面板的数据源
1Life/Models/AppSettings.swift                effectiveTarget/spotlightNutrientKeys 等目标计算逻辑
```

**重要架构前提**：Dashboard 不是一个孤立页面。它读取的 `selectedDate` 来自 `@Environment(AppViewModel.self)` 里的 `appViewModel.selectedDate`——这个状态挂在 `ContentView.mainTabView` 层级，被**所有 5 个 Tab 共享**。也就是说，在 Dashboard 把日期切到「昨天」，切去饮食 Tab 时如果那边也读同一个 `selectedDate`，看到的也会是「昨天」的数据（03 篇会验证饮食 Tab 是否真的读了同一个状态）。这与常见的「每个 Tab 各自独立维护日期」的设计不同，是 1Life 的一个全局性架构决策，不是 Dashboard 独有的行为。

---

## 1. 入口与整体结构

- **入口**：App 启动默认选中的 Tab（`AppViewModel.selectedTab` 初始值是 `.dashboard`），底部 TabBar 图标 `chart.bar.fill`，文字「今日」。
- **导航标题**：动态文字——`selectedDate.isToday` 为真显示「今日」，是「昨天」的特殊文案，其余显示具体日期（`dayDisplay` 格式化）。`.navigationBarTitleDisplayMode(.inline)`。
- **整体布局**：`NavigationStack` → `ScrollView` → `LazyVStack(alignment: .leading, spacing: 16)`，从上到下固定 8 个 `SystemPanel` 卡片，**没有任何条件性隐藏面板**（不管数据是否为空，8 个面板全部渲染，用空状态文案而非隐藏面板本身来处理无数据情况）：

```text
1. dateSelectorPanel   日期选择
2. heroCard            今日摄入（大数字+环形进度+宏量营养素网格）
3. mealStatusPanel     餐食快照（4 个餐次格子）
4. nutritionDetailsSection  营养素（可展开/收起）
5. healthMetricsRow    健康指标（步数/睡眠/训练/日照）
6. waterCard           饮水
7. bowelCard           排便
8. quickStatusRow      生活记录（习惯/训练/日记摘要）
```

- **生命周期钩子**（这些决定了页面数据什么时候刷新，是本篇容易被忽略但很关键的一块）：
  - `.task(id: selectedDate)`：`selectedDate` 每次变化（用户翻页或选日期），重新触发 `refreshHealthData()`——这是 SwiftUI `task(id:)` 的标准用法，日期一变就取消旧任务、发起新任务。
  - `.onChange(of: scenePhase)`：App 从后台回到前台（`.active`）时也会重新 `refreshHealthData()`——覆盖「用户切到 Apple 健康 App 记了步数再切回来」这种场景。
  - `.onReceive(NotificationCenter...healthEnergyDidUpdate)`：监听一个自定义通知（`Notification.Name.healthEnergyDidUpdate`），这是 `HealthKitService` 的后台能量数据交付（`OneLifeApp.swift` 里 App 启动时注册的 `enableEnergyBackgroundDelivery()`）触发的，收到后同样刷新——这是让「用户运动后即使没主动打开 App，TDEE 数据也能在下次打开时自动更新」的机制。

---

## 2. 逐面板详解

### 2.1 日期选择（`dateSelectorPanel`）

`SystemPanel(title: "日期选择")` 内嵌一个 `DaySelectorView`（定义在 `ContentView.swift`，01 篇已介绍过其结构，此处是它在真实业务页面里的唯一复用点之一）。

- 左箭头：`Calendar.current.date(byAdding: .day, value: -1)`，无下限限制，可以一直往前翻
- 中间日期文字：点击弹出 340pt 高的 `.sheet`，系统 `DatePicker(.graphical)` 直接选日期，选择范围 `in: ...Date.now`（**不能选未来日期**）
- 右箭头：往后翻一天，`selectedDate.isToday` 时这个按钮 `disabled`（图标变浅灰色）——**不能翻到未来**
- 绑定的是 `appViewModel.selectedDate`（通过 `selectedDateBinding` 计算属性包了一层 `min($0, Date.now)` 兜底，双重保险防止选到未来）

### 2.2 今日摄入（`heroCard`）—— 全页视觉权重最高的卡片

标题动态：`"\(selectedDateScopeLabel)摄入"`（今日摄入 / 当日摄入），detail 是「\(日期)摄入、目标差值与宏量营养执行情况」。

**左侧数据块**：
- Eyebrow「总摄入」（11pt tracking 1.2）
- 42pt black 大数字（当日总热量，`Int` 取整）+「kcal」小字
- 徽标行：始终显示「剩余 X」（accent 色）或「超出 X」（danger 色，负数时）；如果开启了 HealthKit 动态 TDEE 且当天有健康数据，额外加一个「动态」中性徽标；如果饮食目标模式是「均衡」（`isBalancedMode`），额外加一个「参考」中性徽标——**这两个附加徽标可以同时出现，也可以都不出现**，取决于用户的目标模式和 HealthKit 授权状态

**右侧环形进度**：124×124 的圆环，`trim(from: 0, to: min(progress, 1.5))`——注意这里允许进度条画到 150%（超出目标时圆环会画一圈半），不是简单地卡在 100%。颜色规则（`progressColor`）：均衡模式恒定 accent 色；非均衡模式下 progress>1.0 是 danger 红色，progress>0.8 是 warning 橙色，其余 accent 色——**这是全页唯一一处用「距离目标的百分比」驱动颜色分级警示的地方**。圆环中心显示百分比数字+目标类型文字（「参考目标」或「当日目标」）。

**中间统计条**（`MetricStrip` ×3，`SystemPanelDivider` 上下分隔）：目标热量数值、当日已记录餐次数（`mealSummaries` 里 `totalCalories > 0` 的条数）、当日饮水总量。

**底部宏量营养素网格**（`spotlightNutrientGrid`）：2 列 `LazyVGrid`，默认显示蛋白/碳水/脂肪/膳食纤维/钠 5 项（`currentSettings?.spotlightNutrientKeys`，可在设置里自定义——见 06 篇），每项是一个 `MacroProgressBar`：名称+「当前/目标+单位」文字+进度条+「执行中」或「超出目标」（danger 色）状态文字。当某营养素完全没有数据时（`current == nil`），进度条画 0 且文字显示纯「—」。

**目标值计算的特殊规则**（不是 UI 层面直接读一个固定值，值得单独说明）：
- 蛋白质目标：如果当天是训练日（`workoutSummary.isTrainingDay`）或休息日（`isRestDay`），走 `WorkoutService.adjustedProteinTarget` 做训练相关调整；如果当天完成了名字包含"运动/跑步/健身/训练/拉伸"关键词的习惯打卡（`hasCompletedExerciseHabit`），基础值 ×1.10；否则用基础目标值原样
- 碳水目标：恒定走 `WorkoutService.adjustedCarbsTarget`（依据当天训练情况调整）
- 热量/脂肪目标：直接来自 `currentSettings.effectiveTarget(healthTDEE:goal:)`，这个方法本身会在「HealthKit 动态 TDEE」和「手动设置的 NutritionGoal」之间做选择——**Dashboard 本身不做这个决策，只是调用现成的计算方法**

### 2.3 餐食快照（`mealStatusPanel`）

2×2 网格（`LazyVGrid`），对应 `MealType.allCases`（4 个类型，具体是哪 4 个由 03 篇饮食 Tab 详细展开，这里只说明 Dashboard 侧的呈现）。每个格子：
- 图标+类型名+右侧徽标（已记录=success 绿色 / 可补记=neutral 灰色）
- 主文字：已记录显示该餐次热量（accent 色 18pt bold），未记录显示「点按补记」（次要色）
- **点击整个格子**：已记录 → `appViewModel.navigateToExistingMeal(type)`（设置 `foodScrollMealType`，跳到饮食 Tab 后会自动滚动到该餐次位置）；未记录 → `appViewModel.navigateToFood(mealType: type)`（设置 `foodFocusMealType`，跳到饮食 Tab 后会直接进入该餐次的补记语境）——**这是两条不同的深链接参数，行为不同，03 篇会看到饮食 Tab 侧具体怎么响应这两个不同的 `AppViewModel` 字段**

### 2.4 营养素（`nutritionDetailsSection`）

一个可展开/收起的面板：顶部始终是一行「查看全部营养素 / 收起营养素明细」按钮（chevron 图标带 180° 旋转动画，`.easeInOut(duration: 0.25)`），展开后（仅当 `currentGoal != nil` 时才会真正展示内容，`showNutritionDetails` 为真但没有营养目标数据时点了也不会出现任何东西——这是一个潜在的可感知性问题：按钮文字变成「收起」但下方空空如也）显示 `NutrientDefinitions.dashboardGroups` 定义的分组网格，每组（宏量营养素/常规指标/矿物质/维生素 4 大类）内部 2 列展示每个营养素的「当前/目标 + 单位」和百分比进度条（颜色规则：>100% 红色，>80% 绿色，其余蓝色——**这组颜色规则和 2.2 节 `heroCard` 的颜色规则不是同一套**，`heroCard` 用的是 `FamilyUI.danger`/`FamilyUI.warning`/`FamilyUI.accent`，这里用的是裸色 `.red`/`.green`/`.blue`，是两套独立实现，不是共享同一个颜色计算函数）。

### 2.5 健康指标（`healthMetricsRow`）

顶部一行 4 个等宽 `HealthMetricItem`（步数/睡眠/训练/日照，各自图标+标签+数值，无数据显示「—」灰色），下方一个「点击从 Apple Health 同步」按钮行：
- 未授权 HealthKit 时该行整体 `disabled`，右侧显示「未授权」徽标
- 已授权且有 TDEE 数据时，右侧显示「TDEE X kcal」徽标
- 点击后触发 `refreshHealthData()`，按钮内容切换成 loading 态（`ProgressView().controlSize(.mini)` + 「读取中…」文字），`isRefreshingHealth` 为真时按钮本身也 disabled，防止重复点击

### 2.6 饮水（`waterCard`）

- 左侧：大号（28pt black）当前/目标数值（超过 1000ml 自动换算成升显示，`waterProgressText`），下方文字「已达到饮水目标」或「还差 X ml」
- 右侧：黑色胶囊按钮「+ 记录饮水」，是一个 `Menu`（不是普通 Button），点击弹出 9 个预设水量选项（50/100/150/200/250/300/500/750/1000 ml），选中即调用 `addWater(amount:)`
- 底部：`ProgressView` 蓝绿色（`.cyan`）进度条，`min(progress, 1.0)` 封顶不会画超

**`addWater` 的撤销机制**（是本页面唯一带「撤销」交互的地方）：点击记录后立即插入一条 `WaterLog`，同时在页面底部（`.overlay(alignment: .bottom)`，覆盖在整个 ScrollView 上方，从底部滑入+淡入 `.transition(.move(edge: .bottom).combined(with: .opacity))`）弹出一条黑色半透明撤销条「已追加 X ml · 撤销」，**3 秒后自动消失**（`Task.sleep(3_000_000_000)` 纳秒级睡眠实现，用 `Task` 存到 `waterUndoTask` 以便新记录进来时能 `cancel()` 掉上一个未过期的撤销任务，避免连续加水时撤销条互相打架）。点「撤销」调用 `undoLastWaterLog()`：`HapticEngine.warning()` + 删除该条记录。

**记录时间的隐藏逻辑**（`waterLogDate()`）：如果 `selectedDate` 是今天，直接用 `.now`（精确到当前时刻）；如果是在补记过去某天，用「当前的时:分」拼到「被选中的那一天」上——即补记过去日期的饮水，时间戳不是那天的 00:00，而是「如果现在的钟点发生在那一天」的模拟时间。排便记录的 `bowelLogDate()` 逻辑类似但补记过去日期时固定用中午 12:00，不是当前时:分——**这是两个相邻功能在「补记历史数据应该用什么时间戳」这个问题上给出了不同答案**，饮水用「现在几点就记几点」，排便用「统一中午」，不是同一套规则。

### 2.7 排便（`bowelCard`）

- 左侧：当天记录条数摘要 + 最近一条的 Bristol 分型（emoji+名称+具体时间），无记录时显示引导文案「可通过上方日期选择补记过去某一天」
- 右侧：黑色胶囊按钮「记录」（`plus` 图标），点击 `HapticEngine.tap()` + 打开 `isShowingBowelEditor` sheet
- 有记录时下方额外列出最多 4 条明细（emoji+分型名+备注+时间）
- Sheet 内容 `BowelLogEditorSheet` **定义在 `Views/MyLife/MyLifeView.swift` 里**（不是 Dashboard 自己的文件），通过 `initialDate: bowelLogDate()` 传入补记日期——这是本篇提到的唯一一处「界面组件跨 Tab 文件复用」的例子，其它面板涉及的弹窗/编辑器都定义在各自 Tab 自己的文件内

### 2.8 生活记录（`quickStatusRow`）—— 三个子区域的复合面板

顶部徽标行：习惯完成度（「无习惯」灰色 或 「X/Y 习惯」绿色）+ 有训练时的「已训练」accent 徽标。

**习惯区块**（仅 `activeHabits` 非空时渲染）：点击整块跳转 `openMyLife(.habits)`；内容是「每日习惯」标题+完成数，下方最多 8 个习惯图标横排小格子（完成态用该习惯自定义颜色`Color(hex: habit.colorHex)`填充，未完成态统一灰色 `systemGray4`/`systemGray6`），每个格子下方是习惯名前两个字。

**训练区块**（恒定渲染）：点击跳转 `openMyLife(.workouts)`；有训练时显示时长+消耗热量，是休息日显示蓝色「休息日」文字，否则显示「\(日期)还没有训练」灰色文字，右侧统一带 `chevron.right` 提示可点击。

**日记区块**（恒定渲染，但内容二选一）：有当天日记（`todayJournal`）时显示心情 emoji+内容摘要（限 2 行）+最多 3 个活动标签胶囊；没有日记时显示引导文案「记录\(日期)的状态和心情」。两种状态都点击跳转 `openMyLife(.journal)`。

`openMyLife(_:)` 统一逻辑：`HapticEngine.tap()` + `withAnimation(.snappy(duration: 0.28))` 同时设置 `appViewModel.myLifeFocus` 和切换 `appViewModel.selectedTab = .myLife`——即 Dashboard 到「回顾」Tab 的跳转是带着「聚焦哪个子模块」的语境一起过去的，05 篇会展开 `MyLifeView` 侧怎么响应 `myLifeFocus`。

---

## 3. 子组件清单

以下是 `DashboardView.swift` 文件内定义、仅供本文件内部使用的 `private struct`（不是家族共享组件，`SystemPanel`/`SystemPanelDivider`/`SystemStatusBadge` 才是共享组件，这里不重复介绍）：

| 组件 | 用途 |
|---|---|
| `HealthMetricItem` | 健康指标行的单个图标+标签+数值格子 |
| `MacroProgressBar` | 宏量营养素网格里的单个进度条（名称+数值+进度+状态文字） |
| `MetricStrip` | Hero Card 中间统计条的单个数值展示（自带三色 tone 枚举：neutral/accent/success） |
| `NutrientRow` | 营养素展开面板里单个营养素的进度行 |
| `NutrientGroupBlock` | 营养素展开面板里一个分组（标题+2列网格） |

---

## 4. 值得注意的实现特点

1. **`selectedDate` 是全局共享状态，不是 Dashboard 私有的**——已在文档开头强调，这里再次提醒：任何未来要改 Dashboard 日期逻辑的人，都要意识到改动可能影响其它 Tab。
2. **8 个面板恒定渲染，用空状态文案而非条件隐藏**——好处是页面结构稳定、用户对布局有稳定预期；代价是数据完全空白的新用户第一屏会看到 8 个卡片但大多数是「暂无/—」占位内容，没有「Dashboard 整体空状态」的引导设计。
3. **两套颜色分级规则并存**：Hero Card 用 `FamilyUI.danger/warning/accent` 语义色 token，营养素展开面板用裸色 `.red/.green/.blue`——不是共享同一份颜色计算逻辑，未来调色需要两处分别改。
4. **饮水记录带 3 秒撤销窗口，排便记录没有**——同属「快捷记录」类交互，两个面板在「记错了怎么办」这件事上提供的补救机制不对等。
5. **补记历史数据的时间戳规则不统一**：饮水用「现在的钟点」，排便固定用「中午 12 点」。
6. **跳转到其它 Tab 都带着语境（deep-link）一起过去**：无论是跳饮食 Tab（带 `foodFocusMealType`/`foodScrollMealType`）还是跳回顾 Tab（带 `myLifeFocus`），都不是简单的 `selectedTab = xxx`，而是先设置好「去了之后应该聚焦在哪」的状态。这是一个贯穿全 App 的导航模式，02-06 篇会反复看到它的踪影。

---

## 5. 可复制性 / 迁移建议

- **Hero Card 的「大数字+环形进度+统计条+网格」四段式结构**是一个通用的「今日核心指标」呈现模式，不含营养领域耦合的部分（大数字、环形进度、统计条）可以直接复制给其它 App 的首页——比如 1Track 可以用同样结构展示「本月订阅支出」，1Day 可以展示「今日任务完成度」。营养网格这一段是 1Life 专属，不建议照搬。
- **`quickStatusRow` 那种「多个子区域压缩进一个复合面板、每个子区域点击跳到对应 Tab 并带语境」的模式**值得作为家族级设计模式：与其给每个次要功能单独开一个入口卡片占屏幕空间，不如像这里一样压缩进一个面板的多个分区。
- **饮水记录的 3 秒撤销撤销条**（底部滑入+自动消失+可取消上一个未过期任务）是一个通用的「快捷操作后悔药」交互模式，建议纳入家族共享组件库，而不是每个 App 各自实现一遍——目前 1Life 内部这个模式也只在饮水这一处出现，排便记录都没有复用，本身就存在复用不足的问题。
- **`AppViewModel` 承载跨 Tab 状态 + 语境化深链接**这个架构在 01 篇也提到过，Dashboard 是这个机制最密集的调用方（3 处不同的跳转都带参数），建议其它 App 在设计跨 Tab 跳转时都参照这个「不只是切 Tab，还要带上下文」的思路。
