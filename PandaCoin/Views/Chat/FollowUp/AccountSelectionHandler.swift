//
//  AccountSelectionHandler.swift
//  PandaCoin
//
//  账户选择处理器 - 处理缺少账户时的追问和选择逻辑
//

import Foundation

// MARK: - 账户选择处理器
class AccountSelectionHandler {
    
    // MARK: - 检查是否需要账户选择追问
    func checkNeedAccountSelection(events: [ParsedFinancialEvent]) -> NeedMoreInfoParsed? {
        // 检查是否有交易事件缺少账户信息
        for event in events {
            if event.eventType == .transaction, let txData = event.transactionData {
                let hasAccount = !txData.accountName.isEmpty
                let hasCreditCard = txData.cardIdentifier != nil && !txData.cardIdentifier!.isEmpty
                
                if !hasAccount && !hasCreditCard {
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
    
    // MARK: - 将账户应用到多笔事件
    func applyAccountToMultipleEvents(
        _ events: [ParsedFinancialEvent],
        selectedAccount: SelectedAccountInfo
    ) -> (events: [ParsedFinancialEvent], confirmText: String) {
        var updatedEvents: [ParsedFinancialEvent] = []
        
        for var event in events {
            if event.eventType == .transaction, var txData = event.transactionData {
                let hasAccount = !txData.accountName.isEmpty
                let hasCreditCard = txData.cardIdentifier != nil && !txData.cardIdentifier!.isEmpty
                
                if !hasAccount && !hasCreditCard {
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
        
        let confirmText = "好的，\(updatedEvents.count)笔记录将使用\(selectedAccount.displayName)"
        return (updatedEvents, confirmText)
    }
    
    // MARK: - 从部分数据创建完整事件
    func createEventFromPartialData(
        needMoreInfo: NeedMoreInfoParsed,
        selectedAccount: SelectedAccountInfo
    ) -> (events: [ParsedFinancialEvent], confirmText: String)? {
        
        switch needMoreInfo.originalIntent {
        case .transaction:
            return createTransactionEvent(needMoreInfo: needMoreInfo, selectedAccount: selectedAccount)
            
        case .holdingUpdate:
            return createHoldingEvent(needMoreInfo: needMoreInfo, selectedAccount: selectedAccount)
            
        case .autoPayment:
            return createAutoPaymentEvent(needMoreInfo: needMoreInfo, selectedAccount: selectedAccount)
            
        default:
            return nil
        }
    }
    
    // MARK: - 创建交易事件
    private func createTransactionEvent(
        needMoreInfo: NeedMoreInfoParsed,
        selectedAccount: SelectedAccountInfo
    ) -> (events: [ParsedFinancialEvent], confirmText: String)? {
        guard var txData = needMoreInfo.partialTransactionData else { return nil }
        
        if selectedAccount.type == .creditCard {
            txData.cardIdentifier = selectedAccount.cardIdentifier
        } else {
            txData.accountName = selectedAccount.displayName
        }
        
        let confirmText = buildSelectionConfirmText(txData: txData, accountName: selectedAccount.displayName)
        
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
        
        return ([event], confirmText)
    }
    
    // MARK: - 创建持仓事件
    private func createHoldingEvent(
        needMoreInfo: NeedMoreInfoParsed,
        selectedAccount: SelectedAccountInfo
    ) -> (events: [ParsedFinancialEvent], confirmText: String)? {
        guard var holdingData = needMoreInfo.partialHoldingData else { return nil }
        
        holdingData.accountName = selectedAccount.displayName
        holdingData.accountId = selectedAccount.id
        
        let actionStr = holdingData.holdingAction == "SELL" ? "卖出" : "买入"
        let confirmText = "好的，\(actionStr)\(Int(holdingData.quantity))股\(holdingData.name)，使用\(selectedAccount.displayName)账户"
        
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
        
        return ([event], confirmText)
    }
    
    // MARK: - 创建自动扣款事件
    private func createAutoPaymentEvent(
        needMoreInfo: NeedMoreInfoParsed,
        selectedAccount: SelectedAccountInfo
    ) -> (events: [ParsedFinancialEvent], confirmText: String)? {
        guard var autoPaymentData = needMoreInfo.partialAutoPaymentData else { return nil }
        
        autoPaymentData.sourceAccount = selectedAccount.displayName
        
        let confirmText = "好的，\(autoPaymentData.name)的自动扣款将从\(selectedAccount.displayName)支付"
        
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
        
        return ([event], confirmText)
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
}
