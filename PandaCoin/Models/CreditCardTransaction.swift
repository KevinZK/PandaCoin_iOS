//
//  CreditCardTransaction.swift
//  PandaCoin
//
//  信用卡消费记录模型
//

import Foundation

// MARK: - 信用卡消费记录
struct CreditCardTransaction: Identifiable, Codable {
    let id: String
    let creditCardId: String
    let amount: Double
    let type: String           // EXPENSE, PAYMENT
    let category: String
    let description: String?
    let date: Date
    let recordId: String?
    let createdAt: Date
    let updatedAt: Date
    
    var isExpense: Bool { type == "EXPENSE" }
    var isPayment: Bool { type == "PAYMENT" }
    
    // 格式化金额显示
    var formattedAmount: String {
        let prefix = isExpense ? "-" : "+"
        return "\(prefix)¥\(String(format: "%.2f", amount))"
    }
}

// MARK: - 消费记录汇总
struct TransactionSummary: Codable {
    let totalExpense: Double
    let totalPayment: Double
    let balance: Double
}

// MARK: - 获取消费记录响应
struct CreditCardTransactionsResponse: Codable {
    let transactions: [CreditCardTransaction]
    let summary: TransactionSummary
}

// MARK: - 创建消费记录请求
struct CreateCreditCardTransactionRequest: Codable {
    let cardIdentifier: String
    let amount: Double
    let type: String           // EXPENSE, PAYMENT
    let category: String
    let description: String?
    let date: Date?
}

// MARK: - 创建消费记录响应
struct CreateCreditCardTransactionResponse: Codable {
    let transaction: CreditCardTransaction
    let creditCard: CreditCard
    let record: RecordData?
    
    struct RecordData: Codable {
        let id: String
        let amount: Double
        let type: String
        let category: String
    }
}
