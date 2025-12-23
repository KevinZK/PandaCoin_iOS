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

// MARK: - 记录中嵌套的简化账户信息
struct RecordAccount: Codable {
    let id: String
    let name: String
    let type: String
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
    let accountId: String?
    let userId: String
    let isConfirmed: Bool       // 是否已确认(AI记账需要)
    let confidence: Double?     // AI解析置信度
    let createdAt: Date
    let updatedAt: Date
    
    // 关联数据（后端只返回部分字段）
    var account: RecordAccount?
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case type
        case category
        case description
        case rawText
        case date
        case accountId
        case userId
        case isConfirmed
        case confidence
        case createdAt
        case updatedAt
        case account
    }
    
    // MARK: - 便捷初始化器（用于本地构造）
    init(
        id: String,
        amount: Decimal,
        type: RecordType,
        category: String,
        description: String?,
        date: Date,
        accountId: String?,
        accountName: String? = nil,
        isConfirmed: Bool
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.description = description
        self.rawText = nil
        self.date = date
        self.accountId = accountId
        self.userId = ""
        self.isConfirmed = isConfirmed
        self.confidence = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        if let accountId = accountId, let accountName = accountName {
            self.account = RecordAccount(id: accountId, name: accountName, type: "")
        } else {
            self.account = nil
        }
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
    var accountName: String  // 改为 var，支持用户选择账户后更新
    let description: String
    let date: Date
    let confidence: Double?
    var cardIdentifier: String?  // 信用卡标识（仅当交易涉及信用卡时使用）
}

// MARK: - AI语音记账请求
struct VoiceRecordRequest: Codable {
    let text: String  // 语音转换后的文本
}

// MARK: - AI语音记账响应
struct VoiceRecordResponse: Codable {
    let records: [Record]  // 返回完整的 Record 对象（未确认的）
    let originalText: String
    
    enum CodingKeys: String, CodingKey {
        case records
        case originalText = "original_text"  // 后端实际返回 originalText，需映射
    }
    
    // 自定义解码，兼容驼峰和下划线两种格式
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decode([Record].self, forKey: .records)
        
        // 尝试两种格式
        if let text = try? container.decode(String.self, forKey: .originalText) {
            originalText = text
        } else {
            // 尝试直接用驼峰格式
            let rawContainer = try decoder.container(keyedBy: RawCodingKeys.self)
            originalText = try rawContainer.decode(String.self, forKey: .originalText)
        }
    }
    
    private enum RawCodingKeys: String, CodingKey {
        case originalText
    }
}
