//
//  Record.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

// MARK: - 记账类型
enum RecordType: String, Codable {
    case expense = "EXPENSE"   // 支出
    case income = "INCOME"     // 收入
    case transfer = "TRANSFER" // 转账
    
    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .transfer: return "转账"
        }
    }
}

// MARK: - 记账记录
struct Record: Codable, Identifiable {
    let id: String
    let amount: Decimal
    let type: RecordType
    let category: String
    let description: String?
    let rawText: String?        // AI语音原始文本
    let date: Date
    let accountId: String
    let userId: String
    let isConfirmed: Bool       // 是否已确认(AI记账需要)
    let confidence: Double?     // AI解析置信度
    let createdAt: Date
    let updatedAt: Date
    
    // 关联数据
    var account: Account?
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case type
        case category
        case description
        case rawText = "raw_text"
        case date
        case accountId = "account_id"
        case userId = "user_id"
        case isConfirmed = "is_confirmed"
        case confidence
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case account
    }
    
    // 格式化金额显示
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let number = NSDecimalNumber(decimal: amount)
        let amountStr = formatter.string(from: number) ?? "0.00"
        
        switch type {
        case .expense:
            return "-¥\(amountStr)"
        case .income:
            return "+¥\(amountStr)"
        case .transfer:
            return "¥\(amountStr)"
        }
    }
}

// MARK: - 创建记账请求
struct RecordRequest: Codable {
    let amount: Decimal
    let type: RecordType
    let category: String
    let description: String?
    let date: Date?
    let accountId: String
}

// MARK: - AI语音记账解析结果
struct AIRecordParsed: Codable {
    let type: RecordType
    let amount: Decimal
    let category: String
    let accountName: String
    let description: String
    let date: Date
    let confidence: Double?
}

// MARK: - AI语音记账请求
struct VoiceRecordRequest: Codable {
    let text: String  // 语音转换后的文本
}

// MARK: - AI语音记账响应
struct VoiceRecordResponse: Codable {
    let records: [AIRecordParsed]
    let needConfirm: Bool
    
    enum CodingKeys: String, CodingKey {
        case records
        case needConfirm = "need_confirm"
    }
}
