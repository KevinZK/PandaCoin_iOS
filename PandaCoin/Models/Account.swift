//
//  Account.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

// MARK: - 账户类型
enum AccountType: String, Codable, CaseIterable {
    case bank = "BANK"           // 银行卡
    case investment = "INVESTMENT" // 投资账户
    case cash = "CASH"           // 现金
    case creditCard = "CREDIT_CARD" // 信用卡
    
    var displayName: String {
        switch self {
        case .bank: return "银行卡"
        case .investment: return "投资账户"
        case .cash: return "现金"
        case .creditCard: return "信用卡"
        }
    }
    
    var icon: String {
        switch self {
        case .bank: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.circle.fill"
        }
    }
}

// MARK: - 账户模型
struct Account: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: AccountType
    var balance: Decimal
    let currency: String
    let userId: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case balance
        case currency
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 格式化余额显示
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let number = NSDecimalNumber(decimal: balance)
        return formatter.string(from: number) ?? "0.00"
    }
}

// MARK: - 创建/更新账户请求
struct AccountRequest: Codable {
    let name: String
    let type: AccountType
    let balance: Decimal
    let currency: String?
}

struct UpdateAccountRequest: Codable {
    let name: String?
    let balance: Decimal?
}
