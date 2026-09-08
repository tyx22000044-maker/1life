# 1Life 结构文档 05：Tab 4 · 回顾（MyLife）

> 系列文档共 6 篇，本篇是第 5 篇。方法论见 [01_启动与Onboarding.md](01_启动与Onboarding.md) 开头。本篇是 5 个 Tab 里**内容密度最高**的一个——单个 `MyLifeView.swift` 就有 1713 行，加上习惯/日志/训练三个独立子模块共 4176 行，比 Dashboard（02）和饮食 Tab（03）加起来还多。

## 0. 涉及文件

```text
1Life/Views/MyLife/MyLifeView.swift           主容器 + 阶段回顾图表 + 身体数据卡 + 排便卡，1713 行（全 App 单文件行数最多）
1Life/Views/MyLife/HabitTrackerView.swift     习惯打卡面板 + 新建习惯 Sheet，395 行
1Life/Views/MyLife/HabitDetailView.swift      习惯详情页 + 编辑 Sheet，458 行
1Life/Views/MyLife/JournalListView.swift      状态日志面板（列表+搜索+筛选），238 行
1Life/Views/MyLife/JournalDetailView.swift    日志详情页，139 行
1Life/Views/MyLife/JournalEditorView.swift    日志编辑 Sheet + FlowLayout 自定义布局，389 行
1Life/Views/MyLife/WorkoutTimelineView.swift  训练面板 + 日历 + 详情/编辑，844 行
```

**这个 Tab 和其它 4 个 Tab 的本质区别**：Dashboard 是"今天"的快照，饮食 Tab 是"今天+历史"的记录流，AI Tab 是对话式状态机；回顾 Tab 是**唯一做跨天聚合分析**的界面——顶部「阶段回顾」面板会把周/月/季/年四种周期的饮食、训练、习惯、体重、排便数据聚合成图表，其余三个子面板（身体数据/排便/习惯/日志/训练）则是各自独立的小型 CRUD 模块，垂直堆叠在同一个滚动页面里，不是 Tab 内二级导航。

---

## 1. 入口与整体结构

- **入口**：底部 TabBar 第 4 位，图标随 `AppTab` 枚举定义（与其它 Tab 一致的写法，图标+文字「回顾」）。
- **导航标题**：固定「回顾」，`.inline` 模式。
- **整体布局**：`NavigationStack` → `ScrollViewReader` 包裹 `ScrollView` → 纵向 `VStack(spacing: 16)`，从上到下 7 个面板：

```text
1. MyLifeSummaryCard      顶部汇总卡（今日习惯/训练/状态一眼看）
2. ReviewSummaryPanel     阶段回顾（周/月/季/年切换 + 4 张图表）
3. BodyMetricsCard        身体数据（体重/体脂 + Apple Health 导入）
4. BowelTrackerCard       排便记录
5. HabitTrackerView       习惯打卡列表
6. JournalListView        状态日志列表
7. WorkoutTimelineView    训练记录 + 训练日历
```

**首次加载有一个人为延迟的"整理中"占位**：`isPreparingContent` 初始为 `true`，`.task` 里 `sleep(160ms)` 后才切到真实内容，期间显示 `MyLifeLoadingPanel`（转圈+"正在准备习惯、身体和阶段回顾"文案）。这个手法在 Dashboard（02篇）也出现过，是家族里"避免 SwiftData 首帧空数据闪烁"的通用技巧。

**跨 Tab 深链定位机制**：`AppViewModel.myLifeFocus`（`MyLifeFocus?` 枚举，三个 case：`habits`/`workouts`/`journal`）是这个 Tab 独有的滚动定位入口——Dashboard 的"今日习惯"卡片、训练摘要行、最新日志行分别调用 `openMyLife(.habits)` / `openMyLife(.workouts)` / `openMyLife(.journal)`，写入 `myLifeFocus` 并切换 `selectedTab` 到回顾 Tab；本页 `.onChange(of: appViewModel.myLifeFocus)` 监听到后，用 `DispatchQueue.main.asyncAfter(0.12s)` + `proxy.scrollTo(focus, anchor: .top)` 滚动到对应面板（`HabitTrackerView`/`JournalListView`/`WorkoutTimelineView` 各自用 `.id(MyLifeFocus.xxx)` 打了锚点），滚动完成后立即把 `myLifeFocus` 置回 `nil`——**这是一次性消费的信号，不是持久状态**，且专门处理了"内容还在 160ms 占位期"的时序问题（`isPreparingContent` 变化时再触发一次滚动检查，避免占位期间滚动目标还不存在）。身体数据卡和排便卡没有对应的 focus case，说明这套深链目前只覆盖 3 个子面板。

---

## 2. 逐面板详解

### 2.1 顶部汇总卡（`MyLifeSummaryCard`）

纯展示，无交互按钮。`SystemPanel` 内：
- `SystemStatusBadge("MY LIFE", tone: .accent)`
- 标题：根据数据动态选择文案（依优先级：无任何记录→"开始记录你的生活节奏"；今日有训练→"今天训练 X 分钟"；习惯全部完成→"今天的习惯完成得不错"；否则→"持续追踪习惯和状态"）
- 副标题：有最新日志则显示日期，否则固定说明文字
- 三个 `SummaryPill`横排：今日习惯（完成数/总数）、今日训练（分钟数或"未记录"）、状态记录（今日已记 or 历史条数）

### 2.2 阶段回顾（`ReviewSummaryPanel`）—— 全 App 图表密度最高的面板

顶部 `Picker(.segmented)` 四选一：周/月/季/年（`ReviewPeriod` 枚举）。切换周期时有一次 `preparePeriodChange()`（180ms 延迟+透明度动画）营造"正在整理"的过渡感，同时并行触发 `refreshHealthTDEE(for:)` 异步向 HealthKit 拉取该周期每天的动态 TDEE（仅当设置里开启了"HealthKit 动态 TDEE"时才请求，否则用 `settings.estimatedTDEE` 兜底常量）。

周期定义细节（`bucketRanges`）：
- 周：过去 7 天，每天一个桶
- 月：过去 30 天，每天一个桶
- 季：过去 13 周，每周一个桶（周从周日开始对齐）
- 年：过去 12 个月，每月一个桶

四张子图表，垂直堆叠在同一个 `ReviewInsightDashboard` 内：

1. **`ReviewOverviewStrip`**：2×2 网格 4 个指标块（记录覆盖率/日均热量/训练完成率/身体恢复），每块标题+大数值+一行细节说明
2. **`ReviewEnergyChart`**：自绘柱状图（`GeometryReader`+`Path`手工计算坐标，没有用 Swift Charts）——柱子是每个周期桶的日均摄入热量，颜色按"相对 TDEE 偏差"分三档（偏高 250kcal 以上=warning橙、±120kcal 内=success绿、其余=accent蓝），叠加一条 TDEE 折线（`Path`连线+每个点一个描边圆点）
3. **`ReviewRhythmHeatmap`**：网格热力图，每个格子是一个周期桶，格子底色深浅由"当天记录了几类数据"（饮食/习惯/训练/日志，0-4 分）决定，格子内还有 4 个小圆点分别代表这四类是否命中——**是"日历热力图"和"多维度小圆点"两种可视化叠加在同一个格子里**
4. **`ReviewRecoveryPanel`**：左侧体重迷你折线图（`ReviewWeightSparkline`，样本点少于 2 个时显示占位说明），右侧 4 个紧凑指标（体重变化/饮水/排便次数/Bristol正常占比），底部再叠加两行饮水趋势和排便趋势的小柱状图（`ReviewHydrationBowelTrendChart`）

**结论文案是规则引擎，不是 AI 生成**：`ReviewPeriodSnapshot.conclusion` 用一串 if-else 硬编码规则（无记录→提示补记；覆盖率≥70%且训练达标→夸奖；只有饮食没训练→提示；覆盖率<35%→提示断点多；否则给默认鼓励语），后续四篇文档都没有遇到类似的"结构化数据到自然语言结论"的本地规则生成器，这是回顾 Tab 独有的模式。

### 2.3 身体数据卡（`BodyMetricsCard`）

- 标题行：`SystemStatusBadge("身体数据")`（无记录时 tone 为 warning）+ 动态标题（"当前体重 X kg" / "当前体脂 X%" / "开始记录体重和体脂变化"）+ 最近记录日期或引导文案
- 右上角黑色圆角方形 **`+` 按钮**（34×34，`Image(systemName: "plus")`，与全 App 其它面板的新增按钮视觉规格完全一致）→ 弹出 `BodyMeasurementEditorSheet`
- 两个并排 `metricPill`（体重/体脂），体重块右上角额外叠一个 BMI 徽标（依赖 `settings.heightCm`，身高缺失则不显示）
- **「导入 Apple Health」按钮**（绿色文字+心形方框图标，胶囊底），点击调用 `HealthKitService.shared.latestBodyMeasurement()`：若当天已有一条 `.appleHealth` 来源的记录则原地更新数值，否则插入新记录；同时会**反向回写** `settings.weightKg`/`settings.heightCm`（身体数据卡的导入操作会顺带更新全局设置里的体重身高，这个联动在其它任何面板都没有出现过）
- 底部最多列出最近 5 条历史记录（日期+体重+体脂+来源标签）

`BodyMeasurementEditorSheet`：全屏 `NavigationStack` sheet，三个 `SystemPanel`（测量数据时间+体重体脂输入框、是否同步到 Apple Health 的 Toggle、备注输入）。保存逻辑：先本地插入并 `modelContext.save()`，若勾选了同步则再异步调用 `HealthKitService.saveBodyMeasurement`，**同步失败不回滚本地记录**，只弹出一条 warning 提示"本地已保存，写入 Apple Health 失败"——本地优先、远端尽力而为。

这是本篇（乃至全部 5 个 Tab）**第一次系统性使用 `GlobalBannerCenter` 做非 AI 场景的反馈**：导入成功/失败、保存成功/失败都调用 `bannerCenter.show(...)`，而不是像饮食 Tab 那样把错误内嵌成面板里的文字——04 篇提到 GlobalBannerCenter 目前只有 AI Tab 在稳定使用，回顾 Tab 的身体数据卡是第二个稳定使用者。

### 2.4 排便记录卡（`BowelTrackerCard`）

- 标题行：今日排便次数（或"今日暂无记录"）+ 最近一次的 Bristol 类型 emoji/名称/时间
- 右上角同款黑色 `+` 按钮 → `BowelLogEditorSheet`（这个 Sheet 是 `struct`，非 `private`，说明设计上预期被其它文件复用——实际上目前只有本卡片一处调用点）
- 若今日有记录，下方展开列表（emoji+类型名+备注+时间）

`BowelLogEditorSheet`：时间选择 + **7 种 Bristol 分型的可点击列表**（每行 emoji+名称+英文分级描述，选中项右侧打勾+背景变色，不是 Picker 而是自绘的可选列表）+ 备注输入框。`init` 支持传入 `initialDate`（默认 `.now`），但当前唯一调用点没有传自定义日期，属于预留但未使用的扩展点。

### 2.5 习惯打卡（`HabitTrackerView` + `HabitDetailView`）

**主面板**：`SystemStatusBadge("HABITS X/Y")` + 右上角黑色 `+` 按钮（`AddHabitSheet`）。空状态是一整块可点击的引导条（"追踪早睡、补剂、拉伸等每日行为"），点击同样弹新建 Sheet。非空时纵向列出每个 `HabitRow`。

**`HabitRow` 是 `NavigationLink`**（这是与 Dashboard/饮食 Tab 里大多数"行"用 Sheet 弹出编辑不同的地方——习惯行点进去是一个 push 到详情页，不是 Sheet）：图标方块（颜色取 `habit.colorHex`）+ 名称（完成时加删除线）+ 连续天数/周数 + **独立的圆形状态按钮**（点击本身不触发 NavigationLink 跳转，是同一行内的第二个可交互区域）。状态按钮三态循环：空圈→半填（`circle.lefthalf.filled`，写入 `value: 0.5` 的 `HabitLog`）→打勾实心圆（删除半态 log，写入 `value: 1`）→点击已完成态直接清空当天所有 log 回到空圈。**半完成态是这个 App 里唯一出现"三态开关"而非"二态开关"的交互**，其它所有勾选类交互（食物记录、AI 确认卡）都是简单的开/关或有/无。

**`AddHabitSheet`**：8 个预设习惯横向滚动卡片（早睡/运动/拉伸/补剂/控糖/称重/晒太阳/冥想，点击一键填充名称+图标+颜色+频率）+ 手动输入名称 + 10 个图标选择 + 8 个颜色选择（横向滚动，选中态描边加粗）+ 频率 `Picker(.segmented)`（每天/每周，每周模式下出现 `Stepper` 选次数）+ 提醒开关（开启后 `NotificationManager.shared.scheduleHabitReminder`）。**这个 Sheet 的 `SystemPageHeader` 文案是英文**（"CREATE HABIT" / "Track repeatable behaviors..."），而同一个文件里 `EditHabitSheet` 的等效位置也是英文，但页面内其它所有文案（编辑器分组标题如"PRESETS"/"HABIT INFO"/"FREQUENCY"/"REMINDER"）同样是英文大写——**这是全篇唯一一处编辑器内部标签整体使用英文而非中文的模块**，与 Dashboard/饮食 Tab 里`editorHeader`统一用中文形成反差，值得在替换到其它 App 时注意统一。

**`HabitDetailView`**：`SystemPageHeader` + 4 个信息面板：基础信息卡（图标/名称/频率）、STATS（当前连续/完成率/总记录三个 `StatCard`）、LAST 30 DAYS（`HeatmapView`——7 列 LazyVGrid 自绘热力格，今天有描边高亮）、TREND（30 天完成天数对比上一个 30 天，纯规则文案）。底部操作区三个按钮：编辑（`EditHabitSheet`）、归档（橙色，二次确认 alert，归档后仍保留历史数据但退出日常列表且清除提醒）、删除（红色 destructive，二次确认，级联删除所有打卡记录）。

`EditHabitSheet` 比新建多两块：**目标数量**（Toggle 开启后输入目标数值+单位，比如"3次"、"500ml"）和复用同款提醒设置，其余字段结构与 `AddHabitSheet` 基本对称但没有预设卡片区。

### 2.6 状态日志（`JournalListView` + `JournalDetailView` + `JournalEditorView`）

**主面板**：`SystemStatusBadge("JOURNAL X")` + 右上角黑色 `+` 按钮。非空时额外出现搜索框（图标+`TextField`+清空按钮）和一行横向筛选胶囊（"全部" + 每种心情 emoji + 每个 `ActivityTag`，点击当前项再点一次会取消筛选，心情筛选和标签筛选互斥——选一个会重置另一个）。列表按日期分组（`sectionHeaderDisplay`做分组标题），每条 `JournalRow`：左侧缩略图（若有照片，多图时右下角叠加"+N"角标）+ 时间+心情 emoji + 正文前两行 + 最多 3 个标签胶囊。整行是 `NavigationLink` 进 `JournalDetailView`。

**`JournalEditorView`**（新建与编辑复用同一个 View，`entry: JournalEntry?` 为 nil 时新建）：
1. **快速复盘模板区**：6 个预设模板（压力饮食/睡眠状态/外食复盘/运动日/经期状态/游戏娱乐），点击后把模板文本追加到正文（已有内容则用两个换行分隔）并联动勾选对应标签——这是全篇除 Onboarding 预设外**唯一的"一键套用文本模板"交互**
2. **心情选择**：5 个 emoji 横排按钮，再点一次取消选择
3. **影响因素标签**：`ActivityTag.allCases` 用自定义 `FlowLayout`（本文件内定义的通用流式布局 `Layout` 协议实现，处理胶囊自动换行）铺开，多选
4. **正文编辑**：`TextEditor` + 顶部 4 个 Markdown 快捷按钮（粗体/斜体/列表/引用），点击后把 Markdown 语法符号追加到文末（**不是在光标处插入，也不是包裹选中文本**——`content += "****"` 这种写法只是在末尾追加固定符号串，用户需要自己把光标移进符号中间打字；斜体按钮追加的是 `"**"`两个星号而不是`"*"`一个星号，与详情页用 `AttributedString(markdown:)` 渲染时的斜体语法不匹配，这是一个可以在原型复制到其它 App 前修正的小 bug）
5. **照片**：`PhotosPicker` 多选（最多 9 张，每张展示为 72×72 缩略图+右上角删除按钮），选择后异步逐张 `loadTransferable` 追加到 `photoDataList`
6. **日期**：`DatePicker(.date)`

保存时会先删除该 entry 原有的所有 `JournalPhoto` 再重新插入当前 `photoDataList`（不做增量 diff），照片经过 `ImageService.compress`/`ImageService.thumbnail`处理后落盘。

**`JournalDetailView`**：正文用 `AttributedString(markdown:)` 渲染（支持粗体/斜体/列表/引用），失败则降级显示纯文本。有照片时展示自适应网格（`LazyVGrid(.adaptive(minimum: 96))`）。底部编辑/删除两个操作行，删除有二次确认 alert。

### 2.7 训练记录（`WorkoutTimelineView` + 详情/编辑）

结构最复杂的子面板，`SystemStatusBadge("WORKOUTS X")` + 右上角黑色 `+` 按钮之外，还有：

- **「导入 Apple Health」按钮**（与身体数据卡同款绿色胶囊样式），点击后回溯过去 30 天逐天调用 `HealthKitService.shared.workoutLogs(for:)`，用 `externalIdentifier` 去重后批量插入，导入结果显示为按钮旁的一行文字（"没有新的训练" / "已导入 N 条"）——**这里的反馈没有用 GlobalBannerCenter，是内嵌文字**，和身体数据卡的导入反馈方式不一致（后者用 Banner），是两个相邻子面板之间的实现不统一之处
- **本周目标卡**（`weeklyGoalCard`）：默认折叠只显示"设定目标"入口（当目标仍是默认值 3次/150分钟时），点开后展开三个指标胶囊（次数/分钟/连续天数）+ 两个数值输入行（每周次数 1-14、每周时长 30-900 分钟）+ 两个提醒开关（周目标提醒/恢复提醒，开关变化会立即重新调度通知）+ 三行规则生成的建议文案（周报摘要、下次训练前的饮食建议、根据今日训练量和当前饮水量给出的补水建议）。**目标数值输入用的是失败静默校验**（`Int($0)`解析失败或超出范围时，`Binding`的`set`闭包直接不做任何操作，界面上数字不会跳动，但也没有任何"输入无效"的提示）
- **训练日历**（可折叠，`showCalendar`）：月历网格，6×7=42 格（含上下月补齐），每天一个圆点：有训练=绿色填充，仅休息日=蓝色（accent）填充，都没有=透明；今天额外描边圈。左右箭头切月，标题用 `zh_CN` locale 格式化"yyyy年M月"。
- **训练记录列表**（可折叠，`showWorkoutHistory`）：按日期分组，`WorkoutRow` 是 `NavigationLink` 进 `WorkoutDetailView`（休息日和正式训练共用一种行样式，靠 `isRestDay` 切换图标颜色和副标题内容）

**`WorkoutDetailView`**：`SystemPageHeader` + 概览卡 + （非休息日才有）「TRAINING DATA」面板（时长/强度/消耗/心率/距离/来源，心率和距离是可选字段，缺失时整行不渲染）+ （有备注才有）「NOTE」面板 + 编辑/删除操作行。

**`WorkoutEditorView`**：`isRestDay` Toggle 是第一个决策点——开启后训练类型/强度选择器整体隐藏，只保留时间和备注；关闭时才显示训练类型 `Picker(.menu)`、时长/消耗热量输入、强度 `Picker(.segmented)`。保存按钮的可用性只校验"非休息日时长必须>0"，没有对消耗热量做校验（允许留空）。这个 Sheet 与习惯/日志的新建 Sheet 一样，`SystemPageHeader` 使用英文文案（"CREATE WORKOUT"/"EDIT WORKOUT"），与详情页/主面板的中文标题不一致。

---

## 3. 值得注意的实现特点

1. **本篇是唯一系统使用自绘图表（非 Swift Charts）的地方**：能量趋势柱状图+折线、体重迷你折线、饮水/排便趋势柱状图全部用 `GeometryReader` + `Path` 手工计算坐标绘制，没有依赖 `Charts` 框架。这意味着复制到其它 App 时这套图表代码是完全可迁移的纯 SwiftUI 实现，不依赖额外 import。
2. **`healthTDEEByDay` 是一个会因周期切换而竞态的异步缓存**：`refreshHealthTDEE` 在设置了 `guard !Task.isCancelled, period == selectedPeriod` 才写回结果，防止用户快速切换周期时旧请求的结果覆盖新周期的展示——这是全篇少见的显式处理异步竞态的代码，其它子面板的异步调用（Apple Health 导入）都没有做类似的过期结果丢弃。
3. **身体数据导入和训练导入使用了两套不同的用户反馈机制**（Banner vs 内嵌文字），是两个紧邻面板之间风格不统一的具体案例，值得在文档 06（设置）或后续改进里统一收敛到 GlobalBannerCenter。
4. **习惯打卡是全 App 唯一的三态交互**（空/半/满），其它勾选交互都是二态。
5. **`BowelLogEditorSheet` 被声明为非 `private` 但只有一处调用**：说明当初设计时预期未来会被其它地方复用（比如从 Dashboard 或饮食 Tab 快速记录排便），目前尚未发生，是一个已声明但未使用的扩展面。
6. **Markdown 编辑器的"追加而非插入光标"实现方式**：粗体/斜体快捷按钮不做真正的富文本编辑操作，只是给正文字符串末尾追加固定符号，且斜体符号数量（`**`两个星号）与预期的单星号斜体语法不符——渲染层用标准 Markdown 解析器，这里存在一个实际的功能小 bug（斜体按钮实际效果等同于再次触发粗体）。
7. **新建类 Sheet 的双语不一致模式**：习惯/日志/训练三个"新建"Sheet 的 `SystemPageHeader`（eyebrow/title/detail）几乎都用英文，但 `JournalEditorView` 是例外——它的头部用中文（"状态记录"/"记录状态"），编辑器内部分组标题也是中文，是本篇 3 个新建 Sheet 里唯一贯彻中文的一个。换句话说双语不一致不是"新建=英文，编辑=中文"这种简单规律，而是各文件独立决定，复制到新 App 时需要统一而不能假设某种既有规律。

---

## 4. 可复制性 / 迁移建议

1. **阶段回顾面板（`ReviewSummaryPanel`）是整个 1Life 里最值得完整迁移的可复用资产**：周/月/季/年四态周期选择器 + 4 张自绘图表（概览网格/柱线复合图/热力网格/迷你趋势）的组合，对 1Track（记账）、1Pet（宠物健康）这类同样需要"阶段性数据回顾"的 App 几乎可以整体复用框架，只需替换 `ReviewPeriodSnapshot` 里的具体字段（把热量/训练换成支出/收入，或换成宠物体重/驱虫记录）。
2. **HabitTrackerView 的整套"打卡习惯"模型（三态循环+连续天数+30天热力图+预设卡片）是一个独立度很高的通用组件**，如果 1Day 或 1Pet 需要"每日待办/护理打卡"，可以直接复用这套 `Habit`/`HabitLog` 数据结构和交互模式，替换预设列表和图标集合即可。
3. **深链定位机制（`myLifeFocus` 枚举 + `.id()` 锚点 + `ScrollViewProxy`）是一个轻量但通用的跨 Tab 导航模式**，任何"Tab A 的摘要卡片点击后跳到 Tab B 并滚动到特定区块"的需求都可以复刻这个三步流程（写状态→切 Tab→监听状态滚动并清空）。
4. **需要在迁移前修正、而不是原样复制的两处**：Markdown 快捷按钮的符号追加逻辑（斜体符号数量错误）、身体数据/训练两处 Apple Health 导入反馈机制不统一（一个用 Banner 一个用内嵌文字）——建议新 App 直接采用"统一用 GlobalBannerCenter"的版本，不必复刻这处不一致。
5. **英文/中文标签混用没有必然规律，需要在迁移时人工审查每个文件**，不能假设"新建用英文、编辑用中文"之类的省力规则——本篇发现的具体分布（习惯新建/编辑、训练新建/编辑都是英文，日志新建/编辑是中文）已经打破了 04 篇里观察到的任何简单假设。

---

## 已知问题汇总（本篇新发现，将同步记录到 ROADMAP.md）

- `JournalEditorView.applyMarkdown` 的斜体快捷按钮追加 `"**"`（两个星号），与详情页 Markdown 渲染器的单星号斜体语法不匹配，实际效果是再次触发粗体符号而非斜体。
- 身体数据卡（`BodyMetricsCard`）的 Apple Health 导入使用 `GlobalBannerCenter` 反馈，训练面板（`WorkoutTimelineView`）的 Apple Health 导入使用内嵌文字反馈，两处操作性质相同但反馈机制不统一。
- 训练目标数值输入（每周次数/每周时长）在解析失败或超出范围时静默丢弃输入，没有任何提示告知用户为什么输入没有生效。
