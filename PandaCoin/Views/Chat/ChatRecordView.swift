//
//  ChatRecordView.swift
//  PandaCoin
//
//  对话式记账视图 - 与熊猫财务官对话记账
//

import SwiftUI
import Combine

// MARK: - 固定收入信息（用于自动入账提示）
struct FixedIncomeInfo {
    let record: AIRecordParsed
    let accountId: String  // 记录收入时使用的账户 ID
}

// MARK: - 对话消息类型
enum ChatMessageType {
    case userText(String)                      // 用户文字输入
    case userVoice(String)                     // 用户语音输入
    case userImage(UIImage)                    // 用户图片输入
    case assistantText(String)                 // 熊猫文字回复
    case assistantParsing                      // 正在解析中
    case assistantResult([ParsedFinancialEvent]) // AI解析结果卡片
    case assistantError(String)                // 错误提示
    case savedConfirmation(Int)                // 保存成功确认（保存了几条）
    case autoIncomePrompt(FixedIncomeInfo)     // 自动入账提示（带确认/取消按钮）
}

// MARK: - 对话消息模型
struct ChatMessage: Identifiable {
    let id = UUID()
    let type: ChatMessageType
    let timestamp = Date()
    
    // 是否是用户消息
    var isUser: Bool {
        switch type {
        case .userText, .userVoice, .userImage:
            return true
        default:
            return false
        }
    }
}

// MARK: - 对话式记账视图
struct ChatRecordView: View {
    // 外部传入的图片（从 DashboardView 的拍照/相册按钮获取）
    @Binding var externalImage: UIImage?
    // 控制输入栏显示/隐藏
    @Binding var showInputBar: Bool
    // 外部控制录音状态
    @Binding var isRecording: Bool

    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var recordService = RecordService()
    @ObservedObject private var accountService = AssetService.shared
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    // 登录/订阅提示
    @State private var showLoginRequired = false
    @State private var showSubscription = false

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var editableEvents: [ParsedFinancialEvent] = []  // 可编辑的事件列表
    @State private var showingEventCards = false  // 是否显示事件确认卡片
    @State private var cancellables = Set<AnyCancellable>()

    // 图片处理状态
    @State private var isProcessingImage = false  // 正在处理图片
    private let ocrService = LocalOCRService.shared

    // 自动入账服务
    @StateObject private var autoIncomeService = AutoIncomeService.shared
    @State private var autoIncomeCancellables = Set<AnyCancellable>()

    // 用于自动滚动到底部
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 欢迎消息
                        if messages.isEmpty && !showingEventCards {
                            welcomeMessage
                        }
                        
                        // 显示对话消息
                        ForEach(messages) { message in
                            SimpleChatBubble(
                                message: message,
                                onConfirmAutoIncome: confirmAutoIncome,
                                onCancelAutoIncome: cancelAutoIncome
                            )
                        }
                        
                        // 显示可编辑的事件确认卡片（复用 UnifiedConfirmationView 的卡片）
                        if showingEventCards && !editableEvents.isEmpty {
                            eventConfirmationSection
                        }
                        
                        // 底部锚点
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: showingEventCards) { _ in
                    scrollToBottom(proxy)
                }
            }
            
            // 输入栏（根据 showInputBar 控制显示，确认卡片显示时禁用输入）
            if showInputBar {
                ChatInputBar(
                    text: $inputText,
                    onSend: sendTextMessage
                )
                .disabled(showingEventCards)
                .opacity(showingEventCards ? 0.5 : 1.0)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.clear)  // 透明背景，与首页渐变融合
        // 监听外部图片（从 DashboardView 传入）- 直接进行 OCR 识别并发送给 AI
        .onChange(of: externalImage) { newImage in
            if let image = newImage {
                processImageDirectly(image)
                // 处理后清空外部图片
                externalImage = nil
            }
        }
        // 监听外部录音状态变化
        .onChange(of: isRecording) { newValue in
            if newValue {
                startRecording()
            } else {
                // 只有在 speechService 正在录音时才停止
                if speechService.isRecording {
                    stopRecording()
                }
            }
        }
        .sheet(isPresented: $showLoginRequired) {
            LoginRequiredView(featureName: "记账")
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
    
    // MARK: - 直接处理图片（无预览，直接 OCR + AI 解析）
    private func processImageDirectly(_ image: UIImage) {
        guard authService.isAuthenticated else {
            showLoginRequired = true
            return
        }
        guard subscriptionService.isProMember else {
            showSubscription = true
            return
        }
        guard !isProcessingImage else { return }
        isProcessingImage = true
        
        // 添加用户图片消息
        messages.append(ChatMessage(type: .userImage(image)))
        
        // 显示识别中状态
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 进行本地 OCR 识别
        ocrService.recognizeText(from: image)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    isProcessingImage = false

                    if case .failure(let error) = completion {
                        // OCR 失败
                        self.messages.removeAll { msg in
                            if case .assistantParsing = msg.type { return true }
                            return false
                        }
                        self.messages.append(ChatMessage(type: .assistantError("图片识别失败：\(error.localizedDescription)")))
                    }
                },
                receiveValue: { [self] result in
                    // OCR 成功，构建文本发送给 AI
                    if !result.isValidReceipt {
                        // 不是有效票据
                        self.messages.removeAll { msg in
                            if case .assistantParsing = msg.type { return true }
                            return false
                        }
                        self.messages.append(ChatMessage(type: .assistantText("这张图片不像是票据哦，请拍摄购物小票、支付截图或外卖订单~")))
                        return
                    }
                    
                    // 构建 AI 解析文本
                    var parseText = "【票据识别】"
                    
                    if let amount = result.extractedInfo.amount {
                        parseText += " 金额¥\(amount)"
                    }
                    if let merchant = result.extractedInfo.merchant {
                        parseText += " 商家:\(merchant)"
                    }
                    if let paymentMethod = result.extractedInfo.paymentMethod {
                        parseText += " 支付方式:\(paymentMethod)"
                    }
                    
                    // 附加原始文字（帮助 AI 理解）
                    parseText += "\n原文: \(result.rawText.prefix(500))"
                    
                    logInfo("📷 票据OCR结果: \(parseText)")
                    
                    // 发送给 AI 解析
                    parseAndRespond(text: parseText, parsingMessageId: nil)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 事件确认区域（复用 EventConfirmCard）
    private var eventConfirmationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 熊猫提示
            HStack(alignment: .top, spacing: 8) {
                Text("🐼")
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("好的，帮你记录\(editableEvents.count > 1 ? "\(editableEvents.count)笔" : "")：")
                        .font(AppFont.body(size: 15))
                        .foregroundColor(Theme.text)
                    
                    Text("请确认信息是否正确")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 使用 EventConfirmCard（完整功能，包含账户选择）
            // 使用 id 而非索引绑定，避免 dismiss 时的 Index out of range 崩溃
            ForEach(editableEvents) { event in
                if let index = editableEvents.firstIndex(where: { $0.id == event.id }) {
                    EventConfirmCard(event: Binding(
                        get: {
                            guard index < editableEvents.count else { return event }
                            return editableEvents[index]
                        },
                        set: { newValue in
                            guard index < editableEvents.count else { return }
                            editableEvents[index] = newValue
                        }
                    ))
                }
            }
            
            // 确认按钮
            HStack(spacing: 12) {
                Button(action: cancelEvents) {
                    Text("取消")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.separator)
                        .cornerRadius(22)
                }
                
                Button(action: { confirmEvents(editableEvents) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("确认保存")
                            .font(AppFont.body(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.bambooGreen)
                    .cornerRadius(22)
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
    
    // MARK: - 欢迎消息
    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            Text("🐼")
                .font(.system(size: 60))
            
            VStack(spacing: 8) {
                Text("你好！我是熊猫财务官")
                    .font(AppFont.body(size: 18, weight: .semibold))
                    .foregroundColor(Theme.text)
                
                Text("告诉我你今天的收支吧~")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 快捷提示
            VStack(spacing: 8) {
                Text("你可以这样说：")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    QuickTipChip(text: "我的汇丰银行储蓄卡有156300")
                    QuickTipChip(text: "我这个月预算2600")
                }
                QuickTipChip(text: "我有一张尾号2345的花旗银行信用卡，额度25000，每个月15号还款")
                HStack(spacing: 8) {
                    QuickTipChip(text: "午餐花了35元，打车15块")
                    QuickTipChip(text: "发了8000工资")
                }
                
                HStack(spacing: 8) {
                    QuickTipChip(text: "买衣服消费200")
                    QuickTipChip(text: "我持有英伟达股票1万股")
                }
                HStack(spacing: 8) {
                    QuickTipChip(text: "我的车贷目前还有12000")
                    QuickTipChip(text: "今天车贷还款3065")
                }
                
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 发送文本消息
    private func sendTextMessage() {
        guard authService.isAuthenticated else {
            showLoginRequired = true
            return
        }
        guard subscriptionService.isProMember else {
            showSubscription = true
            return
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 添加用户消息
        messages.append(ChatMessage(type: .userText(text)))
        inputText = ""
        
        // 显示解析中状态
        let parsingMessageId = UUID()
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 调用AI解析
        parseAndRespond(text: text, parsingMessageId: parsingMessageId)
    }
    
    // MARK: - 开始录音
    private func startRecording() {
        guard authService.isAuthenticated else {
            isRecording = false
            showLoginRequired = true
            return
        }
        guard subscriptionService.isProMember else {
            isRecording = false
            showSubscription = true
            return
        }
        do {
            try speechService.startRecording()
        } catch {
            isRecording = false
            messages.append(ChatMessage(type: .assistantError("语音识别启动失败，请检查麦克风权限")))
        }
    }
    
    // MARK: - 停止录音
    private func stopRecording() {
        let recognizedText = speechService.recognizedText
        speechService.stopRecording()
        isRecording = false
        
        guard !recognizedText.isEmpty else {
            messages.append(ChatMessage(type: .assistantText("没有听清楚，请再说一次吧~")))
            return
        }
        
        // 添加用户语音消息
        messages.append(ChatMessage(type: .userVoice(recognizedText)))
        
        // 显示解析中
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 调用AI解析
        parseAndRespond(text: recognizedText, parsingMessageId: nil)
    }
    
    // MARK: - AI解析并响应
    private func parseAndRespond(text: String, parsingMessageId: UUID?) {
        recordService.parseVoiceInputUnified(text: text)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                // 移除"解析中"消息
                self.messages.removeAll { msg in
                    if case .assistantParsing = msg.type { return true }
                    return false
                }
                
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("解析失败：\(error.localizedDescription)")))
                }
            } receiveValue: { events in
                // 移除"解析中"消息
                self.messages.removeAll { msg in
                    if case .assistantParsing = msg.type { return true }
                    return false
                }
                
                if events.isEmpty {
                    self.messages.append(ChatMessage(type: .assistantText("抱歉，没有识别出记账信息，请换个方式描述试试~")))
                } else {
                    // 设置可编辑事件并显示确认卡片
                    self.editableEvents = events
                    self.showingEventCards = true
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 确认保存事件
    private func confirmEvents(_ events: [ParsedFinancialEvent]) {
        // 隐藏事件卡片
        showingEventCards = false

        // 构建账户映射
        var accountMap: [String: String] = [:]
        for account in accountService.accounts {
            accountMap[account.name] = account.id
        }

        // 检测是否有固定收入事件（保存成功后提示）- 传入 accountMap 以获取账户 ID
        let fixedIncomeInfo = findFixedIncomeRecord(in: events, accountMap: accountMap)

        // 保存事件（传入 authService 以便使用默认账户）
        recordService.saveFinancialEvents(events, accountMap: accountMap, assetService: accountService, authService: AuthService.shared)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("保存失败：\(error.localizedDescription)")))
                }
            } receiveValue: { count in
                self.messages.append(ChatMessage(type: .savedConfirmation(count)))
                self.editableEvents = []

                // 检测到固定收入，延迟显示提示
                if let info = fixedIncomeInfo {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.promptAutoIncome(for: info)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 提示设置自动入账
    private func promptAutoIncome(for info: FixedIncomeInfo) {
        let record = info.record
        let incomeType = inferIncomeType(from: record)
        let amount = Double(truncating: record.amount as NSNumber)
        let suggestedDay = record.suggestedDay ?? Calendar.current.component(.day, from: Date())

        // 先检查是否已存在相似的自动入账
        autoIncomeService.fetchAutoIncomes()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { autoIncomes in
                    // 检查是否存在相似的自动入账（收入类型 + 金额 + 日期）
                    let exists = autoIncomes.contains { existing in
                        // 1. 收入类型相同
                        let sameType = existing.incomeType == incomeType

                        // 2. 金额相近（差异在 10% 以内，或绝对差异在 100 元以内）
                        let amountDiff = abs(existing.amount - amount)
                        let percentDiff = amount > 0 ? amountDiff / amount : 0
                        let similarAmount = percentDiff < 0.1 || amountDiff < 100

                        // 3. 日期相近（差异在 3 天以内，考虑月末跨月的情况）
                        let dayDiff = abs(existing.dayOfMonth - suggestedDay)
                        let similarDay = dayDiff <= 3 || dayDiff >= 28  // 28+ 表示月末和月初的差异

                        return sameType && similarAmount && similarDay
                    }

                    if exists {
                        // 已存在相似的自动入账，不再提示
                        logInfo("检测到已存在相似的自动入账配置（类型+金额+日期匹配），跳过提示")
                    } else {
                        // 不存在，发送带确认/取消按钮的消息
                        self.messages.append(ChatMessage(type: .autoIncomePrompt(info)))
                    }
                }
            )
            .store(in: &autoIncomeCancellables)
    }

    // MARK: - 确认设置自动入账
    func confirmAutoIncome(for info: FixedIncomeInfo, messageId: UUID) {
        // 移除提示消息
        messages.removeAll { $0.id == messageId }

        // 显示设置中状态
        messages.append(ChatMessage(type: .assistantText("好的，正在为你设置自动入账...")))

        let record = info.record

        // 使用记录时的账户 ID，如果为空则查找合适的账户
        var targetAccountId = info.accountId
        if targetAccountId.isEmpty {
            targetAccountId = findSuitableAccountId(for: record)
        }

        guard !targetAccountId.isEmpty else {
            // 移除"设置中"消息
            messages.removeAll { msg in
                if case .assistantText(let text) = msg.type, text.contains("正在为你设置") {
                    return true
                }
                return false
            }
            messages.append(ChatMessage(type: .assistantError("未找到可用的储蓄账户，请先添加银行卡或储蓄账户")))
            return
        }

        // 创建自动入账请求
        let request = CreateAutoIncomeRequest(
            name: record.description.isEmpty ? inferIncomeType(from: record).displayName : record.description,
            incomeType: inferIncomeType(from: record).rawValue,
            amount: Double(truncating: record.amount as NSNumber),
            targetAccountId: targetAccountId,
            category: inferIncomeType(from: record).defaultCategory,
            dayOfMonth: record.suggestedDay ?? Calendar.current.component(.day, from: Date()),
            executeTime: "09:00",
            reminderDaysBefore: 1,
            isEnabled: true
        )

        autoIncomeService.createAutoIncome(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    // 移除"设置中"消息
                    self.messages.removeAll { msg in
                        if case .assistantText(let text) = msg.type, text.contains("正在为你设置") {
                            return true
                        }
                        return false
                    }

                    if case .failure(let error) = completion {
                        self.messages.append(ChatMessage(type: .assistantError("设置失败：\(error.localizedDescription)")))
                    }
                },
                receiveValue: { _ in
                    // 移除"设置中"消息
                    self.messages.removeAll { msg in
                        if case .assistantText(let text) = msg.type, text.contains("正在为你设置") {
                            return true
                        }
                        return false
                    }

                    self.messages.append(ChatMessage(type: .assistantText("已设置成功！以后每月都会自动记录这笔收入，你可以在「设置 → 自动入账」中管理 🎉")))
                }
            )
            .store(in: &autoIncomeCancellables)
    }

    // MARK: - 取消设置自动入账
    func cancelAutoIncome(messageId: UUID) {
        // 移除提示消息
        messages.removeAll { $0.id == messageId }
        messages.append(ChatMessage(type: .assistantText("好的，已跳过。有需要时可以在「设置」中手动添加自动入账~")))
    }

    // MARK: - 查找合适的入账账户
    private func findSuitableAccountId(for record: AIRecordParsed) -> String {
        // 储蓄类账户类型
        let savingsTypes: [AssetType] = [.bank, .cash, .digitalWallet, .savings]

        // 1. 优先使用记录时选择的账户（如果是储蓄类）
        if !record.accountName.isEmpty {
            if let account = accountService.accounts.first(where: { $0.name == record.accountName }) {
                if savingsTypes.contains(account.type) {
                    return account.id
                }
            }
        }

        // 2. 使用第一个储蓄类账户
        if let account = accountService.accounts.first(where: { savingsTypes.contains($0.type) }) {
            return account.id
        }

        return ""
    }

    // MARK: - 查找固定收入记录
    private func findFixedIncomeRecord(in events: [ParsedFinancialEvent], accountMap: [String: String]) -> FixedIncomeInfo? {
        for event in events {
            if let record = event.transactionData {
                // 收入类型且被标记为固定收入
                if record.type == .income && record.isFixedIncome == true {
                    let accountId = accountMap[record.accountName] ?? ""
                    return FixedIncomeInfo(record: record, accountId: accountId)
                }
                // 收入类型且分类是工资、公积金等（使用 CategoryMapper 的纯枚举匹配）
                if record.type == .income && CategoryMapper.isFixedIncomeCategory(record.category) {
                    let accountId = accountMap[record.accountName] ?? ""
                    return FixedIncomeInfo(record: record, accountId: accountId)
                }
            }
        }
        return nil
    }

    // MARK: - 推断收入类型
    private func inferIncomeType(from record: AIRecordParsed) -> IncomeType {
        // 先尝试使用 incomeType 字段
        if let typeString = record.incomeType {
            switch typeString.uppercased() {
            case "SALARY": return .salary
            case "HOUSING_FUND": return .housingFund
            case "PENSION": return .pension
            case "RENTAL": return .rental
            case "INVESTMENT_RETURN": return .investmentReturn
            default: break
            }
        }

        // 使用 CategoryMapper 从 category 推断
        return CategoryMapper.inferIncomeType(from: record.category)
    }
    
    // MARK: - 取消事件
    private func cancelEvents() {
        // 先隐藏卡片区域，再清空数组，避免 Index out of range 崩溃
        withAnimation(.easeOut(duration: 0.2)) {
            showingEventCards = false
        }
        // 延迟清空数组，确保视图已经移除
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            editableEvents = []
        }
        messages.append(ChatMessage(type: .assistantText("好的，已取消。有其他记账需要吗？")))
    }
}

// MARK: - 快捷提示标签
struct QuickTipChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Theme.bambooGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.bambooGreen.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.bambooGreen.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(16)
    }
}

// MARK: - 简化对话气泡视图（不包含事件卡片）
struct SimpleChatBubble: View {
    let message: ChatMessage
    var onConfirmAutoIncome: ((FixedIncomeInfo, UUID) -> Void)?
    var onCancelAutoIncome: ((UUID) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !message.isUser {
                // 熊猫头像
                Text("🐼")
                    .font(.system(size: 28))
                    .frame(width: 36, height: 36)
            }

            if message.isUser {
                Spacer(minLength: 60)
            }

            bubbleContent

            if !message.isUser {
                Spacer(minLength: 60)
            }

            if message.isUser {
                // 用户头像
                Circle()
                    .fill(Theme.bambooGreen.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(Theme.bambooGreen)
                            .font(.system(size: 16))
                    )
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.type {
        case .userText(let text), .userVoice(let text):
            userBubble(text: text, isVoice: message.type.isVoice)

        case .userImage(let image):
            imageBubble(image: image)

        case .assistantText(let text):
            assistantTextBubble(text: text)

        case .assistantParsing:
            parsingBubble

        case .assistantResult:
            // 事件卡片现在在 ChatRecordView 中单独处理
            EmptyView()

        case .assistantError(let error):
            errorBubble(error: error)

        case .savedConfirmation(let count):
            confirmationBubble(count: count)

        case .autoIncomePrompt(let info):
            autoIncomePromptBubble(info: info)
        }
    }
    
    // 用户消息气泡
    private func userBubble(text: String, isVoice: Bool) -> some View {
        HStack(spacing: 6) {
            if isVoice {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            Text(text)
                .font(AppFont.body(size: 15))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.bambooGreen)
        .cornerRadius(18)
    }
    
    // 图片消息气泡
    private func imageBubble(image: UIImage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .cornerRadius(12)
                .clipped()
            
            HStack(spacing: 4) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 10))
                Text("票据识别")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.bambooGreen.opacity(0.8))
            .cornerRadius(8)
        }
    }
    
    // 熊猫文字消息气泡
    private func assistantTextBubble(text: String) -> some View {
        Text(text)
            .font(AppFont.body(size: 15))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
    
    // 解析中气泡
    private var parsingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("让我看看...")
                .font(AppFont.body(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
    
    // 错误气泡
    private func errorBubble(error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.expense)
                .font(.system(size: 14))
            Text(error)
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.expense)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.expense.opacity(0.1))
        .cornerRadius(18)
    }
    
    // 保存成功确认气泡
    private func confirmationBubble(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.income)
                .font(.system(size: 16))
            Text("已记录\(count)笔！继续保持好习惯 💪")
                .font(AppFont.body(size: 15))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.income.opacity(0.1))
        .cornerRadius(18)
    }

    // 自动入账提示气泡（带确认/取消按钮）
    private func autoIncomePromptBubble(info: FixedIncomeInfo) -> some View {
        let record = info.record
        let incomeName = record.description.isEmpty ? record.category : record.description

        return VStack(alignment: .leading, spacing: 12) {
            // 提示文字
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                Text("检测到「\(incomeName)」是固定收入")
                    .font(AppFont.body(size: 15))
                    .foregroundColor(Theme.text)
            }

            Text("要设置为每月自动入账吗？这样以后就不用手动记录啦~")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)

            // 确认/取消按钮
            HStack(spacing: 12) {
                Button(action: {
                    onCancelAutoIncome?(message.id)
                }) {
                    Text("不用了")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.separator)
                        .cornerRadius(16)
                }

                Button(action: {
                    onConfirmAutoIncome?(info, message.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("设置自动入账")
                            .font(AppFont.body(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.bambooGreen)
                    .cornerRadius(16)
                }
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
    }
}

// MARK: - 扩展：判断是否是语音消息
extension ChatMessageType {
    var isVoice: Bool {
        if case .userVoice = self { return true }
        return false
    }
}

#Preview {
    ChatRecordView(externalImage: .constant(nil), showInputBar: .constant(true), isRecording: .constant(false))
}
