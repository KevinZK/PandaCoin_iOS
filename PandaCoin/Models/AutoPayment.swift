//
//  AutoPayment.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/25.
//

import Foundation

// MARK: - 扣款类型
enum PaymentType: String, Codable, CaseIterable {
    case creditCardFull = "CREDIT_CARD_FULL"
    case creditCardMin = "CREDIT_CARD_MIN"
    case loan = "LOAN"
    case mortgage = "MORTGAGE"
    case subscription = "SUBSCRIPTION"
    
    var displayName: String {
        switch self {
        case .creditCardFull: return "信用卡全额还款"
        case .creditCardMin: return "信用卡最低还款"
        case .loan: return "贷款还款"
        case .mortgage: return "房贷还款"
        case .subscription: return "订阅扣款"
        }
    }
    
    var icon: String {
        switch self {
        case .creditCardFull, .creditCardMin: return "creditcard.fill"
        case .loan: return "car.fill"
        case .mortgage: return "house.fill"
        case .subscription: return "repeat.circle.fill"
        }
    }
}

// MARK: - 余额不足处理策略
enum InsufficientFundsPolicy: String, Codable, CaseIterable {
    case notify = "NOTIFY"
    case retryNextDay = "RETRY_NEXT_DAY"
    case partialPay = "PARTIAL_PAY"
    case tryNextSource = "TRY_NEXT_SOURCE"
    case skip = "SKIP"
    
    var displayName: String {
        switch self {
        case .notify: return "仅通知我"
        case .retryNextDay: return "次日重试"
        case .partialPay: return "部分还款"
        case .tryNextSource: return "尝试下一个账户"
        case .skip: return "跳过本次"
        }
    }
    
    var description: String {
        switch self {
        case .notify: return "余额不足时发送通知提醒"
        case .retryNextDay: return "第二天自动重试扣款"
        case .partialPay: return "扣除可用余额作为部分还款"
        case .tryNextSource: return "按优先级尝试其他来源账户"
        case .skip: return "跳过本次，等待下个月"
        }
    }
}

// MARK: - 来源账户配置
struct SourceAccountConfig: Codable, Identifiable, Equatable {
    let id: String
    let accountId: String
    let priority: Int
    let account: AccountInfo
    
    struct AccountInfo: Codable, Equatable {
        let id: String
        let name: String
        let type: String
        let balance: Double
    }
}

// MARK: - 自动扣款配置模型
struct AutoPayment: Codable, Identifiable {
    let id: String
    let name: String
    let paymentType: PaymentType
    let creditCardId: String?
    let liabilityAccountId: String?
    let fixedAmount: Double?
    let dayOfMonth: Int
    let executeTime: String
    let reminderDaysBefore: Int
    let insufficientFundsPolicy: InsufficientFundsPolicy
    let isEnabled: Bool
    let lastExecutedAt: Date?
    let nextExecuteAt: Date?
    
    // 贷款进度跟踪
    let totalPeriods: Int?
    let completedPeriods: Int
    let startDate: Date?
    let remainingPeriods: Int?
    
    let createdAt: Date
    let updatedAt: Date
    
    // 关联信息
    let creditCard: CreditCardInfo?
    let liabilityAccount: LiabilityAccountInfo?
    let sources: [SourceAccountConfig]
    
    struct CreditCardInfo: Codable {
        let id: String
        let name: String
        let institutionName: String?
        let cardIdentifier: String?
    }
    
    struct LiabilityAccountInfo: Codable {
        let id: String
        let name: String
        let type: String
        let balance: Double
        let interestRate: Double?
        let loanTermMonths: Int?
        let monthlyPayment: Double?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, paymentType, creditCardId, liabilityAccountId
        case fixedAmount, dayOfMonth, executeTime
        case reminderDaysBefore, insufficientFundsPolicy, isEnabled
        case lastExecutedAt, nextExecuteAt, createdAt, updatedAt
        case creditCard, liabilityAccount, sources
        case totalPeriods, completedPeriods, startDate, remainingPeriods
    }
    
    // 格式化显示
    var formattedAmount: String? {
        guard let amount = effectiveAmount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        return formatter.string(from: NSNumber(value: amount))
    }
    
    // 实际扣款金额（固定金额或月供）
    var effectiveAmount: Double? {
        if let fixed = fixedAmount {
            return fixed
        }
        return liabilityAccount?.monthlyPayment
    }
    
    var formattedNextExecuteDate: String? {
        guard let date = nextExecuteAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
    
    // 还款进度百分比
    var progressPercentage: Double {
        guard let total = totalPeriods, total > 0 else { return 0 }
        return Double(completedPeriods) / Double(total)
    }
    
    // 进度描述
    var progressDescription: String? {
        guard let total = totalPeriods else { return nil }
        return "\(completedPeriods)/\(total)期"
    }
    
    // 来源账户描述
    var sourcesDescription: String {
        guard !sources.isEmpty else { return "未设置扣款账户" }
        if sources.count == 1 {
            return sources[0].account.name
        }
        return sources.map { $0.account.name }.joined(separator: " → ")
    }
}

// MARK: - 来源账户请求
struct SourceAccountRequest: Codable {
    let accountId: String
    let priority: Int
}

// MARK: - 创建自动扣款请求
struct CreateAutoPaymentRequest: Codable {
    let name: String
    let paymentType: PaymentType
    let creditCardId: String?
    let liabilityAccountId: String?
    let sourceAccounts: [SourceAccountRequest]?
    let fixedAmount: Double?
    let dayOfMonth: Int
    let executeTime: String?
    let reminderDaysBefore: Int?
    let insufficientFundsPolicy: InsufficientFundsPolicy?
    let totalPeriods: Int?
    let completedPeriods: Int?
    let startDate: String?
    let isEnabled: Bool?
}

// MARK: - 更新自动扣款请求
struct UpdateAutoPaymentRequest: Codable {
    let name: String?
    let paymentType: PaymentType?
    let creditCardId: String?
    let liabilityAccountId: String?
    let sourceAccounts: [SourceAccountRequest]?
    let fixedAmount: Double?
    let dayOfMonth: Int?
    let executeTime: String?
    let reminderDaysBefore: Int?
    let insufficientFundsPolicy: InsufficientFundsPolicy?
    let totalPeriods: Int?
    let completedPeriods: Int?
    let startDate: String?
    let isEnabled: Bool?
}

// MARK: - 执行日志
struct AutoPaymentLog: Codable, Identifiable {
    let id: String
    let status: String
    let amount: Double
    let sourceBalance: Double?
    let recordId: String?
    let message: String?
    let executedAt: Date
    
    var statusIcon: String {
        switch status {
        case "SUCCESS": return "checkmark.circle.fill"
        case "FAILED": return "xmark.circle.fill"
        case "INSUFFICIENT_FUNDS": return "exclamationmark.triangle.fill"
        case "PARTIAL": return "circle.lefthalf.filled"
        case "SKIPPED": return "arrow.right.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    var statusColor: String {
        switch status {
        case "SUCCESS": return "green"
        case "FAILED": return "red"
        case "INSUFFICIENT_FUNDS": return "orange"
        case "PARTIAL": return "yellow"
        case "SKIPPED": return "gray"
        default: return "gray"
        }
    }
    
    var statusDescription: String {
        switch status {
        case "SUCCESS": return "扣款成功"
        case "FAILED": return "扣款失败"
        case "INSUFFICIENT_FUNDS": return "余额不足"
        case "PARTIAL": return "部分扣款"
        case "SKIPPED": return "已跳过"
        default: return status
        }
    }
}

// MARK: - 月供计算结果
struct MonthlyPaymentCalculation: Codable {
    let monthlyPayment: Double
    let totalPayment: Double
    let totalInterest: Double
}

// MARK: - 执行结果
struct AutoPaymentExecutionResult: Codable {
    let success: Bool
    let amount: Double?
    let recordId: String?
    let message: String?
}
