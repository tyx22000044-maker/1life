# 1Life

1Life 是一款以营养健康与运动健身为核心的个人健康管理 App。用户可以拍照或语音描述一餐，由 AI 识别食物并估算热量和营养素；应用也会结合身体参数与 Apple Health 活动数据估算 TDEE，帮助用户理解摄入、消耗与训练目标之间的关系。日志、习惯与训练时间线用于补充长期复盘。

## 当前状态

项目处在 V1.0 功能收尾阶段。核心页面、SwiftData 模型、AI 服务、饮食记录、饮品知识库、习惯/日志、运动、设置、导入导出和测试骨架均已实现；AI Chat、餐食确认与校验、Food Timeline、插件提取页和 Settings 已按统一视觉系统收口。

1Life 是 app family 中功能最完整的参考工程之一，同时承担 Swiss Ledger 在健康类数据产品中的落地示例：本地优先的数据路径、AI 草稿经用户确认后入库、分层导出/备份服务，以及 ViewModel/service 边界都以可复用为目标。发布前仍需完成真实设备兼容性、隐私文案、App Store 素材和更广泛的 UI/集成测试。

## Swiss Ledger 视觉系统

界面统一使用 `FamilyUI` 与 `FamilyTypography`，设计语言明确为 Swiss Ledger，而不是泛称的 “Family UI V2”：

- 冷纸色页面背景、近黑色墨色、细分隔线和单一印刷红信号色。
- 面板和控件使用 0–4pt 的方形几何，不使用旧的大圆角、胶囊标签或投影。
- 文本角色使用随包 Archivo grotesk；SF Symbols 仍使用系统 symbol font。
- 成功、警告和危险状态使用语义 token；营养素颜色仅用于小面积图例、细条和内联标签，不承担主要操作含义。
- `Services/Export/NutritionPDFExportService.swift` 的 PDF print layout 是独立输出格式，可以保留自己的排版，不影响 App 内 UI 规范。

## 技术栈

- iOS 17.0+ / SwiftUI
- SwiftData
- XCTest
- Keychain Services、UserNotifications、Speech
- HealthKit（用户授权后读取活动数据）
- PhotosUI / AVFoundation（拍照与图片导入）
- 多 AI 服务商 HTTP Client：Claude、OpenAI、Kimi、通义千问、豆包、腾讯混元、DeepSeek、小米 MiMo
- AI Vision API（拍照食物识别）

## 目录结构

- `1Life/`：App 主源码
- `1Life/Models/`：SwiftData 数据模型
- `1Life/Services/`：AI、Food、Image、Habit、Export、Notification、Health 服务
- `1Life/Views/`：Onboarding、AI Chat、Dashboard、Food、MyLife、Settings 等页面
- `1Life/ViewModels/`：AI Chat、餐食校验、饮品解析和日期解析等协作模块
- `1LifeTests/`：业务单元测试
- `docs/`：架构、路线图、产品规格、设计与审核文档

## 运行方式

1. 用 Xcode 打开仓库根目录的 `1Life.xcodeproj`。
2. 选择 `1Life` scheme。
3. 选择 iOS 17 或更高版本的模拟器或真机。
4. 点击 Run。

AI 服务的 Key 通过应用内设置写入 iOS Keychain；如需使用拍照识别，还要选择支持 Vision/多模态输入的服务商模型。

## 构建与测试

在仓库根目录执行：

```sh
xcodebuild -project 1Life.xcodeproj \
  -scheme 1Life \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

仓库包含 `1LifeTests` target，现有 XCTest 主要覆盖 AI 意图解析、营养计算、Meal/FoodItem 持久化与级联删除、用户食物与模板库、饮品知识库、习惯 Streak，以及 CSV/JSON 导出与备份恢复。当前共享 `1Life` scheme 尚未配置 Test action，测试 target 的独立链接配置也需要补齐，因此命令行测试暂不能作为发布门禁；在 Xcode 中运行前应先把 `1LifeTests` 加入 scheme 的 Test action。

## 重要限制

- iCloud 同步目前是设置项占位，不是真实的跨设备同步。
- AI 拍照识别依赖所选服务商的 Vision/多模态 API；非视觉模型会提示切换，图片会以压缩格式发送给所选服务商。
- AI API Key 存在 iOS Keychain；服务商可用性、模型名称和请求额度由外部服务决定。
- Apple Health 仅在用户主动授权后读取活动热量、静息热量、步数、体重和身高，用于动态估算 TDEE 与营养目标。
- 营养、热量和 TDEE 数据仅供个人记录参考，不构成医疗、诊断或专业营养建议。
- 新安装的空 App 不内置食物/饮品营养数据库；用户创建、导入或确认的内容才会进入本地记录。
- AI 识别结果是估算或用户提供标签换算，必须在确认卡片中校对后才会入库。
- 当前界面文案主要是中文。

## 文档索引

- [Roadmap](docs/ROADMAP.md)
- [架构说明](docs/ARCHITECTURE.md)
- [产品功能规格书](docs/产品功能规格书%20v1.0.md)
- [设计自述](docs/1Life%20设计自述.md)
- [UI Style Guide](docs/UI_STYLE_GUIDE_V2.md)
- [隐私说明草案](docs/PRIVACY_POLICY.md)
- [App Store 审核说明草案](docs/APP_STORE_REVIEW_NOTES.md)
- [App Store 截图计划](docs/APP_STORE_SCREENSHOT_PLAN.md)
- [医疗与营养免责声明](docs/MEDICAL_NUTRITION_DISCLAIMER.md)
