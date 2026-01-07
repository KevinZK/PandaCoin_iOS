//
//  ChatRecordView.swift
//  PandaCoin
//
//  对话式记账视图 - 与熊猫财务官对话记账
//

import SwiftUI
import Combine

// MARK: - 对话式记账视图
struct ChatRecordView: View {
    // 外部传入的图片（从 DashboardView 的拍照/相册按钮获取）
    @Binding var externalImage: UIImage?
    // 控制输入栏显示/隐藏
    @Binding var showInputBar: Bool
    // 外部控制录音状态
    @Binding var isRecording: Bool

    // MARK: - Services
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var recordService = RecordService()
    @ObservedObject private var accountService = AssetService.shared
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var autoIncomeService = AutoIncomeService.shared
    
    // MARK: - 追问管理器
    @StateObject private var followUpManager = FollowUpManager()

    // MARK: - UI State
    @State private var showLoginRequired = false
    @State private var showSubscription = false
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var editableEvents: [ParsedFinancialEvent] = []
    @State private var showingEventCards = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var autoIncomeCancellables = Set<AnyCancellable>()

    // 图片处理状态
    @State private var isProcessingImage = false
    private let ocrService = LocalOCRService.shared
    
    // 尾号更新选择器状态
    @State private var showIdentifierUpdatePicker = false
    @State private var pendingIdentifierUpdate: (cardIdentifier: String, accounts: [Asset])? = nil

    // 用于自动滚动到底部
    @Namespace private var bottomID
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 欢迎消息
                        if messages.isEmpty && !showingEventCards {
                            WelcomeMessageView()
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
                                    followUpManager.cancelFollowUp()
                                    messages.append(ChatMessage(type: .assistantText("好的，已取消。有其他需要记录的吗？")))
                                }
                            )
                        }
                        
                        // 显示可编辑的事件确认卡片
                        if showingEventCards && !editableEvents.isEmpty {
                            EventConfirmationSection(
                                editableEvents: $editableEvents,
                                onConfirm: confirmEvents,
                                onCancel: cancelEvents
                            )
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
            
            // 输入栏
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
        .background(Color.clear)
        .onChange(of: externalImage) { newImage in
            if let image = newImage {
                processImageDirectly(image)
                externalImage = nil
            }
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                startRecording()
            } else {
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
        .sheet(isPresented: $showIdentifierUpdatePicker) {
            if let pending = pendingIdentifierUpdate {
                IdentifierUpdatePickerSheet(
                    cardIdentifier: pending.cardIdentifier,
                    accounts: pending.accounts,
                    onSelect: { account in
                        showIdentifierUpdatePicker = false
                        updateAccountIdentifier(account: account, cardIdentifier: pending.cardIdentifier)
                        pendingIdentifierUpdate = nil
                    },
                    onCancel: {
                        showIdentifierUpdatePicker = false
                        pendingIdentifierUpdate = nil
                        messages.append(ChatMessage(type: .assistantText("好的，已取消添加尾号。")))
                    }
                )
            }
        }
    }
    
    // MARK: - 滚动到底部
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
    
    // MARK: - 权限检查
    private func checkPermission() -> Bool {
        guard authService.isAuthenticated else {
            showLoginRequired = true
            return false
        }
        if subscriptionService.isStatusLoaded && !subscriptionService.isProMember {
            showSubscription = true
            return false
        }
        return true
    }
    
    // MARK: - 发送文本消息
    private func sendTextMessage() {
        guard checkPermission() else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(type: .userText(text)))
        inputText = ""
        messages.append(ChatMessage(type: .assistantParsing))
        
        // 检查是否是追问回复
        if let combinedText = followUpManager.buildCombinedTextForFollowUp(userInput: text) {
            parseAndRespond(text: combinedText)
        } else {
            parseAndRespond(text: text)
        }
    }
    
    // MARK: - 开始录音
    private func startRecording() {
        guard checkPermission() else {
            isRecording = false
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
        
        messages.append(ChatMessage(type: .userVoice(recognizedText)))
        messages.append(ChatMessage(type: .assistantParsing))
        
        if let combinedText = followUpManager.buildCombinedTextForFollowUp(userInput: recognizedText) {
            parseAndRespond(text: combinedText)
        } else {
            parseAndRespond(text: recognizedText)
        }
    }
    
    // MARK: - 直接处理图片
    private func processImageDirectly(_ image: UIImage) {
        guard checkPermission() else { return }
        guard !isProcessingImage else { return }
        isProcessingImage = true
        
        messages.append(ChatMessage(type: .userImage(image)))
        messages.append(ChatMessage(type: .assistantParsing))
        
        ocrService.recognizeText(from: image)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    isProcessingImage = false
                    if case .failure(let error) = completion {
                        removeParsingMessage()
                        messages.append(ChatMessage(type: .assistantError("图片识别失败：\(error.localizedDescription)")))
                    }
                },
                receiveValue: { [self] result in
                    if !result.isValidReceipt {
                        removeParsingMessage()
                        messages.append(ChatMessage(type: .assistantText("这张图片不像是票据哦，请拍摄购物小票、支付截图或外卖订单~")))
                        return
                    }
                    
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
                    parseText += "\n原文: \(result.rawText.prefix(500))"
                    
                    logInfo("📷 票据OCR结果: \(parseText)")
                    parseAndRespond(text: parseText)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - AI解析并响应
    private func parseAndRespond(text: String) {
        recordService.parseVoiceInputUnified(text: text)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.removeParsingMessage()
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("解析失败：\(error.localizedDescription)")))
                }
            } receiveValue: { events in
                self.removeParsingMessage()
                
                if events.isEmpty {
                    self.messages.append(ChatMessage(type: .assistantText("抱歉，没有识别出记账信息，请换个方式描述试试~")))
                    return
                }
                
                // 检查是否是尾号更新请求
                // 判断条件：有尾号、无金额（或金额为0）、是银行类资产
                if let assetEvent = events.first(where: { $0.eventType == .assetUpdate }),
                   let assetData = assetEvent.assetUpdateData,
                   let cardIdentifier = assetData.cardIdentifier,
                   !cardIdentifier.isEmpty {
                    let isBankType = ["BANK", "SAVINGS", "DIGITAL_WALLET"].contains(assetData.assetType.uppercased())
                    let hasNoAmount = assetData.totalValue == 0
                    let isIdentifierUpdate = assetData.isIdentifierUpdate || (isBankType && hasNoAmount)
                    
                    if isIdentifierUpdate {
                        self.handleIdentifierUpdate(assetData: assetData, cardIdentifier: cardIdentifier)
                        return
                    }
                }
                
                // 检查是否有新创建的资产账户需要自动补录交易
                if self.followUpManager.hasPendingTransactionsForNewAccount {
                    // 检查是否是资产创建事件
                    if let assetEvent = events.first(where: { $0.eventType == .assetUpdate }),
                       let assetData = assetEvent.assetUpdateData {
                        // 先显示资产创建成功
                        self.editableEvents = [assetEvent]
                        self.showingEventCards = true
                        return
                    }
                }
                
                // 使用追问管理器处理结果（传入当前可用账户）
                let result = self.followUpManager.processParseResult(events, availableAccounts: self.accountService.accounts)
                
                switch result {
                case .showTextFollowUp(let question):
                    self.messages.append(ChatMessage(type: .assistantText(question)))
                    
                case .showPickerFollowUp(let needMoreInfo):
                    self.messages.append(ChatMessage(type: .selectionFollowUp(needMoreInfo)))
                    
                case .showEventCards(let events):
                    self.editableEvents = events
                    self.showingEventCards = true
                    
                case .noFollowUpNeeded:
                    break
                    
                case .noAccountsGuidance(let guidanceMessage, _):
                    // 显示引导消息，提示用户添加账户
                    self.messages.append(ChatMessage(type: .assistantText(guidanceMessage)))
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 处理选择器选择
    private func handlePickerSelection(_ selectedAccount: SelectedAccountInfo, for needMoreInfo: NeedMoreInfoParsed) {
        // 移除选择器追问气泡
        messages.removeAll { msg in
            if case .selectionFollowUp = msg.type { return true }
            return false
        }
        
        if let result = followUpManager.handlePickerSelection(selectedAccount, for: needMoreInfo) {
            messages.append(ChatMessage(type: .assistantText(result.confirmText)))
            editableEvents = result.events
            showingEventCards = true
        } else {
            messages.append(ChatMessage(type: .assistantText("已选择: \(selectedAccount.displayName)")))
        }
    }
    
    // MARK: - 移除解析中消息
    private func removeParsingMessage() {
        messages.removeAll { msg in
            if case .assistantParsing = msg.type { return true }
            return false
        }
    }
    
    // MARK: - 确认保存事件
    private func confirmEvents(_ events: [ParsedFinancialEvent]) {
        showingEventCards = false

        var accountMap: [String: String] = [:]
        for account in accountService.accounts {
            accountMap[account.name] = account.id
        }

        let fixedIncomeInfo = findFixedIncomeRecord(in: events, accountMap: accountMap)
        
        // 检查是否是新建资产事件且有待补录交易
        let isAssetCreation = events.contains { $0.eventType == .assetUpdate }
        let hasPendingTransactions = followUpManager.hasPendingTransactionsForNewAccount
        
        // 检查是否有银行账户缺少卡号尾号
        let bankAssetWithoutIdentifier = findBankAssetWithoutIdentifier(in: events)

        recordService.saveFinancialEvents(events, accountMap: accountMap, assetService: accountService, authService: AuthService.shared)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("保存失败：\(error.localizedDescription)")))
                }
            } receiveValue: { count in
                self.messages.append(ChatMessage(type: .savedConfirmation(count)))
                self.editableEvents = []
                
                // 刷新账户列表
                self.accountService.fetchAccounts()
                
                // 如果有银行账户没有尾号，显示建议提示
                if let assetName = bankAssetWithoutIdentifier {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.messages.append(ChatMessage(type: .assistantText("💡 小提示：为了区分同一银行的不同卡片，建议添加卡号尾号，例如「\(assetName)尾号1234」")))
                    }
                }

                // 如果是资产创建且有待补录交易，延迟处理自动补录
                if isAssetCreation && hasPendingTransactions {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.handlePendingTransactionsAfterAssetCreation()
                    }
                    return
                }

                if let info = fixedIncomeInfo {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.promptAutoIncome(for: info)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 查找缺少卡号尾号的银行账户
    private func findBankAssetWithoutIdentifier(in events: [ParsedFinancialEvent]) -> String? {
        for event in events {
            if event.eventType == .assetUpdate,
               let assetData = event.assetUpdateData {
                // 只检查银行类账户
                let bankTypes = ["BANK", "SAVINGS", "DIGITAL_WALLET"]
                if bankTypes.contains(assetData.assetType.uppercased()) {
                    // 检查是否缺少卡号尾号
                    if assetData.cardIdentifier == nil || assetData.cardIdentifier?.isEmpty == true {
                        return assetData.assetName
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - 处理资产创建后的待补录交易
    private func handlePendingTransactionsAfterAssetCreation() {
        // 获取最新创建的账户（假设是列表中最后一个）
        guard let newAccount = accountService.accounts.last else {
            followUpManager.clearPendingTransactionsForNewAccount()
            return
        }
        
        if let result = followUpManager.applyPendingTransactionsToNewAccount(newAccount) {
            messages.append(ChatMessage(type: .assistantText(result.confirmText)))
            editableEvents = result.events
            showingEventCards = true
        }
    }
    
    // MARK: - 处理尾号更新请求
    private func handleIdentifierUpdate(assetData: AssetUpdateParsed, cardIdentifier: String) {
        // 查找匹配的账户（同一银行、同类型、无尾号）
        let matchingAccounts = findMatchingAccountsForIdentifierUpdate(assetData: assetData)
        
        if matchingAccounts.isEmpty {
            // 没有找到匹配的账户，提示用户
            messages.append(ChatMessage(type: .assistantText("未找到匹配的\(assetData.institutionName ?? "")账户，请先添加该账户。")))
            return
        }
        
        if matchingAccounts.count == 1 {
            // 只有一个匹配，直接更新
            let account = matchingAccounts[0]
            updateAccountIdentifier(account: account, cardIdentifier: cardIdentifier)
        } else {
            // 多个匹配，需要用户选择
            pendingIdentifierUpdate = (cardIdentifier, matchingAccounts)
            let accountNames = matchingAccounts.map { $0.name }.joined(separator: "、")
            messages.append(ChatMessage(type: .assistantText("发现您有多个\(assetData.institutionName ?? "该银行")的账户（\(accountNames)），请问要为哪个添加尾号 \(cardIdentifier)？")))
            // 显示账户选择器
            showIdentifierUpdatePicker = true
        }
    }
    
    // MARK: - 查找匹配的账户用于尾号更新
    private func findMatchingAccountsForIdentifierUpdate(assetData: AssetUpdateParsed) -> [Asset] {
        let bankTypes: [AssetType] = [.bank, .savings, .digitalWallet]
        
        return accountService.accounts.filter { account in
            // 类型匹配
            guard bankTypes.contains(account.type) else { return false }
            
            // 已有尾号的不需要更新
            if let existingIdentifier = account.cardIdentifier, !existingIdentifier.isEmpty {
                return false
            }
            
            // 机构名称匹配（如果有）
            if let institutionName = assetData.institutionName {
                // 检查账户名称是否包含机构名
                if account.name.contains(institutionName) || 
                   (account.institutionName?.contains(institutionName) ?? false) {
                    return true
                }
                return false
            }
            
            return true
        }
    }
    
    // MARK: - 更新账户尾号
    private func updateAccountIdentifier(account: Asset, cardIdentifier: String) {
        var updatedAccount = account
        updatedAccount.cardIdentifier = cardIdentifier
        
        // 更新账户名称，添加尾号
        if !account.name.contains("(\(cardIdentifier))") && !account.name.contains(cardIdentifier) {
            updatedAccount.name = "\(account.name)(\(cardIdentifier))"
        }
        
        accountService.updateAsset(updatedAccount)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    self.messages.append(ChatMessage(type: .assistantError("更新失败：\(error.localizedDescription)")))
                }
            } receiveValue: { _ in
                self.messages.append(ChatMessage(type: .assistantText("✅ 已为「\(account.name)」添加尾号 \(cardIdentifier)")))
                self.accountService.fetchAccounts()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 取消事件
    private func cancelEvents() {
        withAnimation(.easeOut(duration: 0.2)) {
            showingEventCards = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            editableEvents = []
        }
        messages.append(ChatMessage(type: .assistantText("好的，已取消。有其他记账需要吗？")))
    }

    // MARK: - 自动入账相关
    private func promptAutoIncome(for info: FixedIncomeInfo) {
        let record = info.record
        let incomeType = inferIncomeType(from: record)
        let amount = Double(truncating: record.amount as NSNumber)
        let suggestedDay = record.suggestedDay ?? Calendar.current.component(.day, from: Date())

        autoIncomeService.fetchAutoIncomes()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { autoIncomes in
                    let exists = autoIncomes.contains { existing in
                        let sameType = existing.incomeType == incomeType
                        let amountDiff = abs(existing.amount - amount)
                        let percentDiff = amount > 0 ? amountDiff / amount : 0
                        let similarAmount = percentDiff < 0.1 || amountDiff < 100
                        let dayDiff = abs(existing.dayOfMonth - suggestedDay)
                        let similarDay = dayDiff <= 3 || dayDiff >= 28
                        return sameType && similarAmount && similarDay
                    }

                    if !exists {
                        self.messages.append(ChatMessage(type: .autoIncomePrompt(info)))
                    }
                }
            )
            .store(in: &autoIncomeCancellables)
    }

    func confirmAutoIncome(for info: FixedIncomeInfo, messageId: UUID) {
        messages.removeAll { $0.id == messageId }
        messages.append(ChatMessage(type: .assistantText("好的，正在为你设置自动入账...")))

        let record = info.record
        var targetAccountId = info.accountId
        if targetAccountId.isEmpty {
            targetAccountId = findSuitableAccountId(for: record)
        }

        guard !targetAccountId.isEmpty else {
            removeSettingMessage()
            messages.append(ChatMessage(type: .assistantError("未找到可用的储蓄账户，请先添加银行卡或储蓄账户")))
            return
        }

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
                    self.removeSettingMessage()
                    if case .failure(let error) = completion {
                        self.messages.append(ChatMessage(type: .assistantError("设置失败：\(error.localizedDescription)")))
                    }
                },
                receiveValue: { _ in
                    self.removeSettingMessage()
                    self.messages.append(ChatMessage(type: .assistantText("已设置成功！以后每月都会自动记录这笔收入，你可以在「设置 → 自动入账」中管理 🎉")))
                }
            )
            .store(in: &autoIncomeCancellables)
    }

    func cancelAutoIncome(messageId: UUID) {
        messages.removeAll { $0.id == messageId }
        messages.append(ChatMessage(type: .assistantText("好的，已跳过。有需要时可以在「设置」中手动添加自动入账~")))
    }
    
    private func removeSettingMessage() {
        messages.removeAll { msg in
            if case .assistantText(let text) = msg.type, text.contains("正在为你设置") {
                return true
            }
            return false
        }
    }

    private func findSuitableAccountId(for record: AIRecordParsed) -> String {
        let savingsTypes: [AssetType] = [.bank, .cash, .digitalWallet, .savings]

        if !record.accountName.isEmpty {
            if let account = accountService.accounts.first(where: { $0.name == record.accountName }) {
                if savingsTypes.contains(account.type) {
                    return account.id
                }
            }
        }

        if let account = accountService.accounts.first(where: { savingsTypes.contains($0.type) }) {
            return account.id
        }

        return ""
    }

    private func findFixedIncomeRecord(in events: [ParsedFinancialEvent], accountMap: [String: String]) -> FixedIncomeInfo? {
        for event in events {
            if let record = event.transactionData {
                if record.type == .income && record.isFixedIncome == true {
                    let accountId = accountMap[record.accountName] ?? ""
                    return FixedIncomeInfo(record: record, accountId: accountId)
                }
                if record.type == .income && CategoryMapper.isFixedIncomeCategory(record.category) {
                    let accountId = accountMap[record.accountName] ?? ""
                    return FixedIncomeInfo(record: record, accountId: accountId)
                }
            }
        }
        return nil
    }

    private func inferIncomeType(from record: AIRecordParsed) -> IncomeType {
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
        return CategoryMapper.inferIncomeType(from: record.category)
    }
}

#Preview {
    ChatRecordView(externalImage: .constant(nil), showInputBar: .constant(true), isRecording: .constant(false))
}
