//
//  Investment.swift
//  PandaCoin
//
//  投资账户模型 (如: 富途证券、老虎证券、Coinbase)
//

import Foundation

// MARK: - 投资账户类型
enum InvestmentType: String, Codable, CaseIterable {
    case stock = "STOCK"
    case fund = "FUND"
    case crypto = "CRYPTO"
    case mixed = "MIXED"
    
    var displayName: String {
        switch self {
        case .stock: return "股票账户"
        case .fund: return "基金账户"
        case .crypto: return "加密货币账户"
        case .mixed: return "综合账户"
        }
    }
    
    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .fund: return "chart.pie.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .mixed: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - 投资账户模型
struct Investment: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: InvestmentType
    let institutionName: String?
    let accountNumber: String?
    let currency: String
    let balance: Double
    let userId: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    
    // 关联的持仓
    let holdings: [Holding]?
    
    // 计算属性
    var holdingsMarketValue: Double {
        holdings?.reduce(0) { $0 + $1.marketValue } ?? 0
    }
    
    var totalValue: Double {
        balance + holdingsMarketValue
    }
    
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: balance)) ?? "0.00"
    }
    
    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalValue)) ?? "0.00"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, institutionName, accountNumber
        case currency, balance, userId, createdAt, updatedAt, deletedAt, holdings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(InvestmentType.self, forKey: .type) ?? .mixed
        institutionName = try container.decodeIfPresent(String.self, forKey: .institutionName)
        accountNumber = try container.decodeIfPresent(String.self, forKey: .accountNumber)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        balance = try container.decodeIfPresent(Double.self, forKey: .balance) ?? 0
        userId = try container.decode(String.self, forKey: .userId)
        holdings = try container.decodeIfPresent([Holding].self, forKey: .holdings)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        
        // 日期解析
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let dateString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
}

// MARK: - 请求 DTO
struct CreateInvestmentRequest: Codable {
    let name: String
    let type: InvestmentType
    let institutionName: String?
    let accountNumber: String?
    let currency: String?
    let balance: Double?
}

struct UpdateInvestmentRequest: Codable {
    let name: String?
    let type: InvestmentType?
    let institutionName: String?
    let accountNumber: String?
    let currency: String?
    let balance: Double?
}
