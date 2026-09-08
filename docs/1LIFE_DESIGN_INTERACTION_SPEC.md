# 1Life 设计与交互规范

> 基于 1Life 完整代码库提炼
> 最后更新：2026-07-06
> 本文是 `UI_STYLE_GUIDE_V2.md` 的实现落地说明，供家族其他 App（1Cash / 1Track / 1Day / 1Pet）审查与复用。
> 所有代码示例引用真实文件路径，审查时可直接对照。

---

## 目录

1. [视觉设计规范](#1-视觉设计规范)
2. [组件架构与设计模式](#2-组件架构与设计模式)
3. [交互逻辑与操作流程](#3-交互逻辑与操作流程)
4. [页面结构与信息架构](#4-页面结构与信息架构)
5. [家族复用建议](#5-家族复用建议)

---

## 1. 视觉设计规范

### 1.1 色彩体系

所有设计令牌集中定义在 `Extensions.swift` 的 `FamilyUI` 枚举中，作为家族 V2 共享令牌。

#### 基础色（深浅色自适应）

| 令牌 | 浅色模式 | 深色模式 | 用途 |
|------|---------|---------|------|
| `FamilyUI.pageBackground` | `#f4f1eb` 暖纸白 | `#161410` 暖近黑 | 页面底色 |
| `FamilyUI.panelBackground` | `#ffffff` 纯白 | `#1f1d1a` 暖深面板 | 面板/卡片背景 |
| `FamilyUI.panelMutedBackground` | `#f0ede7` 浅暖灰 | `#2a2724` 深暖灰 | 次级面板、输入框、按钮底 |
| `FamilyUI.panelBorder` | `black 14%` | `white 12%` | 所有面板/控件描边 |
| `FamilyUI.divider` | `black 10%` | `white 8%` | 面板内分割线 |

> 文件：`1Life/Extensions.swift` L257-293

#### 语义色

| 令牌 | 值 | 用途 |
|------|-----|------|
| `FamilyUI.accent` | `#1e4ed8` 蓝 | 主操作、关键数值、选中态 |
| `FamilyUI.success` | `#2f7a63` 深青 | 达标、保存成功、同步完成 |
| `FamilyUI.warning` | `orange` | 接近上限、待配置 |
| `FamilyUI.danger` | `red` | 超标、删除、错误 |
| `FamilyUI.subtleText` | `systemGray` | 辅助说明文字 |

#### 营养素语义色

营养素颜色收敛饱和度，仅用于进度条和极小标签：

| 营养素 | 颜色 |
|--------|------|
| 蛋白质 | `FamilyUI.accent` 冷蓝 |
| 碳水 | `.orange` 柔和橙 |
| 脂肪 | `#9a7b22` 暖琥珀 |
| 纤维 | `FamilyUI.success` |
| 钠 | `#8b3a8b` |
| 糖 | `#c94c7a` |

> 文件：`1Life/Extensions.swift` L230-243 `NutrientKey.spotlightColor`

#### 用色规则

- 单屏彩色种类不超过 2 种
- 彩色只点亮最重要的一项
- 不用彩虹式营养图
- 黑色用于"系统主操作"按钮（发送、添加一餐、确认记录）

### 1.2 排版系统

#### 全局字体配置

`AppTypography.configureGlobalAppearance()` 在 App 启动时调用（`OneLifeApp.swift` L9），将导航栏和 Tab 标签统一为 **Rounded** 设计：

> 文件：`1Life/Extensions.swift` L8-36

- 导航栏 inline 标题：`headline + semibold + rounded`
- 导航栏 large 标题：`largeTitle + bold + rounded`
- Tab 标签：`caption1 + medium + rounded`

所有 View 通过 `.appTypography()` 修饰器（L46-49）应用 `design: .rounded`。

#### 字体层级

| 层级 | 样式 | 使用场景 |
|------|------|---------|
| Hero 数字 | `.system(size: 42, weight: .black)` + `.monospacedDigit()` | 首页总摄入、热量英雄数字 |
| 大数字 | `.system(size: 38, weight: .black)` | 饮食页总摄入 |
| 页面标题 | `.system(size: 32, weight: .black)` | Onboarding/Sheet 页头 |
| 面板内大数值 | `.system(size: 28, weight: .black)` | 饮水进度 |
| 卡片标题 | `.title3.weight(.bold)` 或 `.headline.weight(.black)` | 面板内主标题 |
| 分组标签（eyebrow） | `.system(size: 11, weight: .semibold)` + `.tracking(1.2)` | 面板标题、STEP 标签 |
| 状态标签 | `.system(size: 11, weight: .semibold)` + `.tracking(0.8)` | SystemStatusBadge |
| 列表主文本 | `.subheadline.weight(.semibold)` | 记录行标题 |
| 列表辅文本 | `.caption` 或 `.caption2` | 记录行副标题 |
| 极小标签 | `.system(size: 10, weight: .semibold)` + `.tracking(1)` | 日期 TODAY/ARCHIVE 标签 |
| 极小数据 | `.system(size: 9)` | 进度条范围刻度 |

#### 数字显示规则

- 所有数值文本使用 `.monospacedDigit()`
- 显示用 `Int()` 截断（非四舍五入），避免 99.7g 显示为 100g
- 存储和计算保持 `Double` 原始精度
- `Double` 扩展：`nutritionInt`（整数）、`nutritionDecimal`（1 位小数）、`kcalString`

> 文件：`1Life/Extensions.swift` L315-327

### 1.3 间距与布局

#### 间距令牌

> 文件：`1Life/Extensions.swift` L205-214 `AppSpacing`

| 令牌 | 值 | 用途 |
|------|-----|------|
| `pageHorizontal` | 16pt | 页面左右边距 |
| `cardPadding` | 16pt | 面板内边距 |
| `cardPaddingLarge` | 20pt | 大面板内边距 |
| `sectionSpacing` | 12pt | 面板间距 |
| `formSpacing` | 16pt | 表单组间距 |
| `itemSpacing` | 8pt | 紧凑信息组间距 |
| `rowIconSpacing` | 12pt | 行内图标与文字间距 |
| `pageBottom` | 24pt | 页面底部留白 |

#### 圆角令牌

> 文件：`1Life/Extensions.swift` L218-226 `AppCornerRadius` + L289-293 `FamilyUI`

| 令牌 | 值 | 用途 |
|------|-----|------|
| `FamilyUI.panelCornerRadius` | 12pt | 主面板、卡片 |
| `FamilyUI.controlCornerRadius` | 10pt | 按钮、输入框、子面板 |
| `FamilyUI.badgeCornerRadius` | 6pt | 状态标签、小色块 |
| `AppCornerRadius.card` | 14pt | 主卡片（兼容旧值） |
| `AppCornerRadius.progressBar` | 3pt | 进度条 |
| `AppCornerRadius.photo` | 12pt | 照片缩略图 |

#### 描边规则

所有面板和控件统一使用 1px 浅灰描边：

```swift
.overlay(
    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
        .stroke(FamilyUI.panelBorder, lineWidth: 1)
)
.clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
```

> 这是 V2 风格的核心——"描边优先于阴影"。

#### 阴影规则

- 常规面板：无阴影
- Splash 启动页：`shadow(color: .black.opacity(0.08), radius: 18, y: 12)` 仅此一处例外
> 文件：`1Life/Views/Splash/SplashView.swift` L40

### 1.4 图标与图片

#### SF Symbol 使用

- 图标框统一尺寸：`FamilyUI.iconBoxSize = 34pt`，圆角 8pt
- 图标框样式：`panelMutedBackground` 底 + `panelBorder` 描边
- 图标字号：14pt `.semibold`（设置行）/ 15pt（餐卡）
- 选中态使用 `checkmark.square.fill` / `checkmark.circle.fill`
- Tab 图标：16pt `.bold`

#### 图片策略

- 原图压缩至 ≤1MB JPEG，存 `@Attribute(.externalStorage)`
- 缩略图 200px ≤50KB，内联存储
- 列表展示缩略图，详情页用压缩原图
- `ImageService.compress()` 统一压缩入口

---

## 2. 组件架构与设计模式

### 2.1 通用组件清单

所有通用组件位于 `1Life/Components/` 目录。

| 组件 | 文件 | 职责 |
|------|------|------|
| `SystemPanel` | `SystemPanel.swift` | 核心容器，带可选标题+说明+描边 |
| `SystemPageHeader` | `SystemPanel.swift` | 页面级标题（eyebrow + 大标题 + 说明） |
| `SystemPanelDivider` | `SystemPanel.swift` | 面板内分割线 |
| `SystemStatusBadge` | `SystemPanel.swift` | 状态标签（5 种 tone） |
| `AppEmptyStateView` | `AppEmptyStateView.swift` | 空状态（图标+标题+副标题+可选按钮） |
| `AppSettingsRow` | `AppSettingsRow.swift` | 设置行（图标+标题+副标题+值+箭头） |
| `PrimaryButton` | `PrimaryButton.swift` | 主按钮（accent 底 + 白字 + 黑描边） |
| `SectionHeader` | `SectionHeader.swift` | 分组标题（次级文字） |
| `UserAvatarView` | `UserAvatarView.swift` | 头像（4 级回退） |
| `AppErrorBanner` | `AppErrorBanner.swift` | 全局横幅（自动消失 4s） |

#### SystemPanel — 核心容器

```swift
// 用法 1：带标题和说明
SystemPanel(title: "今日摄入", detail: "摄入、目标差值与宏量营养执行情况") {
    // content
}

// 用法 2：无标题（内容自包含）
SystemPanel {
    // content
}
```

内部结构：`VStack(alignment: .leading, spacing: 14)` + `padding(16)` + `panelBackground` + 1px 描边 + 12pt 圆角。

> 文件：`1Life/Components/SystemPanel.swift` L30-75

#### SystemStatusBadge — 状态标签

5 种 tone：`neutral` / `accent` / `success` / `warning` / `danger`

```swift
SystemStatusBadge(text: "剩余 560", tone: .accent)
SystemStatusBadge(text: "已记录", tone: .success)
SystemStatusBadge(text: "STEP 3 / 8", tone: .neutral)
```

样式：11pt semibold + tracking(0.8) + tone 色 10% 透明度底 + 6pt 圆角。

> 文件：`1Life/Components/SystemPanel.swift` L85-128

#### AppSettingsRow — 设置行

```swift
AppSettingsRow(
    icon: "flame.fill",
    iconColor: .orange,
    title: "每日目标",
    subtitle: "热量与三大营养素目标",
    value: "2000 kcal",
    showsChevron: true,
    emphasizesValue: true
)
```

支持嵌入 `NavigationLink`、`Button`、`Toggle`、`Picker`、`Stepper` 内部。

> 文件：`1Life/Components/AppSettingsRow.swift`

#### UserAvatarView — 4 级回退头像

```
1. avatarData (照片) → 圆角矩形裁剪
2. symbolName (SF Symbol) → mutedBackground 底 + accent 图标
3. name → 渐变底（accent → #173a98）+ 白色首字母
4. 兜底 → mutedBackground 底 + person.fill
```

圆角比例为 `size * 0.28`，对齐家族规范。

> 文件：`1Life/Components/UserAvatarView.swift`

### 2.2 组件拆分策略

#### 大 View 拆分为 private subview

Dashboard 有 929 行，但通过 `private var` 计算属性拆分为 7 个独立面板：

```swift
private var dateSelectorPanel: some View { ... }
private var heroCard: some View { ... }
private var mealStatusPanel: some View { ... }
private var nutritionDetailsSection: some View { ... }
private var healthMetricsRow: some View { ... }
private var waterCard: some View { ... }
private var quickStatusRow: some View { ... }
```

> 文件：`1Life/Views/Dashboard/DashboardView.swift`

#### 子组件提取到独立 struct

重复使用的模式提取为 `private struct`：

- `MacroProgressBar`、`MetricStrip`、`NutrientRow`、`NutrientGroupBlock`、`HealthMetricItem`（Dashboard）
- `HabitRow`、`SummaryPill`、`BodyTrendStrip`（MyLife）
- `ChatBubble`、`MealBubbleCard`、`FeatureCard`（AIChat）

#### Writer/Coordinator 模式

数据写入逻辑提取到独立 Service/Coordinator：

- `FoodTimelineMealWriter` — 餐食创建、复制、批量添加
- `SettingsDataCoordinator` — 导出/导入/清空
- `AIChatMealRecorder` — AI 解析结果持久化

> 避免在 View 中直接操作 modelContext 的复杂逻辑。

### 2.3 状态管理

#### @Observable AppViewModel — 全局状态

```swift
@Observable
final class AppViewModel {
    var selectedTab: AppTab = .dashboard
    var selectedDate: Date = .now      // 首页和饮食页共享
    var isShowingOnboarding = false
    var myLifeFocus: MyLifeFocus?      // 跨 Tab 导航焦点
}
```

通过 `.environment(appViewModel)` 注入，子 View 用 `@Environment(AppViewModel.self)` 读取。

> 文件：`1Life/ViewModels/AppViewModel.swift` L68-86

#### GlobalBannerCenter — 全局横幅单例

```swift
@MainActor @Observable
final class GlobalBannerCenter {
    static let shared = GlobalBannerCenter()
    var currentBanner: AppBannerPayload?

    func show(title: String, message: String? = nil, tone: AppBannerTone = .error)
    func dismiss()
}
```

在 `ContentView` 的 `.overlay(alignment: .top)` 中监听并渲染 `AppErrorBanner`。各 View 通过 `@State private var bannerCenter = GlobalBannerCenter.shared` 调用。

> 文件：`1Life/ViewModels/AppViewModel.swift` L4-25

#### FeedbackPreferences — 反馈偏好单例

```swift
@MainActor @Observable
final class FeedbackPreferences {
    static let shared = FeedbackPreferences()
    var isHapticsEnabled: Bool
    var isSoundEffectsEnabled: Bool
}
```

UserDefaults 持久化，`HapticEngine` 和 `SoundEngine` 在每次触发前检查。

> 文件：`1Life/ViewModels/AppViewModel.swift` L28-66

#### 状态管理边界

| 机制 | 使用场景 |
|------|---------|
| `@State` | View 本地 UI 状态（展开、Sheet 开关、输入文本） |
| `@Binding` | 父子组件传值（DatePicker、OptionRow） |
| `@Environment(AppViewModel.self)` | 全局 Tab/日期/导航焦点 |
| `@Environment(\.modelContext)` | SwiftData 写入 |
| `@Query` | SwiftData 读取（按 Tab 分散查询） |
| `@Observable` class | 跨 View 共享的业务状态 |
| `@Bindable var settings` | Onboarding 中双向绑定 AppSettings |

#### ContentView 顶层查询策略

```swift
@Query private var settings: [AppSettings]   // Onboarding 检查
// 不查询 Meal、FoodItem、Habit —— 各 Tab 自己查
```

> 文件：`1Life/ContentView.swift` L5-6

### 2.4 导航模式

#### 自定义 TabBar

不使用系统 `TabView`，而是自定义 `AppTabBar`：

```swift
HStack(spacing: 6) {
    ForEach(AppTab.allCases) { tab in
        Button {
            HapticEngine.tap()
            withAnimation(.snappy(duration: 0.22)) {
                selectedTab = tab
            }
        } label: { ... }
    }
}
```

特征：
- 选中项：accent 底 + 白字 + 黑描边
- 非选中：mutedBackground 底 + secondary 文字
- 顶部 1px 分割线
- `ignoresSafeArea(edges: .bottom)` 延伸到底部

> 文件：`1Life/ContentView.swift` L85-131

#### NavigationStack + Sheet

每个 Tab 内部独立 `NavigationStack`。二级页面用 `NavigationLink`，表单和编辑用 `.sheet`：

```swift
.sheet(isPresented: $isShowingAddMeal, onDismiss: cleanupEmptyMeals) {
    AddMealSheet(mealType: selectedMealType, date: selectedDate)
}
```

Sheet 的 `onDismiss` 用于清理空 Meal（用户取消且无 FoodItem 时删除空 Meal）。

#### 跨 Tab 导航

通过 `AppViewModel` 实现：

```swift
private func openMyLife(_ focus: MyLifeFocus) {
    HapticEngine.tap()
    withAnimation(.snappy(duration: 0.28)) {
        appViewModel.myLifeFocus = focus
        appViewModel.selectedTab = .myLife
    }
}
```

MyLifeView 通过 `ScrollViewReader` + `.id(MyLifeFocus.xxx)` 实现滚动定位。

> 文件：`1Life/Views/MyLife/MyLifeView.swift` L113-121

---

## 3. 交互逻辑与操作流程

### 3.1 触感反馈（Haptics）

> 文件：`1Life/Extensions.swift` L184-201

#### 三级反馈

| 级别 | 实现 | 触发场景 |
|------|------|---------|
| `HapticEngine.tap()` | `UIImpactFeedbackGenerator(.light)` | 切换 Tab、选择餐次、picker 确认、+1杯水、习惯半完成、清空输入 |
| `HapticEngine.success()` | `UINotificationFeedbackGenerator(.success)` + `SoundEngine.confirmation()` | 餐食记录成功、AI 确认写入、模板保存、导入完成、习惯全完成、Onboarding 完成 |
| `HapticEngine.warning()` | `UINotificationFeedbackGenerator(.warning)` | 删除餐食/食物/习惯、清空聊天、清空数据、撤销操作、导入失败 |

#### 声音反馈

`SoundEngine.confirmation()` 播放系统音 1104（短促确认音），仅在 `isSoundEffectsEnabled` 时触发。`success()` 级别即使关闭震动也会播放声音。

#### 反馈开关

设置页「反馈」面板提供两个开关：
- 震动反馈（`isHapticsEnabled`）
- 提示音（`isSoundEffectsEnabled`）

> 文件：`1Life/Views/Settings/SettingsView.swift` L456-498

### 3.2 动画规范

#### 动画特征

"切换状态"，不是"玩具反馈"——短、准、收得快。

| 场景 | 动画 | 时长 |
|------|------|------|
| Tab 切换 | `.snappy(duration: 0.22)` | 0.22s |
| 跨 Tab 导航 | `.snappy(duration: 0.28)` | 0.28s |
| 横幅出现/消失 | `.spring(response: 0.35, dampingFraction: 0.74)` | — |
| 横幅手动关闭 | `.easeOut(duration: 0.18)` | 0.18s |
| 面板展开/收起 | `.easeInOut(duration: 0.25)` | 0.25s |
| Onboarding 步骤切换 | `.easeInOut(duration: 0.22)` | 0.22s |
| Splash 图标入场 | `.spring(response: 0.6, dampingFraction: 0.7)` | — |
| Splash 文字入场 | `.easeOut(duration: 0.4).delay(0.3)` | — |
| 周期切换加载 | `.easeInOut(duration: 0.2)` → 0.18s sleep → `.easeInOut(0.25)` | — |
| 日期切换 | 160ms 预加载延迟 | — |
| 滚动定位 | `.snappy(duration: 0.34)` | 0.34s |

#### 避免的动画

- 弹簧感太强的动画
- 过于柔软的缩放反馈
- 大面积渐变流动

### 3.3 用户操作流

#### 添加流程（Add）

**创建-编辑-清理模式**：

1. 用户点击"+ 添加一餐" → 立即创建空 Meal
2. Sheet 展开，在 Meal 上添加 FoodItem
3. 用户取消（dismiss Sheet）→ `onDismiss` 检查 Meal 是否有 FoodItem
4. 如果无 FoodItem → 自动删除空 Meal

> 文件：`1Life/Views/Food/FoodTimelineView.swift` L191, L689-691

**快捷添加模式**：

- 从「我的食物」一键添加（复用默认份量）
- 从「最近吃过」复制（复用历史记录）
- 从「模板库」创建整餐
- 从「复制昨天」复制整餐
- 批量添加（多选食物）

所有快捷添加成功后触发 `HapticEngine.success()`。

#### 编辑流程（Edit）

- FoodItem 编辑：`.sheet(item: $editingItem)` 绑定可选 item
- Meal 编辑：展开/收起 + contextMenu 更改餐次
- AI 结果编辑：`MealManualEditSheet` 全量编辑

#### 删除流程（Delete）

**危险操作确认**：

- 清空聊天历史：`.alert` + "取消"/"清空"(destructive) + `HapticEngine.warning()`
- 清空所有数据：`clearDataStep` 逐步确认
- 导入覆盖：`.alert` + "取消"/"覆盖并导入"(destructive)

**静默删除**：

- 单个 FoodItem：`contextMenu` → "删除食物"，无二次确认
- 单个 Meal：`contextMenu` → "删除整餐"，无二次确认

> 文件：`1Life/Views/Food/MealCardView.swift` L79-103

#### 确认流程（Confirm）

AI 识别结果必须经过确认卡片：

```
AI 返回 → pendingConfirmation / pendingMealResult 展示确认卡片
  → 用户可：确认记录 / 手动编辑 / 重新识别 / 取消 / 存到模板库
  → 确认后才写入 SwiftData
```

> 文件：`1Life/Views/AIChat/AIChatView.swift` L197-224

#### 撤销流程（Undo）

**饮水撤销（3 秒 SnackBar）**：

1. 点击 +ml → 创建 WaterLog → 底部显示撤销 Bar
2. 3 秒内可点击「撤销」删除刚创建的记录
3. 3 秒后自动消失，撤销机会结束
4. 撤销触发 `HapticEngine.warning()`

> 文件：`1Life/Views/Dashboard/DashboardView.swift` L489-551

**AI 餐食撤销**：

聊天历史中的 MealBubbleCard 提供「撤销」按钮，调用 `viewModel.undoMeal(message)` 删除已写入的 Meal 并标记消息为已撤销。

> 文件：`1Life/Views/AIChat/AIChatComponents.swift` L330-385

### 3.4 表单交互

#### 输入校验

```swift
private var canSave: Bool {
    Double(weightText) != nil || Double(bodyFatText) != nil
}
```

保存按钮 `.disabled(!canSave)`，无法保存时按钮变灰。

> 文件：`1Life/Views/MyLife/MyLifeView.swift` L647-649

#### 实时反馈

- AI 配置状态实时显示在 `AIConfigurationHeader`
- 输入框获得焦点时 `messageFieldFocused = true`，发送后失焦
- 键盘通过 `dismissKeyboardOnTap()` 点击空白处收起

#### 确认页模式

Onboarding 最后一步 `CompleteStep` 展示所有选择摘要，点击"开始记录"一次性写入所有数据。

### 3.5 AI 交互流

#### 聊天 UI 结构

```
NavigationStack
├── AIConfigurationHeader     // 顶部配置状态栏
├── chatSection               // 消息列表（ScrollViewReader）
│   ├── AIEmptyStateContent   // 空状态（特性卡片 + 配置引导）
│   └── ChatBubble[]          // 消息气泡
├── pendingSection            // 待确认卡片
└── inputSection              // 输入区
    ├── AIRequestProgressView // 加载态
    ├── selectedImagesSection // 已选图片
    ├── promptChipsSection    // 快捷指令
    └── inputBarSection       // 相机 + 语音 + 输入框 + 发送
```

> 文件：`1Life/Views/AIChat/AIChatView.swift`

#### 消息气泡

- 用户消息：黑底白字 + 黑描边
- AI 消息：panelBackground 底 + panelBorder 描边
- 餐食卡片消息：结构化面板（餐次 + 总热量 + 食物列表 + 撤销按钮）
- 最大宽度 280pt
- 长按可复制（`contextMenu`）

> 文件：`1Life/Views/AIChat/AIChatComponents.swift` L283-438

#### 加载态

`AIRequestProgressView` 根据耗时动态切换状态文案：

| 阶段 | 文字标题 | Badge |
|------|---------|-------|
| 0-12s | 正在理解记录 | 理解 |
| 12-30s | 正在估算营养 | 估算 |
| 30s+ | 正在整理确认结果 | 生成 |
| 图片 0-20s | 正在读取图片 | OCR |
| 图片 20-45s | 正在整理营养信息 | 解析 |

> 文件：`1Life/Views/AIChat/AIChatComponents.swift` L87-152

#### 确认卡片

两种确认卡片：

1. `MealConfirmationCard` — 直接餐食确认，支持份量滑块、手动编辑、存模板
2. `AIMealIdentificationConfirmationView` — 本地解析/AI 结果确认，支持重新识别

确认卡片底部操作区：

```
[取消]  [手动编辑]  [存到模板库]  [确认记录]
```

确认按钮：黑底白字 + controlCornerRadius，禁用态变灰。

> 文件：`1Life/Views/AIChat/AIChatMealReviewComponents.swift`

#### 快捷指令（Prompt Chips）

水平滚动按钮组，点击直接发送或填充输入框：

```swift
["记录早餐", "拍照识别", "营养分析", "记录训练", "记录排便", "写日记", "记录喝水"]
```

样式：caption bold + mutedBackground 底 + badgeCornerRadius + panelBorder 描边。

#### 多模态输入

- 相机按钮：`canUseVision` 为 false 时灰显
- 语音输入：录音中变红底 + 白图标
- 图片附件：58×58 缩略图 + 可删除，最多 6 张
- 发送按钮：黑底白字箭头，加载时变沙漏图标

---

## 4. 页面结构与信息架构

### 4.1 五个 Tab 的页面结构

#### Tab 1: 今日（Dashboard）

> 文件：`1Life/Views/Dashboard/DashboardView.swift`

```
NavigationStack
└── ScrollView
    └── LazyVStack(spacing: 16)
        ├── dateSelectorPanel      // 日期选择 + DaySelectorView
        ├── heroCard               // 总摄入 + 进度环 + 状态标签 + MetricStrip × 3 + 营养素网格
        ├── mealStatusPanel        // 四餐次 2×2 网格（已记录/可补记）
        ├── nutritionDetailsSection // 可展开完整营养素
        ├── healthMetricsRow       // 步数/睡眠/运动/日照 4 列
        ├── waterCard              // 饮水进度 + +ml Menu
        └── quickStatusRow         // 习惯/训练/日记快捷入口
```

Hero Card 是第一视觉中心：42pt 黑体数字 + 124×124 进度环 + 剩余/超出状态标签。

#### Tab 2: 饮食（Food Timeline）

> 文件：`1Life/Views/Food/FoodTimelineView.swift`

```
NavigationStack
└── ZStack
    ├── ScrollView
    │   └── LazyVStack(spacing: 16)
    │       ├── dayControlPanel
    │       ├── inlineSearchBar          // 内联搜索（非系统搜索栏）
    │       ├── summaryPanel             // 今日摄入 + 剩余 + 进度条
    │       ├── quickActionsPanel        // 5 个快捷按钮 + 模板/常用/最近横滑
    │       ├── macroSummaryPanel        // 三大宏量素 + 风险提醒
    │       ├── todayDietSummaryPanel    // AI 生成的小结文案
    │       ├── historySearchPanel       // 搜索时的历史匹配
    │       └── mealList                 // 按餐次分组的 MealTypeSection
    └── bottomBar                        // 当天合计 + 添加一餐
```

#### Tab 3: AI

见 [3.5 AI 交互流](#35-ai-交互流)。

#### Tab 4: 回顾（MyLife）

> 文件：`1Life/Views/MyLife/MyLifeView.swift`

```
NavigationStack
└── ScrollViewReader
    └── ScrollView
        └── VStack(spacing: 16)
            ├── MyLifeSummaryCard       // 习惯/训练/状态摘要
            ├── ReviewSummaryPanel      // 周期回顾（周/月/季/年 Picker）
            ├── BodyMetricsCard         // 体重/体脂 + 趋势条 + 导入 Health
            ├── BowelTrackerCard        // 排便记录
            ├── HabitTrackerView        // 习惯列表（.id(habits)）
            ├── JournalListView         // 日记时间线（.id(journal)）
            └── WorkoutTimelineView     // 训练记录（.id(workouts)）
```

#### Tab 5: 设置（Settings）

> 文件：`1Life/Views/Settings/SettingsView.swift`

```
NavigationStack
└── ScrollView
    └── LazyVStack(spacing: 16)
        ├── profileSection        // 头像 + 昵称 + AI/健康状态标签
        ├── aiConfigSection       // AI 服务商 + 视觉支持标签
        ├── healthGoalSection     // 身体参数 + 每日目标 + 饮食模式 + 饮水/杯量
        ├── appleHealthSection    // 动态 TDEE + 连接 + 消耗详情
        ├── feedbackSection       // 震动 + 提示音
        ├── foodLibrarySection    // 我的食物 + 模板库
        ├── pluginSection         // 饮品营养识别插件
        ├── reminderSection       // 三餐提醒
        ├── dataSection           // 导出 CSV/JSON/PDF + 导入 + 清空
        ├── appearanceSection     // 浅色/深色/跟随系统
        └── aboutSection          // 站内信 + 隐私 + 手册 + 反馈 + 版本
```

### 4.2 Onboarding 流程

> 文件：`1Life/Views/Onboarding/OnboardingView.swift` + `OnboardingComponents.swift`

#### 步骤（9 步）

| Step | 页面 | 说明 |
|------|------|------|
| 0 | Welcome | 品牌 + 三个价值点 |
| 1 | Language | 语言选择 |
| 2 | Preset | 预设模式（均衡/减脂/增肌等） |
| 3 | Profile | 昵称 + 头像 |
| 4 | BodyParams | 性别/年龄/身高/体重/活动量（可跳过） |
| 5 | DietGoal | 饮食目标模式 |
| 6 | CalorieTarget | 热量目标（可推荐） |
| 7 | Reminder | 三餐提醒时间 |
| 8 | AIConfig | 服务商 + API Key（可跳过） |
| 9 | Complete | 摘要 + 开始记录 |

#### 交互特征

- 自由前后切换（返回按钮 + 左滑手势）
- 顶部进度条（4pt 高，accent 填充）
- STEP 标签：`SystemStatusBadge(text: "STEP 3 / 8")`
- 步骤切换动画：`.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))`
- "可跳过"步骤的跳过按钮在「下一步」下方
- 完成页一次性写入所有数据 + 调度通知 + `HapticEngine.success()`

#### Onboarding 组件

| 组件 | 用途 |
|------|------|
| `OnboardingHeader` | 返回按钮 + STEP 标签 + 进度条 |
| `OnboardingPageHeader` | eyebrow + 大标题 + 说明 |
| `OnboardingBottomBar` | 底部固定操作区 |
| `OnboardingNextButton` | 主按钮（accent 底） |
| `OnboardingSecondaryButton` | 次按钮（无背景） |
| `OnboardingIconBox` | 34pt 图标框 |
| `OnboardingMetricInput` | 标签 + 输入框 + 单位 |
| `OptionRow` | 可选行（选中态高亮） |
| `SummaryRow` | 摘要行 |

### 4.3 设置页的导出/数据管理流程

> 文件：`1Life/Views/Settings/SettingsDataSection.swift` + `SettingsDataCoordinator.swift`

#### 导出

- **CSV**：明细粒度 + 每日汇总粒度
- **JSON**：完整备份（可选含照片），导出前显示横幅提示
- **PDF**：营养报告，选择日期范围后生成

所有导出通过 `ShareSheet` 分享。

#### 导入

1. `.fileImporter` 选择 JSON
2. 弹出 `.alert` 二次确认（"覆盖并导入"为 destructive）
3. 导入成功：`HapticEngine.success()` + 成功横幅
4. 导入失败：`HapticEngine.warning()` + 错误横幅

#### 清空

`clearDataStep` 控制清空确认流程，通过 `SettingsDataCoordinator.clearAllData` 执行。

### 4.4 空状态引导策略

#### 通用空状态组件

```swift
AppEmptyStateView(
    icon: "fork.knife",
    title: "还没有记录",
    subtitle: "拍照或手动添加你的第一餐",
    buttonTitle: "手动添加",
    buttonAction: { ... }
)
```

样式：72×72 图标框 + 黑体标题 + 副标题 + 可选 accent 按钮，整体包裹在 SystemPanel 内。

#### AI 空状态

`AIEmptyStateContent` 包含：
- AI 介绍面板（图标 + 标题 + 说明 + 状态标签）
- 未配置时的 `AISetupNoticeCard`（橙色描边 + 前往设置按钮）
- 5 个 `FeatureCard`（特性介绍）

#### 嵌入式空状态

习惯列表为空时显示引导按钮："追踪早睡、补剂、拉伸等每日行为"。

#### 无搜索结果

```swift
SystemPanel(title: "搜索结果", detail: "没有找到匹配的食物或餐次") {
    HStack { Image("magnifyingglass"); Text("没有找到 "\(searchText)"") }
}
```

---

## 5. 家族复用建议

### 5.1 应作为家族级标准推广的模式

#### 必须复用

| 模式 | 文件 | 说明 |
|------|------|------|
| `FamilyUI` 设计令牌 | `Extensions.swift` L257-293 | 所有 App 统一色彩/圆角/描边 |
| `AppSpacing` / `AppCornerRadius` | `Extensions.swift` L205-226 | 统一间距和圆角 |
| `SystemPanel` 容器 | `Components/SystemPanel.swift` | 所有 App 的面板容器 |
| `SystemStatusBadge` | `Components/SystemPanel.swift` | 统一状态标签 |
| `SystemPageHeader` | `Components/SystemPanel.swift` | 统一页面标题 |
| `AppSettingsRow` | `Components/AppSettingsRow.swift` | 统一设置行 |
| `AppEmptyStateView` | `Components/AppEmptyStateView.swift` | 统一空状态 |
| `PrimaryButton` | `Components/PrimaryButton.swift` | 统一主按钮 |
| `UserAvatarView` | `Components/UserAvatarView.swift` | 统一头像（4 级回退） |
| `AppErrorBanner` + `GlobalBannerCenter` | `Components/AppErrorBanner.swift` | 统一全局横幅 |
| `HapticEngine` + `SoundEngine` | `Extensions.swift` L174-201 | 统一触感/声音 |
| `FeedbackPreferences` | `ViewModels/AppViewModel.swift` | 统一反馈开关 |
| 自定义 `AppTabBar` | `ContentView.swift` L85-131 | 统一底部导航 |
| `DaySelectorView` | `ContentView.swift` L133-202 | 日期选择器（有日期的 App 复用） |
| Onboarding 骨架 | `OnboardingComponents.swift` | 统一步骤结构、进度条、按钮 |
| `AppTypography` 全局配置 | `Extensions.swift` L8-36 | Rounded 字体全局应用 |
| Splash 启动动画 | `Views/Splash/SplashView.swift` | 统一启动体验 |

#### 推荐复用

| 模式 | 说明 |
|------|------|
| `@Observable AppViewModel` 模式 | 全局 Tab/日期/导航焦点管理 |
| ContentView 顶层只查 settings | 各 Tab 内部自己查业务模型 |
| Sheet `onDismiss` 清理空记录 | 创建后取消时自动清理 |
| 快捷指令 chips | 水平滚动按钮组 |
| AI 加载态分阶段文案 | 根据耗时切换状态文字 |
| 确认卡片模式 | AI 结果必须确认后写入 |
| 撤销 SnackBar 模式 | 3 秒撤销机会 |
| 周期回顾 Picker | 周/月/季/年切换 |

### 5.2 1Life 领域特有，不需要复用

| 模式 | 原因 |
|------|------|
| `NutrientKey.spotlightColor` | 营养素专属颜色映射 |
| `MacroProgressBar` / `NutrientRow` | 营养素进度条专属 |
| `MealConfirmationCard` + `FoodItemSliderView` | 餐食确认和份量滑块专属 |
| `BowelTrackerCard` | 排便记录专属 |
| `BodyTrendStrip` | 体重趋势条专属 |
| `AIMealIdentificationConfirmationView` | 食物识别确认专属 |
| `DrinkExtractorView` 插件 | 饮品成分表识别专属 |
| `HealthKitService` 集成 | 健康 App 专属（其他 App 可能不需要） |
| `WaterLog` 撤销机制 | 饮水专属 |
| 营养素可空设计（`Double?`） | 营养数据特有 |

### 5.3 与现有文档的差异和补充

#### 对 `APP_FAMILY_CONTEXT.md` 的补充

1. **设计令牌已实现**：§4 "Shared UI Language" 提到的 "stronger shared typography system" 和 "clear borders and sectioning" 已在 1Life 中通过 `FamilyUI` 枚举落地，建议家族其他 App 直接复制 `Extensions.swift` 中的 `FamilyUI` / `AppSpacing` / `AppCornerRadius` 定义。

2. **TabBar 已实现 V2 方向**：§3 "Navigation" 提到 "center tab is always AI"，1Life 的自定义 `AppTabBar` 已实现"设备底栏"感（高反差反色块 + 分割线），建议家族统一采用此实现而非系统 `TabView`。

3. **Onboarding 组件已标准化**：§5 "Onboarding Spec" 提到的 "same page rhythm / button treatment / progress behavior" 已由 `OnboardingComponents.swift` 落地，其他 App 可直接复用这些组件。

4. **Haptics 已实现**：§8 "Haptics Spec" 的 tap/success/warning 三级已在 `HapticEngine` 中落地，并额外增加了 `SoundEngine`（系统确认音），这是对家族规范的增强。

5. **Avatar 已对齐**：§4 "Avatar Spec" 的 4 级回退已在 `UserAvatarView` 中实现，但 1Life 的头像圆角使用 `size * 0.28`（圆角矩形）而非圆形，这与家族规范描述的"clipped to circle"有差异——**建议家族统一更新为圆角矩形**，更符合 V2 的"轻圆角面板"方向。

#### 对 `UI_STYLE_GUIDE_V2.md` 的补充

1. **具体色值已确定**：V2 文档只给出"建议方向"，1Life 已确定具体色值（`#1e4ed8` accent、`#2f7a63` success、`#f4f1eb` 暖纸白等），建议家族采纳。

2. **组件已抽取**：V2 §12.1 建议抽出的 `SystemPanel`、`SystemSectionLabel`（对应 `SectionHeader`）、`MetricValueText`（对应 `MetricStrip`）、`RecordRow`（对应 `FoodItemRow`）、`StatusTag`（对应 `SystemStatusBadge`）、`SystemToolbarHeader`（对应 `AIConfigurationHeader`）均已实现。

3. **动画时长已标准化**：V2 §8 提到"短、准、收得快"，1Life 已确定具体时长（Tab 0.22s、横幅 spring 0.35、面板展开 0.25s），建议家族采纳。

4. **优先重构顺序已验证**：V2 §11 建议的顺序（Settings → Dashboard → Food Timeline → AI Chat → My Life）在 1Life 中已全部完成，验证了可行性。

5. **黑色主操作按钮**：V2 §7.6 提到"系统主操作：黑底白字"，1Life 已在发送按钮、添加一餐、确认记录、+ml 按钮中统一采用黑底白字，建议家族统一。

---

## 附录：文件路径速查

| 组件/模式 | 文件路径 |
|----------|---------|
| 设计令牌 | `1Life/Extensions.swift` |
| 通用组件 | `1Life/Components/*.swift` |
| Tab 定义 | `1Life/App/AppTab.swift` |
| 入口 | `1Life/OneLifeApp.swift` |
| 根视图 | `1Life/ContentView.swift` |
| 全局状态 | `1Life/ViewModels/AppViewModel.swift` |
| Dashboard | `1Life/Views/Dashboard/DashboardView.swift` |
| 饮食页 | `1Life/Views/Food/FoodTimelineView.swift` |
| 餐卡 | `1Life/Views/Food/MealCardView.swift` |
| 食物行 | `1Life/Views/Food/FoodItemRow.swift` |
| AI 聊天 | `1Life/Views/AIChat/AIChatView.swift` |
| AI 组件 | `1Life/Views/AIChat/AIChatComponents.swift` |
| AI 确认卡 | `1Life/Views/AIChat/AIChatMealReviewComponents.swift` |
| 回顾页 | `1Life/Views/MyLife/MyLifeView.swift` |
| 习惯追踪 | `1Life/Views/MyLife/HabitTrackerView.swift` |
| 设置页 | `1Life/Views/Settings/SettingsView.swift` |
| Onboarding | `1Life/Views/Onboarding/OnboardingView.swift` |
| Onboarding 组件 | `1Life/Views/Onboarding/OnboardingComponents.swift` |
| Splash | `1Life/Views/Splash/SplashView.swift` |

---

*本文档基于 1Life 完整代码库提炼，可作为家族其他 App 的审查与复用基准。*
