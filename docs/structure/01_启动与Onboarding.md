# 1Life 结构文档 01：启动与 Onboarding

> 系列文档共 6 篇，本篇是第 1 篇。后续 5 篇按 Tab 顺序展开：
> 02 Dashboard(今日) · 03 饮食 · 04 AI · 05 回顾(MyLife) · 06 设置
>
> 另有 [00_总览与跨Tab模式索引.md](00_总览与跨Tab模式索引.md)：01-06 每篇都是逐面板逐按钮的精确记录，查具体某个界面用哪篇；想知道"这个模式全 App 是不是都这样"、或者要把某个模式复制到其它 App，先看 00 篇的跨 Tab 提炼。

## 0. 文档说明

**方法论**：本文档里的每一条结论都对应到具体 Swift 源码，可以按文件路径+行号直接核对。凡是标注【推断】的地方，代表这是纯视觉/手感效果（比如动画的实际观感、弹簧曲线的松紧程度），我没有用模拟器跑过，只是根据代码里的 `.animation`/`.transition`/数值参数做的合理推断——不是我亲眼验证过的结果。没有标注的地方，代表是直接读取代码后确认的事实（比如某个按钮存在、某个字段的取值范围、某个分支的触发条件）。

**范围**：本篇覆盖从「用户点击 App 图标」到「Onboarding 完成、进入主 Tab 界面」之间的完整链路，包括：
- App 图标资源
- 启动动画（SplashView）
- App 根节点的数据初始化与首次/非首次启动分支（`OneLifeApp` / `ContentView`）
- Onboarding 全部 10 个状态（Welcome → Language → Preset → Profile → BodyParams → DietGoal → CalorieTarget → Reminder → AIConfig → Complete）

**涉及文件清单**：

```text
1Life/OneLifeApp.swift                          App 入口，@main，ModelContainer 注册
1Life/ContentView.swift                          根视图，Onboarding/主界面分支，TabBar，DaySelectorView
1Life/Views/Splash/SplashView.swift               启动动画
1Life/Repository/SeedData.swift                   首次启动的默认数据写入
1Life/Views/Onboarding/OnboardingView.swift        Onboarding 状态机容器，10 个 case 的路由与数据落盘
1Life/Views/Onboarding/OnboardingSteps.swift       10 个步骤各自的实际界面（720 行）
1Life/Views/Onboarding/OnboardingComponents.swift  Onboarding 专用共享组件（Header/BottomBar/IconBox/NextButton 等）
1Life/Views/Onboarding/OnboardingPreset.swift      Step 2「初始方案」的 5 个预设枚举
1Life/App/AppTab.swift                             5 个 Tab 的定义（本篇引用，02-06 篇会展开每个 Tab）
1Life/Extensions.swift                             FamilyUI 设计 token、AppTypography、HapticEngine（本篇引用一次，后续 5 篇不再重复解释）
1Life/Assets.xcassets/AppIcon.appiconset           App 图标
1Life/Assets.xcassets/SplashAppIcon.imageset       启动页图标（区分浅色/深色两张位图）
```

---

## 1. App 图标

`Assets.xcassets/AppIcon.appiconset`——标准 iOS App 图标资源目录，是用户在主屏幕上点击进入 App 的入口图标。

启动动画里用的不是这个 `AppIcon`，而是单独的 `SplashAppIcon.imageset`，内含 `SplashAppIcon.png`（浅色）和 `SplashAppIcon-Dark.png`（深色）两张位图，跟随系统外观自动切换——这是两套独立维护的图片资源，改 App 图标不会自动带动启动页图标一起变，反之亦然。【这一点是从资源目录结构直接确认的事实，不是推断】

---

## 2. 冷启动流程

### 2.1 App 入口：`OneLifeApp.swift`

```swift
@main
struct OneLifeApp: App {
    @State private var showSplash = true
    init() { AppTypography.configureGlobalAppearance() }
    ...
}
```

- `init()` 里第一件事是调用 `AppTypography.configureGlobalAppearance()`（`Extensions.swift:9-24`）——在任何界面渲染前，先把系统级的 `UINavigationBarAppearance`、`UITabBarItem` 字体外观改成圆体（`.rounded` design），这样全局的导航栏标题、Tab 文字才会统一是圆润字重，而不是系统默认的 San Francisco 直角字体。这一步是全局单次配置，不是每个页面单独设置的。
- `body` 是一个 `WindowGroup`，内部用 `ZStack` 叠了两层：底层永远是 `ContentView()`（挂了 `.appTypography()` modifier，即页面级再套一层 `.fontDesign(.rounded)`），上层是条件渲染的 `SplashView`，`showSplash` 为 `true` 时盖在最上面。
- `SplashView` 消失时用的是 `.transition(.opacity)` + 外部 `withAnimation(.easeInOut(duration: 0.5))` 包裹 `showSplash = false`——也就是启动页是淡出消失，不是位移或缩放退场。
- `.task { HealthKitService.shared.enableEnergyBackgroundDelivery() }` 挂在最外层 `WindowGroup` 上，App 启动时就注册 HealthKit 后台能量数据交付，不等用户走到需要健康数据的页面才注册。
- `.modelContainer(for: [...])` 注册了 15 个 SwiftData 模型：`AppSettings`、`NutritionGoal`、`Meal`、`FoodItem`、`UserFood`、`MealTemplate`、`WaterLog`、`BowelLog`、`Habit`、`HabitLog`、`JournalEntry`、`JournalPhoto`、`WorkoutLog`、`BodyMeasurement`、`AIChatMessage`、`DrinkRecord`。⚠️ 这里没有 `SupplementRecord`——补剂库模型是后来才加的（见站内信 2026-07-13 记录），如果没有同步补充进这个数组，补剂库的持久化会在运行时报错或静默失败，这是本篇核实时发现的一个需要你确认的点，不属于本文档范围内的功能描述，但值得提醒。
- 容器创建失败时是 `assertionFailure`（仅 Debug 生效），不是用户可见的错误提示。

### 2.2 启动动画：`SplashView.swift`

`SplashView` 接收三个参数：`appName`（这里固定传 `"1Life"`）、`iconName`（固定传 `"SplashAppIcon"`）、`onFinished` 回调。

视觉结构（从上到下）：
1. 背景铺满 `FamilyUI.pageBackground`（暖色调页面背景，浅色 `#f4f1eb`，深色 `#161410`）
2. 一个 132×132 的圆角卡片（`FamilyUI.panelBackground` 填充 + `FamilyUI.panelBorder` 描边 + `FamilyUI.panelCornerRadius`=12 圆角 + 黑色 8% 透明度阴影，`radius:18, y:12`），里面居中放 92×92 的 App 图标图片，图标自身再裁一次 18pt 圆角
3. 图标下方 16pt 间距，是 App 名称（34pt 圆体 black 字重）+ 副标题「营养、习惯与身体回顾」（`.subheadline.weight(.semibold)`，次要色）

动画时序（`animate()` 方法）：
- 图标：`withAnimation(.spring(response: 0.6, dampingFraction: 0.7))`，同时驱动 `logoScale`（0.7→1.0）、`logoOpacity`（0→1）、`panelOffset`（18→0，即整个卡片+文字组从下方 18pt 处回弹到位）。dampingFraction 0.7 意味着有轻微回弹感，不是线性淡入。【回弹手感是推断，数值本身是事实】
- 文字：延迟 0.3 秒后，用 `.easeOut(duration: 0.4)` 单独淡入 `textOpacity`（0→1）——文字比图标晚 0.3 秒开始出现，制造图标先到位、文字再补上的先后节奏。
- 整个启动页在 `.onAppear` 触发动画后，用 `DispatchQueue.main.asyncAfter(deadline: .now() + 1.8)` 硬编码延迟 1.8 秒后调用 `onFinished()`——也就是不管动画本身多快播完，启动页固定停留 1.8 秒才开始淡出。加上 `OneLifeApp` 里淡出动画本身的 0.5 秒，用户从点击图标到看到主界面的启动页占用时间大约是 **1.8~2.3 秒**（不含系统冷启动本身的加载时间）。

### 2.3 根视图分支逻辑：`ContentView.swift`

`ContentView` 用 `@Query private var settings: [AppSettings]` 读取本地唯一的设置记录（理论上全局只有一条），分三种情况渲染：

```swift
if let s = settings.first {
    if s.hasCompletedOnboarding { mainTabView }
    else { OnboardingView(settings: s) }
} else {
    FamilyUI.pageBackground.ignoresSafeArea()   // 数据尚未加载完成的过渡态
}
```

- **数据尚未加载完成**（`settings` 为空数组，SwiftData 还没来得及在 `.onAppear` 里插入默认记录）：只显示一块纯色背景，没有 loading 指示器或文字提示。
- **首次启动 / 未完成引导**（`hasCompletedOnboarding == false`）：进入 `OnboardingView`。
- **已完成引导**：进入 `mainTabView`（5 个 Tab 的主界面，02-06 篇详细展开）。

`.onAppear` 里做的初始化工作（`SeedData.installDefaultsIfNeeded` / `installDefaultNutritionGoalIfNeeded`，`Repository/SeedData.swift:6-22`）：
- 如果 `settings` 为空，插入一条 `AppSettings(hasCompletedOnboarding: false)` 的新记录——这是「数据尚未加载完成」状态转向「首次启动」状态的触发点，本质是异步的：第一帧渲染时 `settings` 还是空的，短暂显示纯色背景，`.onAppear` 里插入记录后 SwiftData 的 `@Query` 会自动刷新，视图重新渲染进入 Onboarding。
- 如果 `nutritionGoals` 为空，插入一条默认的 `NutritionGoal()`。
- 保存 `modelContext`，注册通知导航处理器（`NotificationManager.shared.registerNavigationHandler`，让推送点击能直接跳到指定 Tab）、重新调度提醒通知、应用触感/音效偏好设置。

`ContentView` 本身还挂了两个全局 modifier：`.appSwitchStyle()`（全局 Toggle 外观统一成家族自定义样式）和 `.dismissKeyboardOnTap()`（点击空白处收起键盘），以及一个全局错误 Toast 的 `.overlay(alignment: .top)`（`GlobalBannerCenter.shared` 驱动的 `AppErrorBanner`）——这两者是整个 App 唯一的全局注册点，02-06 篇不会再重复出现「怎么挂载」的说明，只会说「用了这个机制」。

**主界面 `mainTabView`**（`ContentView.swift:59-82`，本篇只做骨架说明，Tab 内部内容见 02-06 篇）：
- 用 `ZStack(alignment: .bottom)` 叠放「当前选中 Tab 的页面」和悬浮在底部的自定义 `AppTabBar`
- 页面内容区域整体 `.padding(.bottom, 64)`，给底部 TabBar 让出空间
- 通过 `appViewModel.selectedTab`（`switch` 语句）决定渲染 `DashboardView()` / `FoodTimelineView()` / `AIChatView(onOpenSettings:)` / `MyLifeView()` / `SettingsView()` 五者之一——**同一时间只有一个 Tab 的页面被创建在视图树里，切 Tab 时旧页面会被销毁重建，不是 iOS 原生 `TabView` 那种五个页面同时保留状态的机制**。这意味着比如在「饮食」Tab 滚动到某个位置，切去别的 Tab 再切回来，滚动位置不会保留。
- `AppTabBar` 是私有组件（`private struct AppTabBar`，仅 `ContentView.swift` 内可见），不是系统 `TabView`：5 个等宽按钮用 `HStack(spacing: 6)` 排列，每个按钮是 SF Symbol 图标（16pt bold）+ 10pt bold 文字上下堆叠，选中态背景 `FamilyUI.accent`（纯色块，非选中态是 `FamilyUI.panelMutedBackground`），点击时 `HapticEngine.tap()` + `withAnimation(.snappy(duration: 0.22))` 做选中态切换动画。整个 TabBar 容器背景是 `FamilyUI.panelBackground`，顶部有 1pt 分割线（`FamilyUI.panelBorder`），`.ignoresSafeArea(edges: .bottom)` 让背景延伸到 Home Indicator 下方。

同文件内还定义了 `DaySelectorView`（`ContentView.swift:133-202`）和 `DatePickerSheet`（`ContentView.swift:204-229`）——这是一个可复用的「按天翻页」组件（左箭头/日期文字按钮/右箭头，右箭头到今天就 disabled），点击日期文字会弹出一个 340pt 高的 `.sheet` 呈现系统 `DatePicker(.graphical)` 选日期。这个组件被 Dashboard 和饮食 Tab 复用（02、03 篇会看到它的实际使用位置），本篇只说明它定义在根文件里这一结构事实。

---

## 3. Onboarding 全流程

### 3.1 容器与状态机：`OnboardingView.swift`

`OnboardingView` 是一个纯状态机容器：`@State private var step = 0`，`body` 用 `switch step` 路由到 10 个具体步骤视图之一（`case 0...8` 各对应一个具名 Step，`default` 落到 `CompleteStep`，即 `step == 9`）。

**关键实现特点**：
- 所有 Onboarding 期间收集的数据（语言、预设、昵称头像、身体参数、饮食目标、热量目标、提醒时间、AI 配置）都用 `@State` 暂存在 `OnboardingView` 这一层，**不会边填边写入 SwiftData**，只有走到最后 `complete()`（AI 步骤点「完成」或「跳过」触发）才一次性把所有字段落盘到 `settings`（`AppSettings` 的 `@Bindable` 引用）和新建/更新一条 `NutritionGoal`。这意味着用户中途退出 App（比如被系统杀掉进程），已经填的数据会丢失，重新打开会从 Welcome 重新开始——因为 `hasCompletedOnboarding` 只有走到 `markDone()`（`CompleteStep` 点「开始记录」）才会置 `true`。
- 页面切换动画：`.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))` + `.id(step)` + 外层 `.animation(.easeInOut(duration: 0.22), value: step)`——前进时新页面从右侧滑入，后退时（`back()` 让 `step -= 1`）同一套 transition 会让页面从左侧滑入（因为 `.id(step)` 变化触发的是同一个 insertion 动画，视觉上后退和前进用的是同一种滑动方向逻辑，不是反向定制的动画）。【滑动的实际观感是推断，transition 类型和触发条件是事实】
- `next()`/`back()` 分别是 `step += 1` / `step -= 1`，没有任何步骤校验拦截——除了 UI 层面按钮的 `isEnabled` 条件（比如 AI Key 为空时「完成」按钮本身是 disabled 的），状态机本身不阻止越界跳转。
- Onboarding 期间如果 AI 配置保存失败，会在 `ZStack` 最上层叠一个 `AppErrorBanner`（不是复用全局 `GlobalBannerCenter`，是 `OnboardingView` 自己 `@State private var aiConfigError` 驱动的局部 Banner）。

### 3.2 Onboarding 专用组件库：`OnboardingComponents.swift`

10 个步骤共享这一套私有组件体系，都不是家族级共享组件（`SystemPanel`/`AppSettingsRow` 等在其它 Tab 广泛复用，但下面这几个是 Onboarding 专属）：

| 组件 | 作用 | 关键实现细节 |
|---|---|---|
| `OnboardingHeader` | 每个非首尾步骤顶部的进度头 | 左上角 36×36 圆角返回按钮（`chevron.left`）+ 居中 `SystemStatusBadge(text: "STEP x / 8")` + 右侧等宽留白（保持标题真正居中）；下方是自绘 4pt 高进度条（`GeometryReader` 手工计算宽度比例，`FamilyUI.accent` 填充在 `FamilyUI.divider` 轨道上，`total` 固定写死为 8） |
| `OnboardingPageHeader` | 页面内容区的大标题 | eyebrow(11pt 全大写风格)+32pt black 大标题+副标题三段式，与家族 `SystemPageHeader` 视觉几乎一致但是本地重新实现的一份 |
| `OnboardingBottomBar` | 底部固定操作区容器 | 泛型 `Content: View`，背景 `FamilyUI.panelBackground` + 顶部 1pt 分割线，`.ignoresSafeArea(edges: .bottom)`；底部 padding 高达 28pt（给 Home Indicator 留足空间） |
| `OnboardingIconBox` | 34×34 圆角图标盒 | 和家族 `FamilyUI.iconBoxSize` 数值一致，描边+填充逻辑与其它 Tab 的图标盒手法相同 |
| `OnboardingNextButton` | 主操作按钮（黑体大按钮） | 高度 `.padding(.vertical, 14)`，禁用态背景变 `Color(.systemGray4)`，启用态是 `FamilyUI.accent`，统一带黑色 18% 描边 |
| `OnboardingSecondaryButton` | 次要操作（「跳过」类文字按钮） | 纯文字，次要色，不是描边按钮 |
| `OnboardingMetricInput` | 数值输入行（年龄/身高/体重） | 标签+右对齐输入框+单位三段，键盘默认 `.numberPad` |
| `OnboardingValueRow` / `SummaryRow` | 只读的「图标+标题+值」展示行 | 用于 `CompleteStep` 汇总页 |
| `OptionRow` | 单选列表项容器 | 选中态用 `FamilyUI.accent.opacity(0.10)` 背景+纯色描边+右侧 `checkmark.square.fill`，泛型 content 承载各步骤不同的行内容 |

### 3.3 逐步骤详解

以下按 `step` 数值顺序展开，每步都标注「从哪一步能到达」「按了按钮之后去哪」。

---

#### Step 0 · Welcome（欢迎页）

- **入口**：Onboarding 状态机的初始值，即 `OnboardingView` 首次渲染直接显示这一步，无法从别的入口进入。
- **退出**：只有一个方向——点底部主按钮进入 Step 1，**没有返回按钮**（也没有 `OnboardingHeader` 进度条，因为这一步在设计上被当作品牌欢迎页，不计入 8 步进度）。
- **视觉结构**：`ScrollView` 包裹 `SystemPageHeader`（eyebrow「WELCOME TO」，标题「1Life」，副标题「把饮食、身体、训练和习惯放到同一个清晰系统里。」）+ 两个 `SystemPanel`：
  - 「CORE WORKFLOW」面板：3 条 `FeaturePoint`（图标+一句话），中间用 `SystemPanelDivider` 分隔——拍照识别营养、摄入消耗对比、围绕训练日调整营养
  - 「HEALTH NOTICE」面板：一段免责声明文字——「1Life 不构成医疗、诊断或专业营养建议」
- **按钮**：底部 `OnboardingBottomBar` 内只有一个 `OnboardingNextButton(title: "开始设置")`，下方附一行小字「继续即表示同意服务条款和隐私政策」（纯文字，不可点击，没有链接跳转）。
- **代码位置**：`OnboardingSteps.swift:6-62`（`WelcomeStep` + 私有 `FeaturePoint` 行组件）

---

#### Step 1 · Language（语言）

- **入口**：Step 0 点「开始设置」
- **退出**：左上角返回箭头回 Step 0；底部「下一步」进 Step 2
- **视觉结构**：`OnboardingHeader(stepNum: 1)` + `OnboardingPageHeader`（eyebrow「LANGUAGE」）+ 一个 `SystemPanel(title: "LANGUAGE OPTIONS")`，内含 3 个 `OptionRow`
- **按钮/交互点**：
  - 3 个语言选项，逐行是「双字母代码方块(40×40) + 语言名」：`sys`/跟随系统、`CN`/简体中文、`EN`/English，点击即选中（`HapticEngine.tap()` + 立即更新 `selected`，不需要额外确认）
  - 底部「下一步」按钮**始终可点击**（没有校验必须选择，因为默认值已经是 `.system`）
- **数据**：`@State private var selectedLanguage: AppLanguage = .system`，选完不会立即生效到 App 语言（App 目前没有观察到运行时切换语言的机制），只会在 Step 8 完成时写入 `settings.languageRaw`
- **代码位置**：`OnboardingSteps.swift:66-124`

---

#### Step 2 · Preset（初始方案）

- **入口**：Step 1「下一步」
- **退出**：返回 Step 1；「套用并继续」进 Step 3，点击时会先调用 `applyPreset(selectedPreset)` 把预设值写进后续步骤的默认状态，再 `next()`
- **视觉结构**：`OnboardingPageHeader`（eyebrow「STARTING POINT」，说明「1Life 会预设饮食目标、饮水目标、训练目标和提醒节奏」）+ `SystemPanel(title: "PRESETS", detail: "后续都可以在设置中修改")`，内含 5 个 `OptionRow`
- **5 个预设选项**（`OnboardingPreset.swift`）：

  | 预设 | 图标 | 一句话说明 | 饮食目标映射 | 蛋白策略 | 饮水目标 | 每周训练 | 提醒时间 |
  |---|---|---|---|---|---|---|---|
  | 均衡记录 | `leaf.fill` | 稳定记录三餐、饮水、体重和日常习惯 | balanced | 按宏量比例×1.2 | 2000ml | 3次/150分钟 | 8/12/19 |
  | 减脂执行 | `flame.fill` | 轻热量缺口、高蛋白、称重和运动提醒 | fatLoss | 按体重×1.8 | 2200ml | 4次/180分钟 | 8/12/19 |
  | 增肌训练 | `figure.strengthtraining.traditional` | 训练优先、更多蛋白和更高热量目标 | muscleGain | 按体重×2.0 | 2600ml | 5次/240分钟 | 8/13/20 |
  | 控糖饮食 | `drop.fill` | 关注碳水、糖、饮水和餐后习惯 | balanced | 按宏量比例×1.2 | 2200ml | 3次/180分钟 | 8/12/19 |
  | 从空白开始 | `slider.horizontal.3` | 不套用推荐，按自己的节奏配置 | balanced | 按宏量比例×1.2 | 2000ml | 3次/150分钟 | 8/12/19 |

  这张表本身就是 Step 5（饮食目标）、Step 6（热量目标）、Step 7（提醒）三步的**默认值来源**——选完预设，后续三步不是空白表单，而是已经预填好推荐值，用户可以直接「下一步」跳过，也可以进去改。这是 Onboarding 里唯一一处「一步影响多步默认值」的设计。
- **代码位置**：`OnboardingSteps.swift:128-178`，预设数据 `OnboardingPreset.swift` 全文件

---

#### Step 3 · Profile（个人资料）

- **入口**：Step 2「套用并继续」
- **退出**：返回 Step 2；「下一步」进 Step 4（**无跳过选项**，但昵称和头像本身都允许留空，因为「下一步」按钮没有 disabled 校验）
- **视觉结构**：`OnboardingPageHeader`（eyebrow「PROFILE」）+ `SystemPanel(title: "IDENTITY", detail: "头像和昵称只保存在本机")`
- **按钮/交互点**：
  - 居中的头像区：`PhotosPicker(selection:matching:.images)` 包裹 `UserAvatarView(avatarData:name:size:96)`，右下角叠一个 30×30 黑色圆角方块相机图标徽标（`camera.fill`，白色图标）——点击整个头像区域触发系统相册选择器
  - **`UserAvatarView` 的兜底渲染**（2026-07-14 更新为渐变版本）：没有头像图片、但已经填了昵称时，不再是纯色占位块，而是取昵称前两个字符做首字母缩写，铺在一个左上到右下的蓝紫渐变（`#1e4ed8`→`#6650a4`）方块上；昵称也为空时才退回灰底人形图标占位——这个组件在 06 篇（设置页个人资料）复用的是同一份实现
  - 选完图片后 `.onChange(of: selectedItem)` 异步 `loadTransferable(type: Data.self)` 读取原始 Data 直接赋给 `avatarData`，**没有裁剪环节**，也没有压缩（对比其它模块用 `ImageService.compress`，这里是唯一一处未压缩直接存原图 Data 的头像录入路径）
  - 下方是昵称输入框（`TextField`，`.textInputAutocapitalization(.never)` + `.autocorrectionDisabled()`）
- **代码位置**：`OnboardingSteps.swift:182-254`

---

#### Step 4 · BodyParams（身体参数）

- **入口**：Step 3「下一步」
- **退出**：返回 Step 3；「下一步」和「跳过」都进 Step 5（`onNext`/`onSkip` 两个回调在 `OnboardingView.swift` 里其实都指向同一个 `next` 函数——即这一步的「跳过」和「下一步」在行为上完全等价，唯一区别是文案给用户的心理暗示不同）
- **视觉结构**：两个面板——
  - 「BASIC DATA」（detail：「可以跳过，之后从设置或 Apple Health 同步」）：性别双选按钮（男/女等宽并排，选中态纯色填充）+ 年龄/身高/体重三个 `OnboardingMetricInput` 数值输入行，中间用 `SystemPanelDivider` 分隔
  - 「ACTIVITY LEVEL」：`ActivityLevel.allCases` 逐条 `OptionRow`
- **按钮/交互点**：性别按钮、3 个数值输入框（数字键盘）、活动水平单选、底部「下一步」+「跳过」两个按钮并排（`OnboardingNextButton` + `OnboardingSecondaryButton`，这是 10 步里第一次出现双按钮布局）
- **代码位置**：`OnboardingSteps.swift:258-351`；`.scrollDismissesKeyboard(.interactively)` 用于数字键盘弹出时手势收起

---

#### Step 5 · DietGoal（饮食目标）

- **入口**：Step 4「下一步」或「跳过」
- **退出**：返回 Step 4；「下一步」进 Step 6，触发条件里有个隐藏逻辑：如果 `calorieText` 此时为空，会先把 `calorieText` 设为 `Int(recommendedCalories)`（即用当前饮食目标模式算出的推荐热量预填进下一步）
- **视觉结构**：`SystemPanel(title: "GOAL MODE")` 内 4 个 `OptionRow`（`DietGoalMode.allCases`：减脂/增肌/维持/均衡饮食），每行显示模式名+「推荐 X kcal/天」（只有 `estimatedTDEE` 算得出时才显示推荐值，即依赖 Step 4 是否填了身体参数——如果 Step 4 跳过了，这里就不显示推荐热量文字，但选项本身仍可选）
- **代码位置**：`OnboardingSteps.swift:355-406`

---

#### Step 6 · CalorieTarget（每日热量目标）

- **入口**：Step 5「下一步」
- **退出**：返回 Step 5；「下一步」进 Step 7
- **视觉结构**：
  - 「DAILY CALORIES」面板：一个大号（46pt black）可编辑数字输入框，placeholder 是推荐值本身，右侧跟着「kcal」单位文字
  - 「MACRO TARGETS」面板：实时根据当前 `calorieText`（或推荐值兜底）算出的蛋白/碳水/脂肪三行 `MacroRow`（色块+名称+克数，蓝/橙/黄三色区分）——**这是 Onboarding 里唯一一处输入即时驱动下方计算结果刷新的步骤**，宏量营养素计算走的是 `AppSettings.recommendedMacroTargets(calories:weightKg:dietGoalMode:proteinTargetStrategy:proteinTargetMultiplier:)` 静态方法，和 Step 2 预设的蛋白策略挂钩
- **代码位置**：`OnboardingSteps.swift:410-500`

---

#### Step 7 · Reminder（提醒节奏）

- **入口**：Step 6「下一步」
- **退出**：返回 Step 6；「下一步」进 Step 8
- **视觉结构**：`SystemPanel(title: "MEAL REMINDERS")` 内 3 行 `ReminderRow`（早/午/晚餐，`sunrise.fill`/`sun.max.fill`/`moon.fill` 三个不同图标，统一橙色调）
- **按钮/交互点**：每行右侧是「系统 `DatePicker(.hourAndMinute)` 内联时间选择器（仅当该餐开关打开时才显示）+ 独立 `Toggle` 开关」——**这是 Onboarding 里唯一使用系统原生 `Toggle` 而非家族 `AppSwitchStyle` 的地方**（因为 Onboarding 阶段 `.appSwitchStyle()` 还没挂载到这棵视图树上，那是 `ContentView` 层级才有的全局 modifier，Onboarding 独立于 `ContentView` 渲染，所以 Onboarding 内的原生控件都是系统默认外观，不是家族定制外观——这一条适用于本篇提到的所有 `Toggle`/`DatePicker`/`Picker`）
- **代码位置**：`OnboardingSteps.swift:504-588`

---

#### Step 8 · AIConfig（AI 配置）

- **入口**：Step 7「下一步」
- **退出**：返回 Step 6【原文如此，`onBack` 回调实际调用的是 `back()` 通用函数，行为是 `step -= 1`，所以真实退回目标是 Step 7，上面写「返回 Step 6」是笔误，应为返回 Step 7】；「完成」或「跳过，稍后设置」都进入 Step 9（`CompleteStep`）
- **视觉结构**：三个面板——
  - 「AI PROVIDER」：`Picker(.menu)` 下拉选择服务商（`AIProvider.allCases`）
  - 「API KEY」（detail：「Key 会保存到 iOS Keychain」）：`SecureField` 密文输入框
  - 「MODEL CAPABILITY」：根据当前选中服务商的默认模型，实时显示「支持拍照识别」或「不支持拍照识别」（图标+文字+右侧模型名徽标），调用 `selectedProvider.supportsVision(model:)` 判断
- **按钮/交互点**：
  - 底部「完成」按钮 **`isEnabled: !apiKeyText.isEmpty`**——这是 10 步里少数几个有真实禁用校验的主按钮（必须填了 Key 才能点「完成」）
  - 「跳过，稍后设置」次要按钮**任何时候都可点**，跳过时 `settings.isAIConfigured = false` 直接进入完成页，不保存任何 Key
  - 点「完成」触发 `saveAIConfig()`：trim 后校验非空 → 写入 `settings.selectedAIProviderRaw`/`selectedAIModel` → 调用 `LocalAIConfigurationService().saveAPIKey(_:provider:)` 存入 Keychain → 成功则 `settings.isAIConfigured = true` 并调用 `complete()`；失败则弹出局部 `AppErrorBanner`「保存 API Key 失败，请稍后在设置中配置」，**不会**阻止用户之后重试或跳过
- **代码位置**：`OnboardingSteps.swift:592-665`

---

#### Step 9 · Complete（完成汇总页，`default` 分支）

- **入口**：Step 8「完成」（先经过 `complete()` 落盘所有数据）或「跳过」
- **退出**：唯一按钮「开始记录」，点击触发 `markDone()`——`HapticEngine.success()` + `settings.hasCompletedOnboarding = true` + 请求通知权限（`NotificationManager.shared.requestPermission()`）+ 重新调度提醒。这一步执行完，`ContentView` 的 `@Query` 感知到 `hasCompletedOnboarding` 变化，自动切换渲染到 `mainTabView`——**没有额外的页面跳转代码，完全靠 SwiftData 的响应式刷新完成从 Onboarding 到主界面的切换**
- **视觉结构**：无进度头（和 Step 0 一样，首尾两步都不显示 `OnboardingHeader`）。`SystemPageHeader`（eyebrow「READY」，标题「设置完成」）+ `SystemPanel(title: "YOUR SETUP")` 汇总卡片：
  - 头像（36pt）+「个人资料」+ 昵称（为空则显示「用户」兜底文案）
  - `SummaryRow`：饮食目标名称、每日热量目标、提醒节奏摘要（`reminderSummary` 计算属性，格式如「早8:00 · 午12:00 · 晚19:00」，全部关闭则显示「未开启」）
- **代码位置**：`OnboardingSteps.swift:669-719`；落盘逻辑在 `OnboardingView.swift:207-256`（`complete()` + `markDone()`）

---

## 4. 完整数据落盘清单（`complete()` 函数）

这是 Onboarding 唯一一次批量写入的时刻（`OnboardingView.swift:207-248`），按字段列出对应关系，方便核对某个 Onboarding 步骤到底影响了 `AppSettings` 的哪些字段：

| 写入字段 | 来源 Step |
|---|---|
| `languageRaw` | Step 1 |
| `nickname`, `avatarImageData` | Step 3 |
| `dietGoalModeRaw` | Step 5 |
| `proteinTargetStrategyRaw`, `proteinTargetMultiplier` | Step 2（预设） |
| `genderRaw`, `age`, `heightCm`, `weightKg`, `activityLevelRaw` | Step 4 |
| `dailyWaterGoalMl`, `weeklyWorkoutTargetCount/Minutes` | Step 2（预设） |
| `isBreakfastReminderEnabled/Hour`（午/晚同理） | Step 7 |
| 新建或更新一条 `NutritionGoal`（当日 `effectiveDate`） | Step 6 计算结果 |
| `selectedAIProviderRaw`, `selectedAIModel`, `isAIConfigured`, Keychain 中的 API Key | Step 8 |
| `hasCompletedOnboarding = true` | Step 9「开始记录」触发 |

---

## 5. 值得注意的实现特点

1. **状态全暂存到完成才落盘**：详见 3.1，中途被杀进程会丢失全部已填数据，需要重新走一遍。
2. **Step 2 预设是唯一的「一对多默认值」入口**：选完预设后 Step 5/6/7 都是已经预填好的表单，而不是空白表单，用户体验上是「先给一个合理默认值，再允许精调」，不是「从零开始问」。
3. **首尾两步（Welcome / Complete）没有进度条**，中间 8 步才有 `OnboardingHeader` 的 `STEP x/8` 徽标——刻意把「品牌欢迎」和「完成汇总」从进度感知里摘出去，让用户不会觉得「填了 10 步」，心理上是「填了 8 步」。
4. **AI 配置是唯一带真实禁用校验的主按钮**：其余步骤的「下一步」全程可点，不强制用户填写任何数据（性别、体重、提醒时间都可以整页跳过），只有 API Key 输入这一步做了非空校验，体现产品在「尽快让用户进入 App」和「AI 功能需要 Key 才能用」之间的取舍。
5. **Onboarding 独立于 `ContentView` 的全局 modifier 树**：`.appSwitchStyle()`/`.dismissKeyboardOnTap()` 挂在 `ContentView` 顶层，而 `OnboardingView` 是 `ContentView` 内部按条件渲染出来的兄弟分支，不是被 `ContentView` 包裹渲染——这带来一个实际后果：Onboarding 内的原生控件（Step 7 的 `Toggle`、Step 8 的 `Picker(.menu)`）都是**系统默认外观**，不是家族定制过的 `AppSwitchStyle`。这是本篇核实中发现的一处「视觉规范未覆盖到 Onboarding」的空隙，供你判断是否需要修。
6. **头像未压缩直接存储**：Step 3 选完图片后 `avatarData` 直接等于 `PhotosPickerItem` 读出的原始 Data，没有经过 `ImageService.compress` 处理——对比其它模块（比如饮品/补剂识别插件的图片输入）都会先压缩到长边 1024px、JPEG 0.7 质量再使用，Onboarding 头像这里是例外。

---

## 6. 可复制性 / 迁移建议（给 1Track / 1Pet / 1Day / 1Parcel 的参考）

- **`SplashView` 的实现（图标卡片+弹簧动画+延迟文字淡入+固定停留时长）是完全通用、无营养领域耦合的组件**，理论上可以原样复制到其它 App，只需换 `appName`/`iconName` 两个参数。1Life 用 1.8 秒固定停留，如果其它 App 已经用了不同时长，建议家族层面统一决定一个标准值，而不是各自设置不同的数字。
- **`OnboardingHeader`/`OnboardingBottomBar`/`OnboardingNextButton`/`OptionRow` 这套 Onboarding 专用组件是完全通用的骨架**，不含任何营养业务逻辑，是「可以直接抄」的那一类文件——这正是此前 1Pet 审查中发现的最大缺口（1Pet 的 Onboarding 完全没有复用这套骨架，是独立重写的一套居中大图标风格）。如果要往下一个 App 迁移，建议直接照抄 `OnboardingComponents.swift` 整个文件，只替换业务相关的 Step 内容。
- **Step 2「预设」这种「一步预填多步默认值」的模式值得作为家族级 Onboarding 设计模式**：不是每个 App 都需要 5 个预设，但「选一个大方向，后续步骤给出可编辑的合理默认值」这个思路本身对任何需要多参数配置的引导流程都适用（比如 1Track 的默认提醒偏好、1Day 的默认提醒时间，都可以用同样思路给一个「快速开始」预设）。
- **AI 配置步骤只做「服务商+Key」两个字段、不做模型选择/测试连接**，比家族标准的 `AIConfigurationSettingsView`（Settings 里的完整版）简化很多——这是 1Life 自己的简化实现，06 篇（设置 Tab）会展开对比完整版差在哪里。如果家族要统一 Onboarding 阶段的 AI 配置深度，需要先决定「引导阶段要不要也支持选模型/测连接」这个产品问题。
