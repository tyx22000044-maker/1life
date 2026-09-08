# 1Life

1Life 是一款以营养健康与运动健身为核心的个人健康管理 App。拍照或语音描述一餐，AI 自动识别食物并计算热量和营养素；结合身体参数与 Apple Health 活动数据估算 TDEE，帮助用户理解摄入、消耗与训练目标之间的关系。日志和习惯追踪是辅助模块，用于补充状态、行为和长期复盘。

## 当前状态

项目处在 V1.0 开发收尾与 app family reference 阶段。产品规格、设计自述和技术架构文档已完成，Xcode 项目和核心代码已创建，主要页面、SwiftData 模型、AI 服务、饮食记录、饮品知识库、习惯/日志、设置、导入导出等模块已有实现。最近一轮更新重点补齐了 AI Chat 模块拆分、餐食确认/校验、饮品识别、Food Timeline 组件化、Settings 数据协调、CSV/JSON/PDF 导出服务、SystemPanel UI 原语和数据清理加固。

当前 1Life 是 1App family 中功能最完整、架构最成熟的参考 app：它定义了 Family UI V2 的系统面板方向、AI 输入到用户确认再入库的安全路径、SwiftData 本地优先模型、导出/备份分层服务和更适合后续复用的 ViewModel/service 边界。发布前重点仍是状态校验、隐私说明、兼容性、截图素材和测试补齐。

## 技术栈

- iOS 17.0+ / SwiftUI
- SwiftData
- XCTest
- Keychain Services
- UserNotifications
- Speech
- HealthKit（Apple Health 动态 TDEE）
- PhotosUI / AVFoundation（拍照识别）
- 多 AI 服务商 HTTP Client：Claude、ChatGPT / OpenAI API、Kimi、通义千问、豆包、腾讯混元、DeepSeek、小米 MiMo
- AI Vision API（拍照食物识别，1Life 独有）
- Family UI V2：`SystemPanel`、错误横幅、分区 Settings、紧凑数据面板

## 目录结构

- `1Life/1Life/`：App 主源码
- `1Life/1Life/Models/`：SwiftData 数据模型（13 个模型）
- `1Life/1Life/Services/`：业务服务（AI、Food、Image、Habit、Export、Notification、Health）
- `1Life/1Life/Views/`：Onboarding、AI、Dashboard、Food、MyLife、Settings 等页面
- `1Life/1Life/ViewModels/`：AI Chat 数据上下文、意图记录、餐食校验、饮品解析、记录日期解析等协作模块
- `1Life/1LifeTests/`：业务单元测试
- `docs/ARCHITECTURE.md`：架构说明
- `docs/ROADMAP.md`：功能状态和后续规划
- `docs/产品功能规格书 v1.0.md`：产品规格
- `docs/1Life 设计自述.md`：设计方向和产品气质

## 运行方式

1. 用 Xcode 打开 `1Life/1Life.xcodeproj`
2. 选择 `1Life` scheme
3. 选择真机或模拟器
4. 点击 Run

当前部署版本为 iOS 17.0。

## 测试

当前已包含业务单元测试，重点覆盖：

- AI 意图解析（本地解析器 + 解码器）
- 营养计算（每日汇总、BMR 公式、份量换算）
- 数据持久化（Meal + FoodItem CRUD、级联删除）
- 用户食物、餐食模板与饮品知识库的本地记录流程
- 习惯 Streak（连续天数、每周型判断）
- 导出（CSV 两种粒度、JSON 备份恢复）

## 重要限制

- iCloud 同步目前只是设置项占位，不是真实跨设备同步。
- AI 拍照识别依赖服务商 Vision / 多模态 API 支持；Claude、OpenAI、Kimi、通义千问、豆包、腾讯混元、小米 MiMo 的视觉模型可用于图片解析，DeepSeek 当前主 API 不作为图片解析首选。是否启用拍照入口以当前选择的模型名判定，非视觉模型会提示切换。
- AI API Key 存在 iOS Keychain；拍照识别会将压缩后的照片发送给所选 AI 服务商。
- Apple Health 仅在用户主动授权后读取活动热量、静息热量、步数、体重和身高，用于动态估算 TDEE 和营养目标。
- 营养、热量和 TDEE 数据仅供个人记录参考，不构成医疗、诊断或专业营养建议。
- 新安装的空 App 不内置食物/饮品营养记录库；我的食物、模板库和饮品知识库均由用户创建或导入。AI 识别结果为估算或用户提供标签换算，需在确认卡片中校对。
- 当前界面文案主要是中文。

## 文档索引

- [Roadmap](docs/ROADMAP.md)
- [架构说明](docs/ARCHITECTURE.md)
- [产品功能规格书](docs/产品功能规格书%20v1.0.md)
- [设计自述](docs/1Life%20设计自述.md)
- [UI Style Guide V2](docs/UI_STYLE_GUIDE_V2.md)
- [隐私说明草案](docs/PRIVACY_POLICY.md)
- [App Store 审核说明草案](docs/APP_STORE_REVIEW_NOTES.md)
- [App Store 截图计划](docs/APP_STORE_SCREENSHOT_PLAN.md)
- [医疗与营养免责声明](docs/MEDICAL_NUTRITION_DISCLAIMER.md)
