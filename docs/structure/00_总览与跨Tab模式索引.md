# 1Life 结构文档 00：总览与跨 Tab 共性模式索引

> 这是系列文档的第 0 篇，写在 01-06 之后回补。01-06 每篇都是「从上到下逐面板、逐按钮」的精确记录，适合查具体某个界面怎么实现；但单独看某一篇容易忽略"同一种模式在别的 Tab 是怎么处理的"——本篇**不重复正文内容**，只做跨篇提炼和定位（file+section 指针），回答"这个模式在全 App 范围内到底一不一致"这一类问题。写给两种场景：(1) 要把某个模式复制到 1Track/1Pet/1Day/1Parcel 之前，先看这里有没有现成结论；(2) 想知道"这个交互全 App 是不是都这样"，先查这里再决定要不要翻源码。

---

## 1. 全局共享状态与深链接机制（`AppViewModel`）

`AppViewModel` 是唯一跨 5 个 Tab 共享的状态容器，挂在 `ContentView.mainTabView` 层级。目前已确认的共享字段：

| 字段 | 被谁写入 | 被谁读取 | 定位 |
|---|---|---|---|
| `selectedTab` | 任何一处「跳转到别的Tab」的按钮 | `ContentView.mainTabView` 的 switch 分支 | [01§2.3](01_启动与Onboarding.md) |
| `selectedDate` | Dashboard 的 `DaySelectorView` | Dashboard **和**饮食 Tab 共用同一个值 | [02§0](02_Tab1_Dashboard首页.md)／[03§0](03_Tab2_饮食.md) |
| `myLifeFocus`（enum: habits/workouts/journal） | Dashboard 的习惯/训练/日记摘要区块 | 回顾 Tab 的 `ScrollViewProxy` 定位滚动 | [02§2.8](02_Tab1_Dashboard首页.md)／[05§1](05_Tab4_回顾MyLife.md) |
| `foodFocusMealType` / `foodScrollMealType` | Dashboard 的餐食快照格子（分别对应"可补记"/"已记录"两种点击） | 饮食 Tab 的 `applyPendingFoodFocus` | [02§2.3](02_Tab1_Dashboard首页.md)／[03§2.9](03_Tab2_饮食.md) |

**统一规律**：全 App 没有一处是简单的 `selectedTab = .xxx`，凡是跳 Tab 都会先把"去了之后应该聚焦哪里"的语境状态写好，再切 Tab。这是唯一被 5 个 Tab 中的 3 个（Dashboard→饮食、Dashboard→回顾）验证过的强一致模式，建议作为家族级设计原则明确写下来。

身体数据卡、排便卡目前**没有**对应的 `myLifeFocus` case，说明这套深链目前只覆盖回顾 Tab 5 个子面板里的 3 个（[05§1](05_Tab4_回顾MyLife.md)）。

---

## 2. 视觉规范复用度

- **新增类"+"按钮**：34×34 黑色圆角方块（`Image(systemName:"plus")`，白色图标）是最高复用度的具名规格，出现在 Dashboard 之外的几乎每个"新增"入口——回顾 Tab 的身体数据卡/排便卡/习惯面板/日志面板/训练面板全部用同一规格（[05§2.3-2.7](05_Tab4_回顾MyLife.md)）。**唯一例外**：饮食 Tab 每个餐次分组标题栏右侧的"+"是 32×32（[03§2.10](03_Tab2_饮食.md)），比标准规格小 2pt，是一处未对齐的细节差异。
- **`SystemPanel`/`SystemPanelDivider`/`SystemStatusBadge`** 是唯一贯穿全部 5 个 Tab 的共享容器组件，Onboarding 也复用了它（[01§3.3](01_启动与Onboarding.md)）。**唯一整体不用卡片语言的是 AI Tab**——四段主结构裸露在滚动区域里，只有头部和输入区有描边容器感（[04§1](04_Tab3_AIChat.md)），这是刻意的"聊天 App 视觉语言"而非"卡片仪表盘"取舍，不是遗漏。
- **`iconBoxSize`=34** 这个家族级 token 在 Onboarding 有独立重实现的 `OnboardingIconBox`，数值对齐但代码不共享（[01§3.2](01_启动与Onboarding.md)）。

---

## 3. 颜色分级规则不统一（语义色 token vs 裸色）

这是目前发现的**跨面板重复次数最多的一处不一致**：

- Dashboard `heroCard`（环形进度、超标提示）：用 `FamilyUI.danger`/`FamilyUI.warning`/`FamilyUI.accent` 语义色 token（[02§2.2](02_Tab1_Dashboard首页.md)）
- Dashboard `nutritionDetailsSection`（营养素展开面板）：同一个文件里，用裸色 `.red`/`.green`/`.blue`（[02§2.4](02_Tab1_Dashboard首页.md)）
- 回顾 Tab 的能量趋势图颜色判断：又是另一套独立的 if-else 阈值判断（250kcal/120kcal 分界），虽然用了语义色 token 但阈值数字和 Dashboard 不是同一份（[05§2.2](05_Tab4_回顾MyLife.md)）

**结论**：目前没有一个统一的"数值偏离目标 → 颜色"计算函数，是至少 3 处独立实现、各自决定阈值和取色方式。如果要往其它 App 复制"进度条变色"这类交互，建议先在家族层面抽一个共享的颜色分级函数，而不是继续各自实现。

---

## 4. 反馈机制三分天下：`GlobalBannerCenter` / 内嵌文字 / 局部 Banner

| 机制 | 使用场景 | 定位 |
|---|---|---|
| `GlobalBannerCenter`（顶部滑入 Toast，全局单例） | AI Tab 三类错误（请求失败/配置异常/语音异常）；回顾 Tab 身体数据卡的保存/导入反馈 | [04§6](04_Tab3_AIChat.md)／[05§2.3](05_Tab4_回顾MyLife.md) |
| 内嵌文字（面板内直接显示错误/结果文字） | 饮食 Tab 批量添加/模板库的空数据提示；回顾 Tab 训练面板的 Apple Health 导入结果 | [03§2.4](03_Tab2_饮食.md)／[05§2.7](05_Tab4_回顾MyLife.md) |
| 局部 Banner（View 自己维护的 `@State` 驱动，不接全局单例） | Onboarding 的 AI 配置保存失败提示——因为 Onboarding 不在 `ContentView` 的 modifier 覆盖范围内，物理上够不到全局机制 | [01§3.1](01_启动与Onboarding.md) |

**同一个 Tab 内部也不统一**：回顾 Tab 身体数据卡用 Banner，紧邻的训练面板用内嵌文字，两处操作性质相同（都是 Apple Health 导入结果反馈）——这是本系列文档里唯一一处"同一 Tab 内两个相邻面板用不同反馈机制"的具体案例，已记入 [ROADMAP.md](../ROADMAP.md) 已知问题。

**结论**：反馈机制目前没有强制规范，是"哪个面板先写、当时顺手用了什么"的历史结果。建议后续统一收敛到 `GlobalBannerCenter`（Onboarding 因视图树位置特殊需要单独处理）。

---

## 5. 删除/写入类操作的风险处理五种形态

按"保护强度"从低到高排列，附具体出现位置：

1. **无任何确认，点击即落盘/删除**：饮食 Tab 的横滑推荐带、历史搜索结果一键添加、`MealCardView`"删除整餐"（[03§2.4](03_Tab2_饮食.md)／[03§2.11](03_Tab2_饮食.md)）——这是饮食 Tab 的**贯穿性**设计，全 Tab 没有一处写入/删除带确认。
2. **纯文案 disabled 拦截**（不算确认，是前置校验）：饮食 Tab 的"批量添加"/"模板库"入口在数据为空时禁用+Toast（[03§2.4](03_Tab2_饮食.md)）。
3. **二次确认 alert**：AI Tab 清空聊天记录（唯一一处）、回顾 Tab 的习惯归档/删除、日志删除、训练删除（[04§1](04_Tab3_AIChat.md)／[05§2.5-2.7](05_Tab4_回顾MyLife.md)）。
4. **限时撤销窗口（3秒自动消失）**：仅 Dashboard 饮水记录一处，回顾 Tab 的排便记录（性质相同的"快捷记录"）没有对应机制（[02§2.6](02_Tab1_Dashboard首页.md)）。
5. **事后撤销按钮（无时限）**：仅 AI Tab 聊天记录里的餐食气泡，是唯一支持"记录写入很久之后还能一键撤销"的地方（[04§3.2](04_Tab3_AIChat.md)）。

**结论**：同样是"记错了/点错了怎么办"这个问题，五个 Tab 给出了五种不同强度的答案，且同一 Tab 内也可能混用（饮食 Tab 添加无保护、但没有涉及删除confirmation；回顾 Tab 习惯/日志/训练都有 alert，但排便记录没有）。这不是刻意的分级设计（没有证据表明"高风险操作用强保护"的规则被贯彻），更像是各面板独立开发时各自决定，是这套文档目前发现的**最大的跨 Tab 不一致集合**。

---

## 6. 数据写入方式：View 直接操作 `modelContext` vs 独立 Writer 层

全 App 目前只有**一处**把写入逻辑拆成独立的纯逻辑文件：`FoodTimelineMealWriter.swift`（饮食 Tab），`FoodTimelineView` 的 `createMeal`/`copyMeal`/`addUserFood` 等方法全部只是转发调用（[03§3.6](03_Tab2_饮食.md)）。但同一个 Tab 里的 `AddFoodSheet`/`EditFoodSheet` 又是直接在 View 的 `save()` 方法里操作 `modelContext`——说明这个模式**连饮食 Tab 自己都没有贯彻到底**，其余 4 个 Tab（Dashboard 的加水/排便、回顾 Tab 的习惯/日志/训练/身体数据）全部是 View 内联写入，没有 Writer 层。

**结论**：`FoodTimelineMealWriter` 是目前唯一的正面案例，值得作为"新写数据写入逻辑应该怎么组织"的参照标准，但不能说这是 1Life 已经建立的规范——它只是一个孤例。

---

## 7. 双语文案不一致清单（`SystemPageHeader`/`editorHeader` 英文 vs 中文）

| 位置 | 语言 | 定位 |
|---|---|---|
| Onboarding 全部 10 步 | 中文 eyebrow/标题，但面板内 `SystemPanel(title:)` 混用英文大写（"CORE WORKFLOW"/"LANGUAGE OPTIONS"等） | [01§3.3](01_启动与Onboarding.md) |
| Dashboard | 全部中文 | [02](02_Tab1_Dashboard首页.md) |
| 饮食 Tab | 全部中文 | [03](03_Tab2_饮食.md) |
| AI Tab | 全部中文 | [04](04_Tab3_AIChat.md) |
| 回顾 Tab · 习惯新建/编辑 Sheet | 英文（"CREATE HABIT"/"PRESETS"/"HABIT INFO"等） | [05§2.5](05_Tab4_回顾MyLife.md) |
| 回顾 Tab · 训练新建/编辑 Sheet | 英文（"CREATE WORKOUT"/"TYPE"/"TIME"等） | [05§2.7](05_Tab4_回顾MyLife.md) |
| 回顾 Tab · 日志新建/编辑 Sheet | 中文（"记录状态"/"快速复盘"等） | [05§2.6](05_Tab4_回顾MyLife.md) |
| 回顾 Tab · 身体数据/排便 Sheet | 中文 | [05§2.3-2.4](05_Tab4_回顾MyLife.md) |

**结论**：没有"新建用英文、编辑用中文"或"哪个 Tab 统一用哪种语言"之类的简单规律可循，是文件级别各自决定的历史结果。复制模式到新 App 前必须逐文件核对，不能按 Tab 或按"新建/编辑"这种维度批量假设。

---

## 8. 自绘图表：仅回顾 Tab 出现，其余 Tab 没有对标物

全 App 唯一系统性使用 `GeometryReader` + `Path` 手工绘图的地方是回顾 Tab 的阶段回顾面板（柱状图/折线/热力网格/迷你趋势图，共 4 种图表类型），没有依赖 Swift Charts 框架（[05§3.1](05_Tab4_回顾MyLife.md)）。Dashboard 的环形进度条虽然也是自绘 `Path`，但只是单一进度环，复杂度和"图表"不在同一量级，不构成可比对象。**如果其它 App 需要类似的阶段趋势可视化，回顾 Tab 这套实现是目前唯一、也是完整的可迁移资产**，见 [05§4](05_Tab4_回顾MyLife.md) 第 1 条。

---

## 9. 本地规则文案引擎（不消耗 AI 请求额度）

三处独立实现，互不共享代码：

- 饮食 Tab「今天饮食小结」（[03§2.6](03_Tab2_饮食.md)）
- 回顾 Tab「阶段回顾」的 `conclusion` 结论文案（[05§2.2](05_Tab4_回顾MyLife.md)）
- 回顾 Tab 习惯详情页的「趋势洞察」文案（[05§2.5](05_Tab4_回顾MyLife.md)）

三者都是各自维护一串 if-else 优先级判断，从结构化数据生成一句自然语言点评。**没有共享同一个"数据→文案"生成器**，如果家族其它 App 也需要类似的"轻量本地点评"（不调用 AI、纯规则），值得考虑抽成一个通用的小工具（输入一组条件优先级+文案模板，输出命中的第一条），而不是继续每处独立写一遍 if-else。

---

## 10. 已知问题索引（详情见 [ROADMAP.md](../ROADMAP.md)，此处不重复内容）

- `SupplementRecord` 未注册进 `OneLifeApp.swift` 的 `modelContainer` 数组（01篇发现）
- Onboarding 内原生控件未套用家族 `AppSwitchStyle`（01篇发现）
- `JournalEditorView` 斜体快捷按钮符号数量错误（05篇发现）
- 身体数据卡与训练面板的 Apple Health 导入反馈机制不统一（05篇发现，即本索引第4节的具体案例）
- 训练周目标数值输入静默丢弃非法值（05篇发现）

---

## 11. 可复制性 Top 清单（跨篇汇总排序）

按"迁移到 1Track/1Pet/1Day/1Parcel 的价值密度"排序，给"下一个 App 从哪抄起"的直接答案：

1. **`SplashView`**（启动动画）——完全无业务耦合，换两个参数即可用（[01§6](01_启动与Onboarding.md)）
2. **Onboarding 专用组件骨架**（`OnboardingHeader`/`OnboardingBottomBar`/`OptionRow` 等）——1Pet 审查已确认这是最大的现存缺口（[01§6](01_启动与Onboarding.md)）
3. **回顾 Tab 阶段回顾整套图表框架**——周期选择器+4张自绘图表，替换字段即可复用给记账/宠物健康等任何"阶段性数据回顾"场景（[05§4](05_Tab4_回顾MyLife.md)）
4. **习惯打卡整套模型**（三态循环+连续天数+30天热力图+预设卡片）——独立度高，可直接复用给"每日待办/护理打卡"类需求（[05§4](05_Tab4_回顾MyLife.md)）
5. **AI Chat 完整实现**——家族规范强制要求"锁步"，本身就是基准而非可选参考（[04§8](04_Tab3_AIChat.md)）
6. **深链接机制**（语境状态+`.id()`锚点+`ScrollViewProxy`）——轻量通用，见本索引第1节
7. **`quickStatusRow` 式复合面板**（多个子区域压缩进一个卡片，各自可点击跳转带语境）——省屏幕空间的通用模式（[02§5](02_Tab1_Dashboard首页.md)）
8. **饮水记录的3秒撤销条**——通用的"快捷操作后悔药"交互，但连 1Life 自己内部复用都不足（仅一处），迁移时建议同时改造成共享组件而不是再复制一份（[02§5](02_Tab1_Dashboard首页.md)）

**不建议原样复制的反面案例**：饮食 Tab 的 Add/Edit 字段不对称（[03§4](03_Tab2_饮食.md)）、本索引第3/4/5/7节列出的四类不一致，迁移时应采用"统一后的版本"而非照抄现状。

---

## 12. 06 篇（设置）完成后的补充

06 篇已撰写完成（[06_Tab5_设置.md](06_Tab5_设置.md)），系列 6 篇全部完成。设置 Tab 补充了以下之前未覆盖的模式：

- **"如何保存"存在两种不统一模式**：显式 Cancel/Save 按钮（`ProfileEditorSheet`）vs 输入即时同步+`onDisappear`兜底的静默保存（`BodyParamsSettingsView`/`NutritionGoalSettingsView`），是第 5 节"风险处理"之外又一处"同类操作、不同确认/保存强度"的具体案例。
- **三级确认是目前全 App 风险等级最高的确认强度**：清空所有数据走"按钮→警告→最终确认"三段，比第 5 节列出的其它四种形态（无确认/前置禁用/单段alert/限时撤销/事后撤销）都更谨慎，应补入第 5 节的风险处理清单，作为最高档。
- **头像未压缩问题不是 Onboarding 独有**：设置页的 `ProfileEditorSheet` 是第二个复现点，说明"头像录入"整条功能线都没接入 `ImageService.compress`。
- **双语文案不一致新增样本**：`NutritionGoalSettingsView` 的页头和分区标题是英文，正文和导航标题是中文，延续第 7 节"没有规律、需逐文件核对"的结论。
- **`SettingsDataCoordinator` 是继 `FoodTimelineMealWriter` 之后第二个"View 只转发、纯逻辑独立成文件"的正面案例**，应补入第 6 节和第 11 节的可复制性清单。
- **新发现的具体 bug**（已记入 `ROADMAP.md`）：`clearAllData` 遗漏 `DrinkRecord`；`UserFoodListView` 批量删除零确认，是本索引第 5 节"风险处理不一致"最新、也是最反直觉的一个案例（批量操作比单条操作保护更弱）。
