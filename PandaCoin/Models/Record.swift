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
    case payment = "PAYMENT"   // 还款（信用卡/贷款）
    
    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .transfer: return "转账"
        case .payment: return "还款"
        }
    }
}

// MARK: - 记录中嵌套的简化账户信息
struct RecordAccount: Codable {
    let id: String
    let name: String
    let type: String
    let deletedAt: Date?  // 账户软删除时间，nil表示账户正常

    // 账户是否已删除
    var isDeleted: Bool {
        deletedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)

        // 解析 deletedAt（可能是字符串或 Date）
        if let dateString = try container.decodeIfPresent(String.self, forKey: .deletedAt) {
            deletedAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        }
    }

    init(id: String, name: String, type: String, deletedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.deletedAt = deletedAt
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
    let accountId: String?
    let userId: String
    let isConfirmed: Bool       // 是否已确认(AI记账需要)
    let confidence: Double?     // AI解析置信度
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?        // 软删除时间，nil表示未删除

    // 转账/还款场景
    let targetAccountId: String?

    // 信用卡场景
    let creditCardId: String?
    let cardIdentifier: String?

    // 关联数据（后端只返回部分字段）
    var account: RecordAccount?
    var targetAccount: RecordAccount?

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
        case deletedAt
        case targetAccountId
        case creditCardId
        case cardIdentifier
        case account
        case targetAccount
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
        targetAccountId: String? = nil,
        targetAccountName: String? = nil,
        creditCardId: String? = nil,
        cardIdentifier: String? = nil,
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
        self.deletedAt = nil
        self.targetAccountId = targetAccountId
        self.creditCardId = creditCardId
        self.cardIdentifier = cardIdentifier

        if let accountId = accountId, let accountName = accountName {
            self.account = RecordAccount(id: accountId, name: accountName, type: "")
        } else {
            self.account = nil
        }

        if let targetAccountId = targetAccountId, let targetAccountName = targetAccountName {
            self.targetAccount = RecordAccount(id: targetAccountId, name: targetAccountName, type: "")
        } else {
            self.targetAccount = nil
        }
    }

    // MARK: - 软删除相关属性

    /// 记录本身是否已删除
    var isDeleted: Bool {
        deletedAt != nil
    }

    /// 关联的源账户是否已删除
    var isAccountDeleted: Bool {
        account?.isDeleted ?? false
    }

    /// 关联的目标账户是否已删除
    var isTargetAccountDeleted: Bool {
        targetAccount?.isDeleted ?? false
    }
    
    // MARK: - 资金流动描述
    var flowDescription: String? {
        switch type {
        case .expense:
            if let cardId = cardIdentifier, !cardId.isEmpty {
                // 信用卡消费
                return "从 信用卡(\(cardId)) 扣款"
            } else if let accountName = account?.name, !accountName.isEmpty {
                return "从 \(accountName) 扣款"
            }
            return nil
            
        case .income:
            if let accountName = account?.name, !accountName.isEmpty {
                return "存入 \(accountName)"
            }
            return nil
            
        case .transfer:
            let from = account?.name ?? "未知"
            let to = targetAccount?.name ?? "未知"
            return "\(from) → \(to)"
            
        case .payment:
            let from = account?.name ?? "未知"
            if let cardId = cardIdentifier, !cardId.isEmpty {
                return "\(from) → 信用卡(\(cardId))"
            } else if let targetName = targetAccount?.name {
                return "\(from) → \(targetName)"
            }
            return "还款"
        }
    }
    
    // MARK: - 资金流动图标
    var flowIcon: String {
        switch type {
        case .expense: return "↓"
        case .income: return "↑"
        case .transfer: return "⇄"
        case .payment: return "↩"
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
        case .payment:
            return "-¥\(amountStr)"  // 还款显示为负（资金流出）
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

    // 固定收入识别（用于自动入账提示）
    var isFixedIncome: Bool?  // AI 识别是否为固定收入（工资、公积金等）
    var suggestedDay: Int?    // AI 从原文推断的入账日期（如"每月15号"）
    var incomeType: String?   // 收入类型（SALARY, HOUSING_FUND, PENSION 等）
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
