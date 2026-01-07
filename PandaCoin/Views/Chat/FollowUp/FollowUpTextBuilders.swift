//
//  FollowUpTextBuilders.swift
//  PandaCoin
//
//  追问文本构建器 - 根据不同事件类型构建追问回复文本
//

import Foundation

// MARK: - 追问文本构建器协议
protocol FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String?
}

// MARK: - 追问文本构建器集合
class FollowUpTextBuilders {
    
    private var builders: [FollowUpTextBuilder] = []
    
    init() {
        // 注册所有构建器
        builders = [
            HoldingFollowUpBuilder(),
            AutoPaymentFollowUpBuilder(),
            TransactionFollowUpBuilder(),
            AssetFollowUpBuilder(),
            CreditCardFollowUpBuilder(),
            BudgetFollowUpBuilder()
        ]
    }
    
    /// 根据待处理数据构建合并文本
    func buildCombinedText(userInput: String, pending: NeedMoreInfoParsed) -> String {
        for builder in builders {
            if builder.canHandle(intent: pending.originalIntent),
               let text = builder.buildText(userInput: userInput, pending: pending) {
                return text
            }
        }
        return userInput
    }
    
    /// 注册自定义构建器（用于扩展）
    func registerBuilder(_ builder: FollowUpTextBuilder) {
        builders.insert(builder, at: 0)  // 优先使用自定义构建器
    }
}

// MARK: - 持仓追问构建器
class HoldingFollowUpBuilder: FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool {
        intent == .holdingUpdate
    }
    
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String? {
        guard let data = pending.partialHoldingData else { return nil }
        
        if pending.missingFields.contains("price") {
            let priceStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "美元", with: "")
                .replacingOccurrences(of: "港币", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            let actionStr = data.holdingAction == "SELL" ? "卖出" : "买入"
            let currencyStr = data.currency == "USD" ? "美元" : (data.currency == "HKD" ? "港币" : "元")
            
            return "\(actionStr)\(Int(data.quantity))股\(data.name)，每股\(priceStr)\(currencyStr)"
        }
        return nil
    }
}

// MARK: - 自动扣款追问构建器
class AutoPaymentFollowUpBuilder: FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool {
        intent == .autoPayment
    }
    
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String? {
        guard let data = pending.partialAutoPaymentData else { return nil }
        
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
}

// MARK: - 交易追问构建器
class TransactionFollowUpBuilder: FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool {
        intent == .transaction
    }
    
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String? {
        guard let data = pending.partialTransactionData else { return nil }
        
        let typeStr = data.type == .income ? "收入" : (data.type == .transfer ? "转账" : "花了")
        
        if pending.missingFields.contains("amount") {
            let amountStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .trimmingCharacters(in: .whitespaces)
            return "\(data.description)\(typeStr)\(amountStr)块"
        } else if pending.missingFields.contains("category") {
            return "\(data.description)\(typeStr)\(data.amount)块，分类是\(userInput)"
        }
        return nil
    }
}

// MARK: - 资产追问构建器
class AssetFollowUpBuilder: FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool {
        intent == .assetUpdate
    }
    
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String? {
        guard let data = pending.partialAssetData else { return nil }
        
        if pending.missingFields.contains("amount") || pending.missingFields.contains("total_value") {
            let amountStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "万", with: "0000")
                .trimmingCharacters(in: .whitespaces)
            return "我有\(amountStr)的\(data.assetName)"
        } else if pending.missingFields.contains("interest_rate") {
            return "\(data.assetName)\(data.totalValue)块，利率\(userInput)"
        } else if pending.missingFields.contains("repayment_day") || pending.missingFields.contains("monthly_payment") {
            return "\(data.assetName)\(data.totalValue)块，\(userInput)"
        }
        return nil
    }
}

// MARK: - 信用卡追问构建器
class CreditCardFollowUpBuilder: FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool {
        intent == .creditCardUpdate
    }
    
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String? {
        guard let data = pending.partialCreditCardData else { return nil }
        
        if pending.missingFields.contains("credit_limit") {
            let limitStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .replacingOccurrences(of: "万", with: "0000")
                .trimmingCharacters(in: .whitespaces)
            return "\(data.name)信用卡额度\(limitStr)"
        } else if pending.missingFields.contains("repayment_due_date") {
            let dayStr = userInput.replacingOccurrences(of: "号", with: "")
                .replacingOccurrences(of: "日", with: "")
                .trimmingCharacters(in: .whitespaces)
            return "\(data.name)信用卡额度\(data.creditLimit ?? 0)，还款日\(dayStr)号"
        }
        return nil
    }
}

// MARK: - 预算追问构建器
class BudgetFollowUpBuilder: FollowUpTextBuilder {
    func canHandle(intent: FinancialEventType) -> Bool {
        intent == .budget
    }
    
    func buildText(userInput: String, pending: NeedMoreInfoParsed) -> String? {
        guard let data = pending.partialBudgetData else { return nil }
        
        if pending.missingFields.contains("amount") || pending.missingFields.contains("target_amount") {
            let amountStr = userInput.replacingOccurrences(of: "元", with: "")
                .replacingOccurrences(of: "块", with: "")
                .trimmingCharacters(in: .whitespaces)
            return "\(data.name)预算\(amountStr)块"
        } else if pending.missingFields.contains("category") {
            return "\(userInput)预算\(data.targetAmount)块"
        }
        return nil
    }
}
