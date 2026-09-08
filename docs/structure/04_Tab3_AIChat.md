# 1Life 结构文档 04：Tab 3 · AI

> 系列文档共 6 篇，本篇是第 4 篇。方法论见 [01_启动与Onboarding.md](01_启动与Onboarding.md) 开头。本篇是家族规范里明确要求"结构必须与其它 App 保持一致"的共享表面（AI Chat UI Lockstep Rule），审查 1Track/1Pet 时反复引用的基准就是这里的实现。

## 0. 涉及文件

```text
1Life/Views/AIChat/AIChatView.swift                  主容器，515 行
1Life/Views/AIChat/AIChatComponents.swift            AIConfigurationHeader/AIRequestProgressView/AIEmptyStateContent/ChatBubble 等通用组件，463 行
1Life/Views/AIChat/AIChatMealReviewComponents.swift  两种餐食确认卡片：MealConfirmationCard、AIMealIdentificationConfirmationView，655 行
1Life/Views/AIChat/AIChatMealEditors.swift           MealManualEditSheet + 单条食物编辑器 ParsedFoodItemEditorSheet，481 行
1Life/Views/AIChat/SpeechInputController.swift       语音输入控制器，124 行
1Life/Views/AIChat/AIImagePicker.swift               相机/相册取图封装，46 行
1Life/ViewModels/AIChatViewModel.swift               核心状态机：本地解析→AI解析→确认→落盘的完整流程（本篇只讲界面如何呈现这些状态，不重复展开 ViewModel 内部算法）
1Life/ViewModels/AIChatDrinkLibraryResolver.swift     饮品知识库文本匹配（此前审查报告已详细介绍）
1Life/ViewModels/AIChatSupplementLibraryResolver.swift 补剂知识库文本匹配（本轮新增，同一机制）
```

**这个 Tab 和其它 4 个 Tab 的本质区别**：Dashboard/饮食/回顾/设置都是"读取已有数据、结构化展示、提供编辑入口"，AI Tab 是一个**对话式状态机**——同一屏幕会随着一次对话在"空状态引导"→"发送中进度"→"确认卡片"→"消息气泡"之间来回切换，UI 结构比其它 4 个 Tab 更依赖运行时状态分支，不是静态布局。

---

## 1. 入口与整体结构

- **入口**：底部 TabBar 正中间（第 3 位，家族规范强制要求 AI Tab 必须居中），图标 `sparkles`，文字「AI」。
- **导航标题**：固定「AI」。
- **整体布局**：`NavigationStack` → 纵向 `VStack(spacing: 0)` 四段：

```text
1. AIConfigurationHeader   顶部常驻状态条（服务商/模型/Key 状态 + 切换入口）
2. chatSection             可滚动消息列表（含空状态）
3. pendingSection          条件性出现的餐食确认卡片
4. inputSection            底部输入区（进度条/已选图片/快捷芯片/输入栏）
```

四段没有用 `SystemPanel` 包裹（这是本篇和 02、03 篇最大的视觉结构差异——Dashboard/饮食 Tab 全部内容都在 `SystemPanel` 卡片里，AI Tab 只有顶部 Header 和输入区有描边容器感，中间消息区是裸的滚动区域，更接近通用聊天 App 的视觉语言而非"卡片仪表盘"语言）。

**Toolbar**：右上角一个垃圾桶图标，点击弹 `alert`「清空聊天历史」二次确认（取消/清空两个按钮，清空是 `role: .destructive`）——**这是本 Tab 唯一的二次确认弹窗**，其它所有交互（发消息、确认餐食、撤销记录）都没有二次确认。当前没有任何历史消息时（`storedMessages.isEmpty`）这个按钮直接 `disabled`。

---

## 2. 顶部状态条（`AIConfigurationHeader`）

图标盒（已配置=绿色对勾盾牌 `checkmark.seal.fill`／未配置=橙色感叹号三角）+「AI 配置」标签+状态徽标（已启用/待配置）+ 一行详情文字（已配置显示"服务商 · 模型 · 打码后的Key"，未配置显示错误信息或"请先选择服务商并保存 API Key"）+ 右侧「切换」按钮。

「切换」是一个 `Menu`，展开后是**两个 Section**：「服务商」（列出全部可选服务商，当前项打勾）和「模型」（当前服务商下的可选模型列表，当前项打勾，服务商下没有模型可选时这个 Section 不出现）+ 分隔线 +「AI 设置」跳转项。**切换服务商和切换模型都会立即写入 `AppSettings` 并 `modelContext.save()`，不需要额外确认按钮**——选中即生效，Menu 收起后头部详情文字立即刷新。

切换服务商时还会做一次隐藏的状态推断：`readAPIKey(provider:)` 检查新选中的服务商是否已经保存过 Key，如果之前保存过就自动把 `isAIConfigured` 置回 `true`，不需要用户重新走一遍配置流程——**这是一个跨服务商的 Key 记忆机制，只要曾经为某个服务商存过 Key，切换回去就自动可用**。

---

## 3. 消息列表（`chatSection`）

### 3.1 空状态（`AIEmptyStateContent`，无任何历史消息时显示）

不是简单的一个空状态占位图，是一组内容：
1. 顶部说明卡：图标+状态徽标（AI已就绪/待配置）+ 标题「AI 健康助手」+ 一句话说明
2. **若未配置**：额外插入一张橙色描边的 `AISetupNoticeCard`（警告图标+标题+说明+黑色「前往设置配置 AI」按钮）
3. 固定 5 张 `FeatureCard`（拍照识别/记录饮食/营养分析/训练复盘/生活记录），纯说明性质，不可点击——**这 5 张卡片不是功能入口，只是文案介绍，点了没有反应**

### 3.2 消息气泡（`ChatBubble`）

根据消息类型分两种完全不同的呈现：
- **普通文本消息**（`ChatBubbleContent`）：用户消息黑底白字、AI 回复描边浅底黑字，靠左/右对齐由 `role` 决定，最大宽度 280pt。如果消息内容包含 `[图片`/`[照片` 前缀行，这些行会被过滤不显示为文字，改成一个「图片附件」小标签胶囊（不显示缩略图本身，只有文字提示曾经发过图片）
- **餐食记录消息**（`toolName == "add_meal"`，`MealBubbleCard`）：结构化卡片——已记录/已撤销状态徽标 + 总热量 + 餐次名 + 逐条食物名与热量 + 底部「撤销」按钮（未撤销时可点，`onUndo` 调用 `viewModel.undoMeal`）。**这是聊天记录里唯一可以在事后撤销的消息类型**，撤销后卡片整体降低透明度（0.6）并把按钮替换成纯文字「已撤销」。

**所有气泡长按都能呼出「复制」**（`contextMenu`），复制文案对餐食卡片和普通文字分别做了不同的格式化处理（餐食卡片复制的是"已记录：早餐 450 kcal（鸡蛋 80 kcal，牛奶 130 kcal）"这种摘要文本，不是原始 JSON）。

### 3.3 自动滚动

`ScrollViewProxy` + 一个不可见的 `Color.clear.frame(height:1).id(chatBottomID)` 锚点，任何时候 `storedMessages.count` 或 `viewModel.messages.count`变化都会在 0.1 秒延迟后自动滚到底部（首次进入页面不带动画，后续消息变化带 0.2 秒缓动）——**两个不同的消息计数来源（持久化的 `storedMessages` 和 ViewModel 内存态的 `viewModel.messages`）都各自独立监听触发滚动**，说明这两者在实现上不是完全同步的单一数据源，而是"ViewModel 维护一份内存态，同时 SwiftData 也在被动写入，两边都可能先于对方变化"。

---

## 4. 餐食确认区（`pendingSection`）—— 两种卡片，且会在同一次对话中互相切换

这是本 Tab 除消息列表外最复杂的一块。当 AI/本地解析出一次饮食记录后，不会直接写入数据库，而是先展示一张"待确认"卡片，用户操作后才真正落盘。**有两种视觉完全不同的卡片**，由 `AIChatViewModel` 的两个状态变量决定用哪个：

```swift
if let confirmation = viewModel.pendingConfirmation {
    AIMealIdentificationConfirmationView(...)   // 优先级更高
} else if let meal = viewModel.pendingMealResult {
    MealConfirmationCard(...)
}
```

### 4.1 `AIMealIdentificationConfirmationView`（首次出现的确认卡）

图标+来源徽标（本地解析=橙色"本地解析"／AI结果=青色"AI 结果"）+ 标题 + 一段「原始输入」引用框（显示用户当时打的原文，最多3行）+ 餐食摘要卡（餐次+总热量+逐条食物）+ **三按钮一排**「用 AI 重新识别」「手动编辑」「确认记录/确认记录N餐」+ 下面一排次要操作「存到模板库」「忽略」。

「用 AI 重新识别」只在本地解析结果的场景下有意义（把本地识别的结果丢弃，重新调用 AI 走一遍图片/文字解析），点击后会清空当前所有 pending 状态并重新发起请求。

### 4.2 `MealConfirmationCard`（点了"手动编辑"之后切换成的卡）

这里有一个**不直观但确实存在的交互链路**：点击 4.1 卡片里的「手动编辑」按钮打开 `MealManualEditSheet`，用户在里面调整完保存后，`applyManualMealEdit(_:)` 会**显式把 `pendingConfirmation` 设为 `nil`、但保留 `pendingMealResult`**（`AIChatViewModel.swift:420-427`）——根据上面的 `if/else if` 逻辑，这会导致 `pendingSection` 从渲染 `AIMealIdentificationConfirmationView` **切换成渲染完全不同结构的 `MealConfirmationCard`**。也就是说：**手动编辑一次之后，确认卡片本身的视觉结构会变**，不是回到原来那张卡片上看编辑后的结果。

`MealConfirmationCard` 的具体结构：
- 头部：AI 餐食复核徽标 + 餐次名 + 右上角「推荐记录值 X kcal」
- 若存在"估算区间"类食物（`isEstimatedRange`，比如 AI 给出"这份菜大概 150-300g"这种不确定范围），顶部会出现一个**整体缩放滑块**「整体估算克重」，拖动滑块用指数曲线（`pow(2.0, 2.0*scale-1.0)`）同时缩放所有区间食物的份量，右侧实时显示当前倍率——这是一个"一个滑块统一调整多个不确定食物份量"的机制
- 逐条食物区块：名称+可信度标签（精确/估算/粗估，三色）+ 份量/热量；区间型食物额外带**单独的份量滑块**（`FoodItemSliderView`，左右两端锚定在 `amountMin`/`amountMax`，可单独精调，和上面的整体滑块是两层独立但联动的调整机制——单独调整某一项后，如果再去拖整体滑块，会覆盖掉单独调整的结果）
- 底部四按钮：取消/手动编辑（可以再次进 `MealManualEditSheet`，形成循环）/存到模板库/确认记录（`totalCalories<=0` 或存在"营养素严重缺失"时这个按钮 disabled）

**两张卡片的按钮集合不完全相同**：4.1 有「用 AI 重新识别」，4.2 没有（编辑后已经不再需要"整个丢掉重新识别"这个选项）；4.2 有「份量滑块微调」，4.1 没有。这不是缺陷，是刻意的两阶段设计（先给一个粗粒度的"信不信得过整体结果"判断，编辑后进入更细粒度的"逐项调整"模式），但对于第一次接触代码的人来说容易误以为是同一张卡片的两种状态而找错文件。

### 4.3 `MealManualEditSheet` → `ParsedFoodItemEditorSheet`（第三层）

`MealManualEditSheet`：餐次 `Picker(.segmented)` + AI 备注展示（若有）+ 食物明细列表，点任意一条食物打开第三层 `ParsedFoodItemEditorSheet`（独立文件内 337 行，未在本篇逐行展开，作用是单条食物的完整营养字段编辑器，字段结构与 03 篇提到的 `EditFoodSheet` 同源）。编辑完成后 `onSave` 逐级往上传回，最终 `MealManualEditSheet` 的「保存」按钮把整份 `draftMeal` 传回 `pendingSection` 层。

---

## 5. 底部输入区（`inputSection`）

从上到下：

### 5.1 请求进度（`AIRequestProgressView`，仅 `viewModel.isLoading` 时出现）

不是简单的转圈圈，而是**根据经过时间和是否带图片，分阶段变化文案和状态徽标**：
- 纯文字请求：<12秒"正在理解记录"／<30秒"正在估算营养"／其余"正在整理确认结果"，对应徽标 理解/估算/生成
- 带图片请求：<20秒"正在读取图片"／<45秒"正在整理营养信息"／其余"正在生成确认结果"，对应徽标 OCR/解析/生成

计时本身由 `AIChatView` 自己维护（`requestElapsedSeconds`，一个每秒 `+1` 的 `Task` 循环，`startRequestTimer`/`stopRequestTimer`），不是 ViewModel 提供的真实进度百分比——**这是"用经过时间伪装分阶段进度"的实现方式，不代表 AI 请求真的按这几个阶段推进，纯粹是给用户一个"没卡死"的心理安慰进度感**。

### 5.2 已选图片预览（仅有待发送图片时出现）

横滑缩略图（58×58，圆角+描边），每张右上角可删除，末尾文字「已附加 X/6」——上限固定 6 张，和 03 篇饮品/补剂识别插件的图片上限（也是 6 张）一致，是全 App 通用的图片附件数量约定。

### 5.3 快捷芯片（`promptChipsSection`）

固定 7 个：记录早餐/拍照识别/营养分析/记录训练/记录排便/写日记/记录喝水。**这里有一个不容易注意到的按钮命名与实际交互的错位**：
- 点「记录训练」「记录排便」「写日记」：**不会立即发送**，只是把预设前缀文字（"记录今天训练："等）填入输入框并聚焦，等用户自己补充内容后手动点发送
- 点其余 4 个（记录早餐/拍照识别/营养分析/记录喝水）：**立即发送**该芯片文字本身作为一条完整消息

`disabled` 条件：`!isConfigured && !["记录喝水","记录训练","记录排便","写日记"].contains(chip)`——即未配置 AI 时，只有「记录喝水/记录训练/记录排便/写日记」这 4 个可点（因为它们背后走的是本地规则解析，不需要 AI），「记录早餐/拍照识别/营养分析」这 3 个需要 AI 能力会被禁用。这和输入框本身"未配置也能打字尝试"的策略是一致的（05 节会提到）。

芯片区**始终常驻显示**，不像某些聊天 App 那样发送过消息后收起——这是此前 1Track/1Pet 审查报告里提到的"1Life 芯片常驻 vs 1Track 仅首次显示"那条差异的权威实现来源。

### 5.4 输入栏（`inputBarSection`）—— 4 个元素固定顺序

```text
[相机] [麦克风] [输入框----------------] [发送]
```

- **相机按钮**（38×38 方块）：`canUseVision` 为真时才启用（要求已配置 AI 且当前模型支持视觉输入），点击弹 `confirmationDialog`「添加图片」（拍照/从相册选择/取消，拍照选项只在设备真的有相机时才出现）。不满足条件点击时不会弹选择器，而是直接把错误信息写进 `viewModel.errorMessage`（进而被 `GlobalBannerCenter` 捕获显示 Toast）
- **麦克风按钮**：`isConfigured` 为真才启用。录音中背景变红色危险色、图标变实心 `mic.fill`；未录音时是描边灰底空心 `mic`。点击调用 `toggleVoiceInput()`，语音转文字结果**实时覆盖**输入框内容（不是追加）
- **输入框**：`isConfigured` 时 placeholder「描述饮食、训练、喝水或状态...」，未配置时 placeholder「可记录喝水，完整 AI 需先配置」——**未配置 AI 时输入框本身没有被禁用，仍然可以打字**，这是与 1Pet 审查中发现的差异点一致（1Life 允许部分基础指令在未配置 AI 时也能用）
- **发送按钮**：黑色方块，`isLoading` 时图标变沙漏，输入为空且没有待发图片时 disabled。点击后清空已选图片列表、停止任何正在进行的语音录制、启动计时器、根据是否带图片分别调用 `viewModel.sendPhotos` 或 `viewModel.sendMessage`

---

## 6. 全局反馈机制

三类错误来源统一走同一个 `GlobalBannerCenter`（顶部滑入 Toast，非本 Tab 独有机制，02/03 篇提到过的同一个单例）：
- `viewModel.errorMessage`（AI 请求失败）→ tone `.error`，标题「AI 请求失败」
- `configurationError`（读取配置状态异常）→ tone `.warning`，标题「AI 配置异常」
- `speechInput.errorMessage`（语音输入异常，比如未授权麦克风/语音识别权限）→ tone `.warning`，标题「语音输入异常」

三者都是`.onChange` 监听后立即清空源状态变量（避免同一个错误重复触发 Toast）。**这三类错误在本 Tab 内部处理方式统一，但和 03 篇提到的饮食 Tab、02 篇 Dashboard 里各自面板"直接把错误当文字嵌在卡片里"的做法不同**——AI Tab 是本 App 里对全局 Toast 机制利用最彻底的一个 Tab。

---

## 7. 值得注意的实现特点

1. **手动编辑会切换确认卡片的视觉结构**（4.2 节）：从三按钮紧凑卡切换成带滑块的详细卡，这是本篇发现的最容易让人困惑的一处交互链路，排查相关 bug 时要注意区分 `pendingConfirmation` 和 `pendingMealResult` 两个状态各自何时被设置/清空。
2. **快捷芯片里有 3 个是"填充文字待发送"、4 个是"立即发送"**，按钮外观完全一样，行为不同，纯靠文案让用户预判（新用户第一次点"记录训练"类芯片，会发现文字填进了输入框而不是直接发出去）。
3. **进度条文案是纯前端计时驱动的伪进度**，不反映真实请求阶段。
4. **餐食气泡是聊天记录里唯一支持事后撤销的消息类型**，其它类型的记录（喝水、训练、日记等）一旦通过对话确认写入，在聊天界面里没有对应的撤销入口（需要去对应 Tab 手动删除）。
5. **输入框和部分快捷芯片在未配置 AI 时仍可用**，走本地规则解析（喝水/训练/排便/日记），这是"AI 功能"和"本地基础记录能力"混在同一个输入框里的设计，好处是新用户不配置 AI 也能用起来，代价是同一个输入框的"能做什么"随配置状态动态变化，容易造成新用户困惑。
6. **AIConfigurationHeader 切换服务商时的 Key 记忆机制**（第 2 节）：只要某服务商曾经存过 Key，来回切换服务商不需要重新验证，是隐藏的便利性设计。
7. **消息计数触发滚动有两个独立来源**（3.3 节），提示 `viewModel.messages`（内存）和 `storedMessages`（`@Query` 持久化）并非严格意义上的单一数据源，理解这个 Tab 的数据流时不能假设两者总是同步的。

---

## 8. 可复制性 / 迁移建议

- **家族规范明确要求 AI Chat 是"锁步"表面**（AI Chat UI Lockstep Rule），本篇记录的头部结构/输入栏 4 元素固定顺序/进度视图分阶段文案/图片上限 6 张，都应该被 1Track、1Pet、1Day、1Parcel 原样复制，只替换 `AIEmptyStateContent` 里的 `FeatureCard` 文案和确认卡片的业务字段。此前审查已经确认 1Track 在语音/图片能力上缺失、1Pet 在错误呈现和部分细节上偏离，1Life 这份实现应作为唯一基准。
- **两阶段确认卡片（粗粒度信任判断 → 编辑后细粒度调整）**是一个成熟的模式，但本篇也指出了它在实现上因为"同一个 pendingSection 用 if/else if 切换两个完全不同的组件"而增加了心智负担。如果要复制这个模式给其它 App，建议用一个更清晰的枚举状态（而不是两个可选值的组合状态）来表达"当前该显示哪张卡片"，减少未来排查状态错乱问题的成本。
- **"部分核心记录能力在 AI 未配置时也可用"这个设计取舍**值得作为家族级产品原则明确下来（目前在 1Life 里是隐性的、要读代码才知道），并写清楚"哪些操作算作降级可用"的判定标准，供其它 App 参照实现，而不是每个 App 各自决定。
