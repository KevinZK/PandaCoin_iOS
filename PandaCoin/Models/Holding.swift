//
//  Holding.swift
//  PandaCoin
//
//  Created by kevin on 2026/01/03.
//

import Foundation

// MARK: - 持仓类型
enum HoldingType: String, Codable, CaseIterable {
    case stock = "STOCK"
    case etf = "ETF"
    case fund = "FUND"
    case bond = "BOND"
    case crypto = "CRYPTO"
    case option = "OPTION"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .stock: return "股票"
        case .etf: return "ETF"
        case .fund: return "基金"
        case .bond: return "债券"
        case .crypto: return "数字货币"
        case .option: return "期权"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .etf: return "chart.bar.doc.horizontal"
        case .fund: return "chart.pie.fill"
        case .bond: return "doc.text.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .option: return "chart.xyaxis.line"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - 市场类型
enum MarketType: String, Codable, CaseIterable {
    case us = "US"
    case hk = "HK"
    case cn = "CN"
    case crypto = "CRYPTO"
    case global = "GLOBAL"

    var displayName: String {
        switch self {
        case .us: return "美股"
        case .hk: return "港股"
        case .cn: return "A股"
        case .crypto: return "加密货币"
        case .global: return "全球"
        }
    }

    var currencyCode: String {
        switch self {
        case .us, .crypto: return "USD"
        case .hk: return "HKD"
        case .cn: return "CNY"
        case .global: return "USD"
        }
    }
}

// MARK: - 持仓交易类型
enum HoldingTransactionType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
    case dividend = "DIVIDEND"
    case transferIn = "TRANSFER_IN"
    case transferOut = "TRANSFER_OUT"

    var displayName: String {
        switch self {
        case .buy: return "买入"
        case .sell: return "卖出"
        case .dividend: return "分红"
        case .transferIn: return "转入"
        case .transferOut: return "转出"
        }
    }

    var color: String {
        switch self {
        case .buy, .transferIn: return "expense" // 支出（减少现金）
        case .sell, .dividend, .transferOut: return "income" // 收入（增加现金）
        }
    }
}

// MARK: - 持仓模型
struct Holding: Codable, Identifiable, Hashable {
    let id: String
    let accountId: String
    let userId: String
    let name: String
    let displayName: String?
    let type: HoldingType
    let market: MarketType
    let tickerCode: String?
    let codeVerified: Bool
    let codeSource: String?           // AI, YFINANCE, COINGECKO, MANUAL
    let quantity: Double
    let avgCostPrice: Double
    
    // 价格信息 (定时更新)
    let currentPrice: Double?
    let previousClose: Double?         // 前收盘价
    let priceChange: Double?           // 价格变动
    let priceChangePercent: Double?    // 价格变动百分比
    let lastPriceAt: Date?
    let priceSource: String?           // YFINANCE, COINGECKO, AKSHARE, MANUAL
    
    // 计算字段 (后端计算)
    let currentValue: Double?          // 当前市值
    let profitLoss: Double?            // 盈亏金额
    let profitLossPercent: Double?     // 盈亏百分比
    
    let currency: String
    let createdAt: Date
    let updatedAt: Date

    // 可选的账户信息
    let account: AccountInfo?

    // 计算属性 - 使用后端计算的值，如果没有则本地计算
    var marketValue: Double {
        if let value = currentValue { return value }
        let price = currentPrice ?? avgCostPrice
        return quantity * price
    }

    var totalCost: Double {
        return quantity * avgCostPrice
    }

    var unrealizedPnL: Double {
        if let pnl = profitLoss { return pnl }
        return marketValue - totalCost
    }

    var unrealizedPnLPercent: Double {
        if let pnlPercent = profitLossPercent { return pnlPercent }
        guard totalCost > 0 else { return 0 }
        return (unrealizedPnL / totalCost) * 100
    }

    var isProfitable: Bool {
        return unrealizedPnL >= 0
    }
    
    // 今日涨跌 - 使用后端计算的值
    var todayChange: Double {
        return priceChange ?? 0
    }
    
    var todayChangePercent: Double {
        return priceChangePercent ?? 0
    }
    
    // 是否有实时价格
    var hasRealTimePrice: Bool {
        return currentPrice != nil && lastPriceAt != nil
    }
    
    // 价格更新时间格式化
    var formattedPriceUpdateTime: String? {
        guard let date = lastPriceAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // 格式化市值显示
    var formattedMarketValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: marketValue)) ?? "0.00"
    }

    // 格式化盈亏显示
    var formattedPnL: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: unrealizedPnL)) ?? "0.00"
    }

    // 格式化盈亏百分比
    var formattedPnLPercent: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 1
        formatter.positivePrefix = "+"
        return (formatter.string(from: NSNumber(value: unrealizedPnLPercent)) ?? "0.00") + "%"
    }

    enum CodingKeys: String, CodingKey {
        case id, accountId, userId, name, displayName, type, market
        case tickerCode, codeVerified, codeSource, quantity, avgCostPrice
        case currentPrice, previousClose, priceChange, priceChangePercent
        case lastPriceAt, priceSource, currentValue, profitLoss, profitLossPercent
        case currency, createdAt, updatedAt, account
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        accountId = try container.decode(String.self, forKey: .accountId)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        type = try container.decode(HoldingType.self, forKey: .type)
        market = try container.decodeIfPresent(MarketType.self, forKey: .market) ?? .us
        tickerCode = try container.decodeIfPresent(String.self, forKey: .tickerCode)
        codeVerified = try container.decodeIfPresent(Bool.self, forKey: .codeVerified) ?? false
        codeSource = try container.decodeIfPresent(String.self, forKey: .codeSource)
        quantity = try container.decode(Double.self, forKey: .quantity)
        avgCostPrice = try container.decode(Double.self, forKey: .avgCostPrice)
        
        // 价格信息
        currentPrice = try container.decodeIfPresent(Double.self, forKey: .currentPrice)
        previousClose = try container.decodeIfPresent(Double.self, forKey: .previousClose)
        priceChange = try container.decodeIfPresent(Double.self, forKey: .priceChange)
        priceChangePercent = try container.decodeIfPresent(Double.self, forKey: .priceChangePercent)
        priceSource = try container.decodeIfPresent(String.self, forKey: .priceSource)
        
        // 计算字段
        currentValue = try container.decodeIfPresent(Double.self, forKey: .currentValue)
        profitLoss = try container.decodeIfPresent(Double.self, forKey: .profitLoss)
        profitLossPercent = try container.decodeIfPresent(Double.self, forKey: .profitLossPercent)
        
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        account = try container.decodeIfPresent(AccountInfo.self, forKey: .account)

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

        if let dateString = try? container.decodeIfPresent(String.self, forKey: .lastPriceAt) {
            lastPriceAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            lastPriceAt = try container.decodeIfPresent(Date.self, forKey: .lastPriceAt)
        }
    }
}

// MARK: - 账户简要信息
struct AccountInfo: Codable, Hashable {
    let id: String
    let name: String
    let type: String
    let balance: Double?
}

// MARK: - 持仓交易记录
struct HoldingTransaction: Codable, Identifiable, Hashable {
    let id: String
    let holdingId: String
    let accountId: String
    let userId: String
    let type: HoldingTransactionType
    let quantity: Double
    let price: Double
    let amount: Double
    let fee: Double?
    let quantityAfter: Double
    let avgCostAfter: Double
    let date: Date
    let note: String?
    let rawText: String?
    let createdAt: Date

    // 关联的持仓信息
    let holding: HoldingInfo?

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    enum CodingKeys: String, CodingKey {
        case id, holdingId, accountId, userId, type, quantity, price, amount
        case fee, quantityAfter, avgCostAfter, date, note, rawText, createdAt, holding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        holdingId = try container.decode(String.self, forKey: .holdingId)
        accountId = try container.decode(String.self, forKey: .accountId)
        userId = try container.decode(String.self, forKey: .userId)
        type = try container.decode(HoldingTransactionType.self, forKey: .type)
        quantity = try container.decode(Double.self, forKey: .quantity)
        price = try container.decode(Double.self, forKey: .price)
        amount = try container.decode(Double.self, forKey: .amount)
        fee = try container.decodeIfPresent(Double.self, forKey: .fee)
        quantityAfter = try container.decode(Double.self, forKey: .quantityAfter)
        avgCostAfter = try container.decode(Double.self, forKey: .avgCostAfter)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
        holding = try container.decodeIfPresent(HoldingInfo.self, forKey: .holding)

        if let dateString = try? container.decode(String.self, forKey: .date) {
            date = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            date = try container.decode(Date.self, forKey: .date)
        }

        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }
}

// MARK: - 持仓简要信息
struct HoldingInfo: Codable, Hashable {
    let id: String
    let name: String
    let tickerCode: String?
    let type: HoldingType
}

// MARK: - 账户持仓汇总
struct AccountHoldingsSummary: Codable {
    let account: Asset
    let holdings: [Holding]
    let summary: HoldingsSummaryData
}

struct HoldingsSummaryData: Codable {
    let cashBalance: Double
    let holdingsMarketValue: Double
    let holdingsCost: Double
    let totalValue: Double
    let unrealizedPnL: Double
    let unrealizedPnLPercent: Double
}

// MARK: - 总持仓汇总
struct TotalHoldingsSummary: Codable {
    let totalMarketValue: Double
    let totalCost: Double
    let unrealizedPnL: Double
    let unrealizedPnLPercent: Double
    let holdingsCount: Int
}

// MARK: - 请求 DTO
struct BuyNewHoldingRequest: Codable {
    let accountId: String
    let name: String
    let displayName: String?
    let type: HoldingType
    let market: MarketType?
    let tickerCode: String?
    let quantity: Double
    let price: Double
    let fee: Double?
    let date: String?
    let note: String?
    let rawText: String?
    let currency: String?
}

struct HoldingTransactionRequest: Codable {
    let holdingId: String
    let type: HoldingTransactionType
    let quantity: Double
    let price: Double
    let fee: Double?
    let date: String?
    let note: String?
    let rawText: String?
}

struct UpdateHoldingRequest: Codable {
    let name: String?
    let displayName: String?
    let tickerCode: String?
    let codeVerified: Bool?
    let quantity: Double?
    let avgCostPrice: Double?
    let currentPrice: Double?
    let market: String?
}

// MARK: - 响应包装
struct BuyHoldingResponse: Codable {
    let holding: Holding
    let transaction: HoldingTransaction
}
