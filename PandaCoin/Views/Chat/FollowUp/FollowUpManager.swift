//
//  FollowUpManager.swift
//  PandaCoin
//
//  追问功能管理器 - 可扩展的追问处理核心模块
//

import SwiftUI
import Combine

// MARK: - 追问处理结果
enum FollowUpResult {
    case showTextFollowUp(String)                    // 显示文本追问
    case showPickerFollowUp(NeedMoreInfoParsed)      // 显示选择器追问
    case showEventCards([ParsedFinancialEvent])      // 直接显示事件卡片
    case noFollowUpNeeded                            // 无需追问
    case noAccountsGuidance(String, [ParsedFinancialEvent])  // 无可用账户，显示引导消息
}

// MARK: - 追问管理器
/// 负责管理所有追问逻辑，支持扩展新的追问类型
class FollowUpManager: ObservableObject {
    
    // MARK: - 状态
    @Published var pendingPartialData: NeedMoreInfoParsed? = nil
    @Published var pendingEvents: [ParsedFinancialEvent] = []
    
    // 待补录的交易（用户添加账户后自动补录）
    @Published var pendingTransactionsForNewAccount: [ParsedFinancialEvent] = []
    
    // MARK: - 文本构建器
    private let textBuilders = FollowUpTextBuilders()
    
    // MARK: - 账户选择处理器
    private let accountHandler = AccountSelectionHandler()
    
    // MARK: - 处理解析结果
    /// 分析解析结果，决定是否需要追问
    func processParseResult(_ events: [ParsedFinancialEvent], availableAccounts: [Asset] = []) -> FollowUpResult {
        // 1. 检查是否有 NEED_MORE_INFO 事件（后端返回的追问）
        if let needMoreInfoEvent = events.first(where: { $0.eventType == .needMoreInfo }),
           let needMoreInfo = needMoreInfoEvent.needMoreInfoData {
            pendingPartialData = needMoreInfo
            
            if needMoreInfo.requiresPicker {
                // 检查是否有可用账户，如果没有则不显示选择器
                let hasAvailableAccounts = checkHasAvailableAccounts(for: needMoreInfo.pickerType, accounts: availableAccounts)
                
                if hasAvailableAccounts {
                    return .showPickerFollowUp(needMoreInfo)
                } else {
                    // 无可用账户，使用后端返回的 question（已包含引导信息）
                    return .showTextFollowUp(needMoreInfo.question)
                }
            } else {
                return .showTextFollowUp(needMoreInfo.question)
            }
        }
        
        // 2. 检查交易事件是否缺少账户（客户端追问）
        if let accountFollowUp = accountHandler.checkNeedAccountSelection(events: events) {
            // 2.1 检查是否有可用账户
            let hasAvailableAccounts = checkHasAvailableAccounts(for: accountFollowUp.pickerType, accounts: availableAccounts)
            
            if !hasAvailableAccounts {
                // 无可用账户，存储待补录交易并返回引导消息
                pendingTransactionsForNewAccount = events
                let guidanceMessage = buildNoAccountGuidanceMessage(for: accountFollowUp.pickerType)
                return .noAccountsGuidance(guidanceMessage, events)
            }
            
            pendingEvents = events
            pendingPartialData = accountFollowUp
            return .showPickerFollowUp(accountFollowUp)
        }
        
        // 3. 无需追问，直接显示事件卡片
        return .showEventCards(events)
    }
    
    // MARK: - 检查是否有可用账户
    private func checkHasAvailableAccounts(for pickerType: FollowUpPickerType?, accounts: [Asset]) -> Bool {
        guard let pickerType = pickerType else { return true }

        switch pickerType {
        case .expenseAccount, .incomeAccount, .autoPaymentSource:
            // 支出/收入/自动扣款需要流动资产账户
            let liquidTypes: [AssetType] = [.bank, .cash, .digitalWallet, .savings, .otherAsset]
            return accounts.contains { liquidTypes.contains($0.type) }
        case .investmentAccount:
            // 投资需要证券/加密货币/养老金账户
            let investmentTypes: [AssetType] = [.investment, .crypto, .retirement]
            return accounts.contains { investmentTypes.contains($0.type) }
        default:
            return !accounts.isEmpty
        }
    }
    
    // MARK: - 构建无账户引导消息
    private func buildNoAccountGuidanceMessage(for pickerType: FollowUpPickerType?) -> String {
        guard let pickerType = pickerType else {
            return "Finboo发现您还没有可关联的资产账户。为了精准记录，我可以帮您添加一个，您可以这样对我说：\"我的花旗银行储蓄卡有4000$\""
        }
        
        switch pickerType {
        case .expenseAccount, .incomeAccount:
            return "Finboo发现您还没有可关联的资产账户。为了精准记录，我可以帮您添加一个，您可以这样对我说：\"我的花旗银行储蓄卡有4000$\""
        case .investmentAccount:
            return "Finboo发现您还没有可关联的投资账户。为了精准记录，我可以帮您添加一个，您可以这样对我说：\"我在富途证券有10万资金\""
        default:
            return "Finboo发现您还没有可关联的账户。为了精准记录，我可以帮您添加一个，您可以这样对我说：\"我的花旗银行储蓄卡有4000$\""
        }
    }
    
    // MARK: - 处理用户文本回复（追问回复）
    /// 将用户输入与待处理数据合并，生成完整的解析文本
    func buildCombinedTextForFollowUp(userInput: String) -> String? {
        guard let pending = pendingPartialData else { return nil }
        
        let combinedText = textBuilders.buildCombinedText(
            userInput: userInput,
            pending: pending
        )
        
        // 清除待处理数据
        pendingPartialData = nil
        
        return combinedText
    }
    
    // MARK: - 处理选择器选择
    /// 处理用户从选择器中选择账户的操作
    func handlePickerSelection(
        _ selectedAccount: SelectedAccountInfo,
        for needMoreInfo: NeedMoreInfoParsed
    ) -> (events: [ParsedFinancialEvent], confirmText: String)? {
        // 清除待处理数据
        pendingPartialData = nil
        
        // 如果有保存的多笔事件，将账户应用到所有缺少账户的事件
        if !pendingEvents.isEmpty {
            let result = accountHandler.applyAccountToMultipleEvents(
                pendingEvents,
                selectedAccount: selectedAccount
            )
            pendingEvents = []
            return result
        }
        
        // 单笔事件的处理逻辑
        return accountHandler.createEventFromPartialData(
            needMoreInfo: needMoreInfo,
            selectedAccount: selectedAccount
        )
    }
    
    // MARK: - 取消追问
    func cancelFollowUp() {
        pendingPartialData = nil
        pendingEvents = []
    }
    
    // MARK: - 检查是否有待处理的追问
    var hasPendingFollowUp: Bool {
        pendingPartialData != nil
    }
    
    // MARK: - 检查是否有待补录的交易
    var hasPendingTransactionsForNewAccount: Bool {
        !pendingTransactionsForNewAccount.isEmpty
    }
    
    // MARK: - 处理新账户创建后的待补录交易
    /// 当用户添加新账户后，自动将待补录的交易关联到新账户
    func applyPendingTransactionsToNewAccount(_ newAccount: Asset) -> (events: [ParsedFinancialEvent], confirmText: String)? {
        guard !pendingTransactionsForNewAccount.isEmpty else { return nil }
        
        let selectedAccount = SelectedAccountInfo(
            id: newAccount.id,
            displayName: newAccount.name,
            type: .account,
            icon: newAccount.type.icon,
            cardIdentifier: nil
        )
        
        let result = accountHandler.applyAccountToMultipleEvents(
            pendingTransactionsForNewAccount,
            selectedAccount: selectedAccount
        )
        
        // 清空待补录交易
        pendingTransactionsForNewAccount = []
        
        let confirmText = "账户添加成功！之前的\(result.events.count)笔记录已自动关联到「\(newAccount.name)」"
        return (result.events, confirmText)
    }
    
    // MARK: - 清空待补录交易
    func clearPendingTransactionsForNewAccount() {
        pendingTransactionsForNewAccount = []
    }
}
