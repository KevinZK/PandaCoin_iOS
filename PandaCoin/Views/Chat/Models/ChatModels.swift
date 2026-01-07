//
//  ChatModels.swift
//  PandaCoin
//
//  对话式记账 - 数据模型
//

import SwiftUI

// MARK: - 固定收入信息（用于自动入账提示）
struct FixedIncomeInfo {
    let record: AIRecordParsed
    let accountId: String  // 记录收入时使用的账户 ID
}

// MARK: - 保存事件摘要（用于确认消息）
struct SavedEventsSummary {
    let totalCount: Int
    let transactionCount: Int
    let assetUpdateCount: Int
    let creditCardCount: Int
    let holdingCount: Int
    let budgetCount: Int
    let autoPaymentCount: Int
    
    init(events: [ParsedFinancialEvent]) {
        var transaction = 0
        var asset = 0
        var credit = 0
        var holding = 0
        var budget = 0
        var autoPayment = 0
        
        for event in events {
            switch event.eventType {
            case .transaction:
                transaction += 1
            case .assetUpdate:
                asset += 1
            case .creditCardUpdate:
                credit += 1
            case .holdingUpdate:
                holding += 1
            case .budget:
                budget += 1
            case .autoPayment:
                autoPayment += 1
            case .needMoreInfo, .queryResponse, .nullStatement:
                break
            }
        }
        
        self.totalCount = transaction + asset + credit + holding + budget + autoPayment
        self.transactionCount = transaction
        self.assetUpdateCount = asset
        self.creditCardCount = credit
        self.holdingCount = holding
        self.budgetCount = budget
        self.autoPaymentCount = autoPayment
    }
    
    /// 生成确认消息文本
    var confirmationMessage: String {
        // 只有一种类型时，显示特定消息
        if transactionCount > 0 && assetUpdateCount == 0 && creditCardCount == 0 && holdingCount == 0 && budgetCount == 0 && autoPaymentCount == 0 {
            return "已记录\(transactionCount)笔交易！继续保持好习惯 💪"
        }
        
        if assetUpdateCount > 0 && transactionCount == 0 && creditCardCount == 0 && holdingCount == 0 && budgetCount == 0 && autoPaymentCount == 0 {
            return "✅ 资产信息已更新"
        }
        
        if creditCardCount > 0 && transactionCount == 0 && assetUpdateCount == 0 && holdingCount == 0 && budgetCount == 0 && autoPaymentCount == 0 {
            return "✅ 信用卡信息已更新"
        }
        
        if holdingCount > 0 && transactionCount == 0 && assetUpdateCount == 0 && creditCardCount == 0 && budgetCount == 0 && autoPaymentCount == 0 {
            return "✅ 持仓信息已更新"
        }
        
        if budgetCount > 0 && transactionCount == 0 && assetUpdateCount == 0 && creditCardCount == 0 && holdingCount == 0 && autoPaymentCount == 0 {
            return "✅ 预算已设置"
        }
        
        if autoPaymentCount > 0 && transactionCount == 0 && assetUpdateCount == 0 && creditCardCount == 0 && holdingCount == 0 && budgetCount == 0 {
            return "✅ 自动扣款已设置"
        }
        
        // 混合类型时，显示通用消息
        return "已保存\(totalCount)条记录 ✅"
    }
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
    case savedConfirmation(SavedEventsSummary)  // 保存成功确认（带事件类型信息）
    case autoIncomePrompt(FixedIncomeInfo)     // 自动入账提示（带确认/取消按钮）
    case selectionFollowUp(NeedMoreInfoParsed) // 选择器追问卡片
    
    var isVoice: Bool {
        if case .userVoice = self { return true }
        return false
    }
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
