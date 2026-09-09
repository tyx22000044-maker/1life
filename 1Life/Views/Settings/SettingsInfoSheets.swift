import SwiftUI

private var oneLifeVersion: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        ?? "—"
}

struct InAppInboxSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("readInAppMessageIDs") private var readIDsRaw = ""

    private static let messages: [InAppMessage] = [
        InAppMessage(
            id: "1life-update-2026-07-15-typography-unification",
            title: "2026-07-15 今日更新汇总 · 字体统一与性能优化",
            dateText: "2026.07.15",
            body: "完成 1App Family 字体系统统一：以 1Life 热量主数字的圆体视觉为基准，统一 FamilyTypography、页面标题、Hero 数字、按钮、设置行、状态徽标、Splash 和页面显式字号；单号、验证码等机器可读字段继续保留等宽字体。同步完成 1Life 第一轮性能优化：收窄 AI 上下文读取范围，减少 Dashboard、饮食、回顾和习惯页面的重复计算，营养汇总改为单次聚合，食物与模板搜索增加输入防抖，模板食材 JSON 增加缓存，并行读取独立的 HealthKit 数据。保持原有数据结构与交互不变。本轮已完成静态差异核验，未执行 build 或模拟器。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-14-icon-refresh",
            title: "2026-07-14 图标视觉更新",
            dateText: "2026.07.14",
            body: "1App Family 图标已换成更醒目的 V2 版本：1Life 采用叶片与闪光主视觉，突出生活记录与健康感；同时补齐浅色、深色和 tinted 图标资源，旧图标已保留备份。本次只更新图标资源与站内信记录，未执行 build。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-14-audit-direction",
            title: "2026-07-14 方向整改记录",
            dateText: "2026.07.14",
            body: "完成 1Life 方向整改复核：头像渐变、Coming Soon 预览页、SystemTextField、AIProvider 模块拆分与插件入口已纳入当前实现；设置说明页的版本号改为读取 Bundle 的实际版本，不再硬编码 v1.0。同步更新站内信记录。本轮只完成静态语法与差异核验，未执行 build 或模拟器验证。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-14-nutrition-target-stability",
            title: "2026-07-14 今日更新汇总 · 动态热量与固定营养目标校准",
            dateText: "2026.07.14",
            body: "修正 Dashboard 营养目标逻辑：开启 Apple Health 动态 TDEE 后，只有每日热量目标会根据当天消耗变化；蛋白质、碳水、脂肪、膳食纤维、钠、糖、维生素和矿物质等营养目标继续沿用已保存的个人目标或固定参考值，不再随着当天时间推移和 TDEE 中途刷新而不断漂移。同步修正 Dashboard、饮食页和设置页的动态目标写回逻辑，动态刷新只更新热量，不会覆盖用户已经设置的营养目标。已完成静态语法与差异核验，未执行 build 或模拟器验证。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-13-plugin-library-pdf-final",
            title: "2026-07-13 今日更新汇总 · 家族对齐、插件与资料库优化",
            dateText: "2026.07.13",
            body: "今天完成 1Life 家族与资料库体系的一轮集中更新：头像渐变、Coming Soon 预览、动态版本号和 SystemTextField 继续统一，AIProvider 从 SharedTypes 拆到 AI 模块，并同步完成 1Track、1Pet 的家族审计收口。设置页补齐补剂库、补剂营养识别和餐食营养识别插件；补剂支持品牌、剂型、每份剂量和营养/活性成分识别，餐食支持图片或纯文字识别，结果均可校对后入库。餐食插件新增品牌（可选）输入框，填写后会优先写入识别结果，方便餐食库按品牌归类；文字输入框新增直接粘贴按钮，并提示不要一次提交过长文本，避免因不同模型能力差异导致识别失败。三个识别插件现在跟随设置页当前 AI 服务商，模型列表也同步变化；全局切换到 MiMo 后可选择 mimo-v2.5 或 mimo-v2.5-pro，并显示实际调用的服务商与模型。三个插件的每次网络请求统一设置为最多 2 分钟，并确认请求会把当前选择的模型真实传入对应服务商接口。餐食识别与餐食库改为每份营养口径，取消克重要求，新餐食不再按 100g 偷换算；餐食营养提取现在只返回原文中实际出现且能匹配字段库的营养字段，未出现字段直接省略；钠、盐、食盐统一归入 sodium。从餐食库或餐食模板记录时，热量、蛋白质、碳水、脂肪、纤维等营养会按每份直接同步，餐食库及模板入口不再显示每100g。餐食库、饮品库、补剂库新增多选、全选、批量删除和批量修改品牌。饮品/补剂精美 PDF 导出增加品牌分组、续页页眉、页码、页脚、主题色卡片、长文本换行和更清晰的信息层级，并修复 PDF 导出的并发隔离与格式化静态问题。以上改动均已完成静态语法与差异核验，未执行 build 或模拟器验证。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-10-ai-model-switch",
            title: "2026-07-10 今日更新汇总",
            dateText: "2026.07.10",
            body: "AI Chat 顶部「切换」菜单升级：现在可以在对话页直接切换服务商和当前服务商下的模型，切换后会保存到 AI 配置，下一次请求会使用新的模型 ID。询问当前 AI 身份、模型或能力时，不再通过 1Life 注入的 provider/model 规则代答，而是交给当前选择的模型自行回复。设置页的食物库也开始重构为餐食库、饮品库和补剂库：已有餐食模板会继续保留在餐食库，旧版饮品模板会自动并入饮品库记录，之后只从饮品库一个入口查看和管理。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-09",
            title: "2026-07-09 今日更新汇总",
            dateText: "2026.07.09",
            body: "今天集中优化饮食、回顾和模板体验：饮品模板与饮品知识库按品牌折叠展示，搜索品牌、饮品名或糖度会自动展开匹配结果；从 Dashboard 餐次进入模板导入时，会优先使用 Dashboard 选中的餐次，饮品不会再默认记到零食。AI Chat 文本饮食估算改为分段策略，先规划食物与克重，再补全热量和营养素，降低同一句话估算漂移。Dashboard 新增排便记录卡片，可跟随顶部日期选择补记过去日期；餐食快照中已记录餐次会直接跳到饮食页对应餐次位置，未记录餐次继续进入补记语境。回顾页能量趋势改为 TDEE 折线叠加实际摄入柱状图，柱状展示日均摄入，折线展示 TDEE；开启 HealthKit 动态 TDEE 时会读取当前回顾周期的每日 TDEE，季和年视图显示周期日均 TDEE。身体恢复新增饮水和排便趋势，并移除重复的体重趋势图。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-08",
            title: "2026-07-08 更新记录",
            dateText: "2026.07.08",
            body: "回顾页阶段总结改为图表化呈现：周、月、季、年都可以查看记录覆盖、日均热量、训练完成度、身体恢复等关键指标；新增能量趋势柱状图、生活节奏热力格和身体恢复趋势，让饮食、习惯、训练、状态、饮水、排便和体重变化更直观。整体仍沿用 Family UI 的卡片、边框、色彩和紧凑排版，减少纯文字复盘带来的阅读负担。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-02",
            title: "2026-07-02 更新记录",
            dateText: "2026.07.02",
            body: "今天集中打磨记录体验：AI 记录更稳，支持饮食、饮水、训练、排便、日记和身体数据，也能识别昨天、前天等日期；模板会优先复用你的模板库，估算加入缓存、分步校验和宏量素自检，减少同一句话热量漂移。饮食页支持历史日期补记、连续追加饮水、克重滑块复核和详情查看，回顾页改为日均热量、记录天数和目标偏差。新增「饮品营养识别」插件，可用图片或文字提取营养，校对后建立饮品知识库；之后记录奶茶、咖啡、果茶等饮品会优先查库，并同步饮食与 ml 饮水量。模板库、导入导出、PDF/CSV/JSON、Apple Health、身体参数、提示音/震动、全局提示和新 UI 也一起补齐。键盘体验同步优化：滚动、点空白和新样式完成按钮都可以更自然地收起输入。"
        ),
        InAppMessage(
            id: "1life-update-2026-07-01",
            title: "2026-07-01 更新记录",
            dateText: "2026.07.01",
            body: "完善饮食 Tab：新增快捷记录、常用食物、最近吃过、模板一键添加、复制昨天同餐、批量添加、餐次分组、每餐蛋白/碳水/脂肪占比、今日饮食小结、高钠/高糖提示和历史食物搜索；优化 Dashboard 到回顾页具体模块的跳转动画；补充站内信内容。"
        ),
        InAppMessage(
            id: "1life-update-2026-06-30",
            title: "2026-06-30 更新记录",
            dateText: "2026.06.30",
            body: "统一 Family UI 细节；优化底部 Tab、新版标题留白和开关样式；加入震动/提示音开关、全局错误提示、Apple Health 体重读取和身体参数同步；推进启动页图标与 1App Family 图标方向。"
        ),
        InAppMessage(
            id: "1life-update-2026-06-29",
            title: "2026-06-29 更新记录",
            dateText: "2026.06.29",
            body: "优化回顾页阶段总结：默认展示本周，可切换月、季、年；补充 BMI 显示、排便记录入口和导出字段；调整设置页身体参数完成状态，让缺失项更清楚。"
        ),
        InAppMessage(
            id: "1life-update-2026-06-28",
            title: "2026-06-28 更新记录",
            dateText: "2026.06.28",
            body: "完善 AI 配置与食物识别流程：加入 AI 服务商 API Key 参考入口，优化 AI Chat 背景和输入区样式；识别营养素不完整时改为提示并允许记录，避免直接拦截。"
        ),
        InAppMessage(
            id: "1life-update-2026-06-27",
            title: "2026-06-27 更新记录",
            dateText: "2026.06.27",
            body: "完善模板库能力：支持模板导入/导出，优化模板克重编辑确认与营养重算；餐食卡片增加显性保存到模板库入口，方便复用常吃餐食和饮品。"
        ),
        InAppMessage(
            id: "1life-update-2026-06-26",
            title: "2026-06-26 更新记录",
            dateText: "2026.06.26",
            body: "优化数据导出体验：CSV/JSON 纳入新增健康记录字段；PDF 导出增加范围选择、加载状态和进度提示，为后续新版 PDF 样式打基础。"
        ),
        InAppMessage(
            id: "1life-security-api-key",
            title: "API Key 安全提醒",
            dateText: "长期提示",
            body: "请只在官方开发平台创建和管理 API Key。1Life 只会保存你主动输入的 Key，并存放在本机 Keychain。不要向非官方页面提交 Key。"
        )
    ]

    private static var messagesByDate: [InAppMessage] {
        var seenDates: Set<String> = []
        return messages.filter { message in
            seenDates.insert(message.dateText).inserted
        }
    }

    private var readIDs: Set<String> {
        get { Set(readIDsRaw.split(separator: ",").map(String.init)) }
        nonmutating set { readIDsRaw = newValue.sorted().joined(separator: ",") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "站内信",
                        title: "消息中心",
                        detail: "版本更新、重要说明和本地公告"
                    )

                    VStack(spacing: 10) {
                        ForEach(Self.messagesByDate) { message in
                            InAppMessageCard(
                                message: message,
                                isRead: readIDs.contains(message.id),
                                onMarkRead: { markRead(message) }
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("站内信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func markRead(_ message: InAppMessage) {
        var ids = readIDs
        ids.insert(message.id)
        readIDs = ids
        HapticEngine.tap()
    }
}

private struct InAppMessageCard: View {
    let message: InAppMessage
    let isRead: Bool
    let onMarkRead: () -> Void

    var body: some View {
        SystemPanel {
            HStack(alignment: .top, spacing: 12) {
                icon
                content
            }
        }
    }

    private var icon: some View {
        Rectangle()
            .fill(isRead ? FamilyUI.panelMutedBackground : FamilyUI.accent.opacity(0.12))
            .overlay(
                Rectangle()
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
            .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
            .overlay(
                Image(systemName: isRead ? "envelope.open.fill" : "envelope.badge.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isRead ? Color.secondary : FamilyUI.accent)
            )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(message.title)
                    .font(.subheadline.weight(.bold))
                Spacer()
                SystemStatusBadge(text: isRead ? "已读" : "未读", tone: isRead ? .neutral : .accent)
            }
            Text(message.dateText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !isRead {
                Button {
                    onMarkRead()
                } label: {
                    Label("标记已读", systemImage: "checkmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(FamilyUI.accent)
                .padding(.top, 2)
            }
        }
    }
}

private struct InAppMessage: Identifiable {
    let id: String
    let title: String
    let dateText: String
    let body: String
}

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct PolicyItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let items: [PolicyItem] = [
        PolicyItem(icon: "lock.shield.fill", title: "本地存储", body: "所有饮食记录、习惯数据、状态记录、身体数据和照片均存储在您的设备本地，不会上传至 1Life 服务器。"),
        PolicyItem(icon: "sparkles", title: "AI 服务", body: "当您使用 AI 功能时，文字描述或照片会发送至您选择的 AI 服务商进行处理。API Key 存储在 iOS Keychain 中。"),
        PolicyItem(icon: "camera.fill", title: "拍照识别", body: "食物照片仅在您主动使用拍照识别功能时发送至 AI 服务商，识别完成后照片仅保存在本地。"),
        PolicyItem(icon: "heart.text.square.fill", title: "Apple Health", body: "连接 Apple Health 后，1Life 会读取活动热量、静息热量、步数、训练记录、体重和身高，用于动态估算 TDEE、训练摘要和营养目标。仅在您主动开启同步时写入体重和体脂。"),
        PolicyItem(icon: "square.and.arrow.up.fill", title: "数据导出", body: "导出的 CSV、JSON 和 PDF 文件由您自行管理，1Life 不会自动上传或分享这些文件。"),
        PolicyItem(icon: "cross.case.fill", title: "AI 使用边界", body: "1Life 中的营养、热量、TDEE、训练和 AI 识别结果仅供个人记录与一般性参考，不构成医疗、诊断、治疗、营养处方或专业健身建议。数据可能存在识别错误、标签口径差异或同步延迟，请在保存前自行核对。涉及疾病、用药、过敏、孕期、饮食障碍或高风险训练时，请咨询合格专业人士；紧急症状请立即联系当地急救服务。"),
        PolicyItem(icon: "checkmark.seal.fill", title: "确认后保存", body: "AI 识别结果先作为草稿展示，只有在你检查并确认后才会写入本机记录。"),
        PolicyItem(icon: "envelope.fill", title: "联系我们", body: "如有任何疑问，请发送邮件至 tyx22000044@gmail.com。")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "隐私政策",
                        title: "隐私说明",
                        detail: "最后更新：2026年7月"
                    )

                    SystemPanel(title: "数据处理") {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { SystemPanelDivider() }

                            HStack(alignment: .top, spacing: 12) {
                                Rectangle()
                                    .fill(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        Rectangle()
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                    .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                                    .overlay(
                                        Image(systemName: item.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(FamilyUI.accent)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack {
                        Spacer()
                        Text("1Life v\(oneLifeVersion) · © 2026")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.pageBottom)
            }
            .background(FamilyUI.pageBackground.ignoresSafeArea())
            .navigationTitle("隐私说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct UserManualSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct ManualItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let items: [ManualItem] = [
        ManualItem(icon: "fork.knife", title: "记录饮食", body: "在「饮食」页手动添加餐食和食物，也可以在 AI 页输入文字描述。使用拍照识别时，确认卡片中的食物、份量和热量后再保存。"),
        ManualItem(icon: "sparkles", title: "AI 配置", body: "在「设置 > AI 配置」选择服务商、模型并保存 API Key。拍照识别只会在当前模型支持视觉输入时启用。API Key 存储在 iOS Keychain。"),
        ManualItem(icon: "heart.text.square.fill", title: "Apple Health", body: "开启动态 TDEE 后，1Life 会在授权范围内读取活动热量、静息热量、步数、训练记录、体重和身高，用于估算今日消耗、训练摘要和营养目标。"),
        ManualItem(icon: "externaldrive.fill", title: "数据管理", body: "CSV 可导出食物明细或每日汇总；JSON 用于完整备份和恢复。导入 JSON 会覆盖当前本机数据，导入前建议先导出备份。"),
        ManualItem(icon: "info.square.fill", title: "数据参考", body: "用户自建食物库、模板、饮品知识库和 AI 识别结果都可能存在估算误差，尤其是混合菜肴和外卖餐食。营养、热量、TDEE、训练和趋势信息仅供个人记录参考，不作为医疗、诊断、治疗或专业营养建议。涉及疾病、用药、过敏、孕期、饮食障碍或高风险训练时，请咨询合格专业人士。")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "用户手册",
                        title: "使用说明",
                        detail: "快速了解 1Life 的记录方式、AI 配置和数据管理。"
                    )

                    SystemPanel(title: "使用指南") {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { SystemPanelDivider() }

                            HStack(alignment: .top, spacing: 12) {
                                Rectangle()
                                    .fill(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        Rectangle()
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                    .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                                    .overlay(
                                        Image(systemName: item.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(FamilyUI.accent)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack {
                        Spacer()
                        Text("1Life v\(oneLifeVersion) · 日常记录参考")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.pageBottom)
            }
            .background(FamilyUI.pageBackground.ignoresSafeArea())
            .navigationTitle("使用说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
