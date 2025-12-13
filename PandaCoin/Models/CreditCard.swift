//
//  CreditCard.swift
//  PandaCoin
//
//  信用卡数据模型
//

import Foundation

// MARK: - 信用卡模型
struct CreditCard: Identifiable, Codable, Equatable {
    let id: String
    var name: String                    // 卡片名称（如"招商信用卡"）
    var institutionName: String         // 发卡银行
    var cardIdentifier: String          // 唯一标识（如尾号"1234"）
    var creditLimit: Double             // 授信额度
    var currentBalance: Double          // 当前待还金额
    var repaymentDueDate: String?       // 还款日（如"04"表示每月4号）
    var currency: String                // 货币
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case institutionName
        case cardIdentifier
        case creditLimit
        case currentBalance
        case repaymentDueDate
        case currency
        case createdAt
        case updatedAt
    }
    
    // 可用额度
    var availableCredit: Double {
        return max(0, creditLimit - currentBalance)
    }
    
    // 额度使用率
    var usageRate: Double {
        guard creditLimit > 0 else { return 0 }
        return min(1.0, currentBalance / creditLimit)
    }
    
    // 显示名称（包含标识）
    var displayName: String {
        if cardIdentifier.isEmpty {
            return name
        }
        return "\(name) (\(cardIdentifier))"
    }
    
    // 格式化还款日显示
    var formattedDueDate: String? {
        guard let dueDate = repaymentDueDate, !dueDate.isEmpty else { return nil }
        return "每月\(dueDate)号"
    }
}

// MARK: - 创建信用卡请求
struct CreateCreditCardRequest: Codable {
    let name: String
    let institutionName: String
    let cardIdentifier: String
    let creditLimit: Double
    let repaymentDueDate: String?
    let currency: String
    // 后端期望 camelCase，不需要 CodingKeys 映射
}

// MARK: - 更新信用卡请求
struct UpdateCreditCardRequest: Codable {
    let name: String?
    let institutionName: String?
    let cardIdentifier: String?
    let creditLimit: Double?
    let currentBalance: Double?
    let repaymentDueDate: String?
    let currency: String?
    // 后端期望 camelCase，不需要 CodingKeys 映射
}

// MARK: - 信用卡列表响应
struct CreditCardListResponse: Codable {
    let cards: [CreditCard]
    let total: Int
}

// MARK: - 更新信用卡余额请求
struct UpdateCreditCardBalanceRequest: Codable {
    let cardIdentifier: String
    let amount: Double
    let transactionType: String  // "EXPENSE" 增加待还, "PAYMENT" 减少待还
    // 后端期望 camelCase，不需要 CodingKeys 映射
}
