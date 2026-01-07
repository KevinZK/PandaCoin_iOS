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
    case selectionFollowUp(NeedMoreInfoParsed) // 选择器追问卡片
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
    
    // 追问状态：保存部分数据，等待用户补充信息
    @State private var pendingPartialData: NeedMoreInfoParsed? = nil
    // 待处理的所有事件（用于多笔交易时保存完整列表）
    @State private var pendingEvents: [ParsedFinancialEvent] = []

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
                                onCancelAutoIncome: cancelAutoIncome,
                                onPickerSelection: { selectedAccount, needMoreInfo in
                                    handlePickerSelection(selectedAccount, for: needMoreInfo)
                                },
                                onPickerCancel: {
                                    pendingPartialData = nil
                                    messages.append(ChatMessage(type: .assistantText("好的，已取消。有其他需要记录的吗？")))
                                }
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
        // 只有状态已加载且非Pro时才显示订阅页面（状态未加载时乐观允许操作）
        if subscriptionService.isStatusLoaded && !subscriptionService.isProMember {
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
                    Text(eventSectionTitle)
                        .font(AppFont.body(size: 15))
                        .foregroundColor(Theme.text)
                    
                    if hasSaveableEvents {
                        Text("请确认信息是否正确")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
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
            
            // 按钮区域
            if hasSaveableEvents {
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
            } else {
//                // 查询类结果只显示关闭按钮
//                Button(action: cancelEvents) {
//                    Text("关闭")
//                        .font(AppFont.body(size: 14, weight: .medium))
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .frame(height: 44)
//                        .background(Theme.bambooGreen)
//                        .cornerRadius(22)
//                }
//                .padding(.top, 8)
            }
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
        // 只有状态已加载且非Pro时才显示订阅页面
        if subscriptionService.isStatusLoaded && !subscriptionService.isProMember {
            showSubscription = true
            return
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 添加用户消息
        messages.append(ChatMessage(type: .userText(text)))
        inputText = ""
        
        // 显示解析中状态
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 检查是否是追问回复（有待处理的部分数据）
        if let pending = pendingPartialData {
            let combinedText = buildCombinedTextForFollowUp(userInput: text, pending: pending)
            pendingPartialData = nil
            parseAndRespond(text: combinedText, parsingMessageId: nil)
        } else {
            // 正常流程
            parseAndRespond(text: text, parsingMessageId: nil)
        }
    }
    
    // MARK: - 统一的追问回复处理
    private func buildCombinedTextForFollowUp(userInput: String, pending: NeedMoreInfoParsed) -> String {
        let missingFields = pending.missingFields
        
        switch pending.originalIntent {
        case .holdingUpdate:
            if let data = pending.partialHoldingData {
                return buildHoldingFollowUpText(userInput: userInput, data: data, missingFields: missingFields)
            }
            
        case .autoPayment:
            if let data = pending.partialAutoPaymentData {
                return buildAutoPaymentFollowUpText(userInput: userInput, data: data, missingFields: missingFields)
            }
            
        case .transaction:
            if let data = pending.partialTransactionData {
                return buildTransactionFollowUpText(userInput: userInput, data: data, missingFields: missingFields)
            }
            
        case .assetUpdate:
            if let data = pending.partialAssetData {
                return buildAssetFollowUpText(userInput: userInput, data: data, missingFields: missingFields)
            }
            
        case .creditCardUpdate:
            if let data = pending.partialCreditCardData {
                return buildCreditCardFollowUpText(userInput: userInput, data: data, missingFields: missingFields)
            }
            
        case .budget:
            if let data = pending.partialBudgetData {
                return buildBudgetFollowUpText(userInput: userInput, data: data, missingFields: missingFields)
            }
            
        default:
            break
        }
        
        return userInput
    }
    
    // MARK: - 持仓追问回复
    private func buildHoldingFollowUpText(userInput: String, data: HoldingUpdateParsed, missingFields: [String]) -> String {
        if missingFields.contains("price") {
            let priceStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "美元", with: "")
                .replacingOccurrences(of: "港币", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            let actionStr = data.holdingAction == "SELL" ? "卖出" : "买入"
            let currencyStr = data.currency == "USD" ? "美元" : (data.currency == "HKD" ? "港币" : "元")
            
            return "\(actionStr)\(Int(data.quantity))股\(data.name)，每股\(priceStr)\(currencyStr)"
        }
        return userInput
    }
    
    // MARK: - 自动扣款追问回复
    private func buildAutoPaymentFollowUpText(userInput: String, data: AutoPaymentParsed, missingFields: [String]) -> String {
        let dayStr = userInput.replacingOccurrences(of: "每个月", with: "")
            .replacingOccurrences(of: "每月", with: "")
            .replacingOccurrences(of: "号", with: "")
            .replacingOccurrences(of: "日", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let typeStr: String
        switch data.paymentType {
        case "SUBSCRIPTION": typeStr = "订阅"
        case "MEMBERSHIP": typeStr = "会员"
        case "INSURANCE": typeStr = "保险"
        case "UTILITY": typeStr = "水电费"
        case "RENT": typeStr = "房租"
        default: typeStr = "自动扣款"
        }
        
        return "\(typeStr)\(data.name)每月\(data.amount)块，每月\(dayStr)号扣费"
    }
    
    // MARK: - 交易追问回复
    private func buildTransactionFollowUpText(userInput: String, data: AIRecordParsed, missingFields: [String]) -> String {
        var result = ""
        let typeStr = data.type == .income ? "收入" : (data.type == .transfer ? "转账" : "花了")
        
        if missingFields.contains("amount") {
            // 补充金额
            let amountStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .trimmingCharacters(in: .whitespaces)
            result = "\(data.description)\(typeStr)\(amountStr)块"
        } else if missingFields.contains("category") {
            // 补充分类
            result = "\(data.description)\(typeStr)\(data.amount)块，分类是\(userInput)"
        } else {
            result = userInput
        }
        return result
    }
    
    // MARK: - 资产追问回复
    private func buildAssetFollowUpText(userInput: String, data: AssetUpdateParsed, missingFields: [String]) -> String {
        var result = ""
        
        if missingFields.contains("amount") || missingFields.contains("total_value") {
            let amountStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "万", with: "0000")
                .trimmingCharacters(in: .whitespaces)
            result = "我有\(amountStr)的\(data.assetName)"
        } else if missingFields.contains("interest_rate") {
            result = "\(data.assetName)\(data.totalValue)块，利率\(userInput)"
        } else if missingFields.contains("repayment_day") || missingFields.contains("monthly_payment") {
            result = "\(data.assetName)\(data.totalValue)块，\(userInput)"
        } else {
            result = userInput
        }
        return result
    }
    
    // MARK: - 信用卡追问回复
    private func buildCreditCardFollowUpText(userInput: String, data: CreditCardParsed, missingFields: [String]) -> String {
        var result = ""
        
        if missingFields.contains("credit_limit") {
            let limitStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "万", with: "0000")
                .trimmingCharacters(in: .whitespaces)
            result = "\(data.name)信用卡额度\(limitStr)"
        } else if missingFields.contains("repayment_due_date") {
            let dayStr = userInput.replacingOccurrences(of: "号", with: "")
                .replacingOccurrences(of: "日", with: "")
                .trimmingCharacters(in: .whitespaces)
            result = "\(data.name)信用卡额度\(data.creditLimit ?? 0)，还款日\(dayStr)号"
        } else {
            result = userInput
        }
        return result
    }
    
    // MARK: - 预算追问回复
    private func buildBudgetFollowUpText(userInput: String, data: BudgetParsed, missingFields: [String]) -> String {
        var result = ""
        
        if missingFields.contains("amount") || missingFields.contains("target_amount") {
            let amountStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .trimmingCharacters(in: .whitespaces)
            result = "\(data.name)预算\(amountStr)块"
        } else if missingFields.contains("category") {
            result = "\(userInput)预算\(data.targetAmount)块"
        } else {
            result = userInput
        }
        return result
    }
    
    // MARK: - 处理选择器选择
    private func handlePickerSelection(_ selectedAccount: SelectedAccountInfo, for needMoreInfo: NeedMoreInfoParsed) {
        // 清除待处理数据
        pendingPartialData = nil
        
        // 移除选择器追问气泡
        messages.removeAll { msg in
            if case .selectionFollowUp = msg.type { return true }
            return false
        }
        
        // 如果有保存的多笔事件，将账户应用到所有缺少账户的事件
        if !pendingEvents.isEmpty {
            var updatedEvents: [ParsedFinancialEvent] = []
            
            for var event in pendingEvents {
                if event.eventType == .transaction, var txData = event.transactionData {
                    // 检查是否需要补全账户
                    let hasAccount = !txData.accountName.isEmpty
                    let hasCreditCard = txData.cardIdentifier != nil && !txData.cardIdentifier!.isEmpty
                    
                    if !hasAccount && !hasCreditCard {
                        // 补全账户信息
                        if selectedAccount.type == .creditCard {
                            txData.cardIdentifier = selectedAccount.cardIdentifier
                        } else {
                            txData.accountName = selectedAccount.displayName
                        }
                        event.transactionData = txData
                    }
                }
                updatedEvents.append(event)
            }
            
            // 添加确认对话消息
            let confirmText = "好的，\(updatedEvents.count)笔记录将使用\(selectedAccount.displayName)"
            messages.append(ChatMessage(type: .assistantText(confirmText)))
            
            // 显示所有事件的确认卡片
            self.editableEvents = updatedEvents
            self.showingEventCards = true
            self.pendingEvents = []  // 清空待处理事件
            return
        }
        
        // 单笔事件的处理逻辑（从 partialData 构建）
        switch needMoreInfo.originalIntent {
        case .transaction:
            if var txData = needMoreInfo.partialTransactionData {
                // 补全账户信息
                if selectedAccount.type == .creditCard {
                    txData.cardIdentifier = selectedAccount.cardIdentifier
                } else {
                    txData.accountName = selectedAccount.displayName
                }
                
                // 添加确认对话消息
                let confirmText = buildSelectionConfirmText(txData: txData, accountName: selectedAccount.displayName)
                messages.append(ChatMessage(type: .assistantText(confirmText)))
                
                // 创建完整事件
                let event = ParsedFinancialEvent(
                    eventType: .transaction,
                    transactionData: txData,
                    assetUpdateData: nil,
                    creditCardData: nil,
                    holdingUpdateData: nil,
                    budgetData: nil,
                    autoPaymentData: nil,
                    needMoreInfoData: nil,
                    queryResponseData: nil
                )
                
                // 显示确认卡片
                self.editableEvents = [event]
                self.showingEventCards = true
            }
            
        case .holdingUpdate:
            if var holdingData = needMoreInfo.partialHoldingData {
                // 补全账户信息
                holdingData.accountName = selectedAccount.displayName
                holdingData.accountId = selectedAccount.id
                
                // 添加确认对话消息
                let actionStr = holdingData.holdingAction == "SELL" ? "卖出" : "买入"
                let confirmText = "好的，\(actionStr)\(Int(holdingData.quantity))股\(holdingData.name)，使用\(selectedAccount.displayName)账户"
                messages.append(ChatMessage(type: .assistantText(confirmText)))
                
                let event = ParsedFinancialEvent(
                    eventType: .holdingUpdate,
                    transactionData: nil,
                    assetUpdateData: nil,
                    creditCardData: nil,
                    holdingUpdateData: holdingData,
                    budgetData: nil,
                    autoPaymentData: nil,
                    needMoreInfoData: nil,
                    queryResponseData: nil
                )
                
                self.editableEvents = [event]
                self.showingEventCards = true
            }
            
        case .autoPayment:
            if var autoPaymentData = needMoreInfo.partialAutoPaymentData {
                // 补全来源账户
                autoPaymentData.sourceAccount = selectedAccount.displayName
                
                // 添加确认对话消息
                let confirmText = "好的，\(autoPaymentData.name)的自动扣款将从\(selectedAccount.displayName)支付"
                messages.append(ChatMessage(type: .assistantText(confirmText)))
                
                let event = ParsedFinancialEvent(
                    eventType: .autoPayment,
                    transactionData: nil,
                    assetUpdateData: nil,
                    creditCardData: nil,
                    holdingUpdateData: nil,
                    budgetData: nil,
                    autoPaymentData: autoPaymentData,
                    needMoreInfoData: nil,
                    queryResponseData: nil
                )
                
                self.editableEvents = [event]
                self.showingEventCards = true
            }
            
        default:
            messages.append(ChatMessage(type: .assistantText("已选择: \(selectedAccount.displayName)")))
        }
    }
    
    // MARK: - 构建选择确认文本
    private func buildSelectionConfirmText(txData: AIRecordParsed, accountName: String) -> String {
        let typeStr = txData.type == .income ? "收入" : "支出"
        let amountStr = String(format: "%.0f", Double(truncating: txData.amount as NSNumber))
        
        if txData.type == .income {
            return "好的，\(txData.description)\(typeStr)\(amountStr)元，存入\(accountName)"
        } else {
            return "好的，\(txData.description)\(typeStr)\(amountStr)元，\(accountName)支付"
        }
    }
    
    // MARK: - 检查是否需要账户选择追问
    private func checkNeedAccountSelection(events: [ParsedFinancialEvent]) -> NeedMoreInfoParsed? {
        // 检查是否有交易事件缺少账户信息
        for event in events {
            if event.eventType == .transaction, let txData = event.transactionData {
                // 如果没有账户名且没有信用卡标识，需要追问
                let hasAccount = !txData.accountName.isEmpty
                let hasCreditCard = txData.cardIdentifier != nil && !txData.cardIdentifier!.isEmpty
                
                if !hasAccount && !hasCreditCard {
                    // 根据交易类型确定追问类型
                    let pickerType: FollowUpPickerType = txData.type == .income ? .incomeAccount : .expenseAccount
                    let question = txData.type == .income ? "请选择收款账户" : "请选择支付账户"
                    
                    return NeedMoreInfoParsed(
                        originalIntent: .transaction,
                        missingFields: ["source_account"],
                        question: question,
                        pickerType: pickerType,
                        partialHoldingData: nil,
                        partialAutoPaymentData: nil,
                        partialTransactionData: txData,
                        partialAssetData: nil,
                        partialCreditCardData: nil,
                        partialBudgetData: nil
                    )
                }
            }
            
            // 检查持仓更新是否缺少账户
            if event.eventType == .holdingUpdate, let holdingData = event.holdingUpdateData {
                if holdingData.accountName == nil || holdingData.accountName?.isEmpty == true {
                    return NeedMoreInfoParsed(
                        originalIntent: .holdingUpdate,
                        missingFields: ["account"],
                        question: "请选择投资账户",
                        pickerType: .investmentAccount,
                        partialHoldingData: holdingData,
                        partialAutoPaymentData: nil,
                        partialTransactionData: nil,
                        partialAssetData: nil,
                        partialCreditCardData: nil,
                        partialBudgetData: nil
                    )
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 开始录音
    private func startRecording() {
        guard authService.isAuthenticated else {
            isRecording = false
            showLoginRequired = true
            return
        }
        // 只有状态已加载且非Pro时才显示订阅页面
        if subscriptionService.isStatusLoaded && !subscriptionService.isProMember {
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
        
        // 检查是否是追问回复
        if let pending = pendingPartialData {
            let combinedText = buildCombinedTextForFollowUp(userInput: recognizedText, pending: pending)
            pendingPartialData = nil
            parseAndRespond(text: combinedText, parsingMessageId: nil)
        } else {
            parseAndRespond(text: recognizedText, parsingMessageId: nil)
        }
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
                    // 检查是否有 NEED_MORE_INFO 事件（需要追问）
                    if let needMoreInfoEvent = events.first(where: { $0.eventType == .needMoreInfo }),
                       let needMoreInfo = needMoreInfoEvent.needMoreInfoData {
                        // 保存部分数据，等待用户补充
                        self.pendingPartialData = needMoreInfo
                        
                        // 根据追问类型显示不同的 UI
                        if needMoreInfo.requiresPicker {
                            // 需要选择器的追问 - 显示选择器卡片
                            self.messages.append(ChatMessage(type: .selectionFollowUp(needMoreInfo)))
                        } else {
                            // 文本追问 - 显示追问消息
                            self.messages.append(ChatMessage(type: .assistantText(needMoreInfo.question)))
                        }
                    } else if let accountFollowUp = self.checkNeedAccountSelection(events: events) {
                        // 检查交易事件是否缺少账户，需要选择器追问
                        // 保存所有事件，选择账户后统一应用
                        self.pendingEvents = events
                        self.pendingPartialData = accountFollowUp
                        self.messages.append(ChatMessage(type: .selectionFollowUp(accountFollowUp)))
                    } else {
                        // 正常流程：设置可编辑事件并显示确认卡片
                        self.editableEvents = events
                        self.showingEventCards = true
                    }
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
    
    // MARK: - 计算属性
    
    /// 是否有可保存的事件（非查询类型）
    private var hasSaveableEvents: Bool {
        editableEvents.contains { event in
            switch event.eventType {
            case .transaction, .assetUpdate, .creditCardUpdate, .holdingUpdate, .budget, .autoPayment:
                return true
            case .queryResponse, .nullStatement, .needMoreInfo:
                return false
            }
        }
    }
    
    /// 事件区域标题
    private var eventSectionTitle: String {
        if hasSaveableEvents {
            return "好的，帮你记录\(editableEvents.count > 1 ? "\(editableEvents.count)笔" : "")："
        } else if editableEvents.first?.eventType == .queryResponse {
            return "为您查询到以下信息："
        } else {
            return "识别结果："
        }
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
    var onPickerSelection: ((SelectedAccountInfo, NeedMoreInfoParsed) -> Void)?
    var onPickerCancel: (() -> Void)?

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
            
        case .selectionFollowUp(let needMoreInfo):
            selectionFollowUpBubble(needMoreInfo: needMoreInfo)
        }
    }
    
    // MARK: - 选择器追问气泡
    @ViewBuilder
    private func selectionFollowUpBubble(needMoreInfo: NeedMoreInfoParsed) -> some View {
        SelectionFollowUpCard(
            needMoreInfo: needMoreInfo,
            onSelection: { selectedAccount in
                onPickerSelection?(selectedAccount, needMoreInfo)
            },
            onCancel: {
                onPickerCancel?()
            }
        )
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
