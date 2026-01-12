//
//  Currency.swift
//  PandaCoin
//
//  Created by kevin on 2025/1/12.
//

import Foundation

// MARK: - 货币信息
struct CurrencyInfo: Codable, Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let nameCn: String
    let symbol: String
    let locale: String

    var displayName: String {
        "\(symbol) \(nameCn) (\(code))"
    }
}

// MARK: - 汇率信息
struct ExchangeRate: Codable, Identifiable {
    let id: String
    let fromCurrency: String
    let toCurrency: String
    let rate: Decimal
    let source: String?
    let fetchedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, fromCurrency, toCurrency, rate, source, fetchedAt, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fromCurrency = try container.decode(String.self, forKey: .fromCurrency)
        toCurrency = try container.decode(String.self, forKey: .toCurrency)
        rate = try container.decode(Decimal.self, forKey: .rate)
        source = try container.decodeIfPresent(String.self, forKey: .source)

        // 日期解析
        if let dateString = try? container.decode(String.self, forKey: .fetchedAt) {
            fetchedAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt)
        }

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

// MARK: - 货币金额响应（后端返回的格式化金额）
struct MoneyResponse: Codable, Hashable {
    let amount: Decimal            // 原始金额
    let currency: String           // 原始货币代码
    let formatted: String          // 格式化后的金额字符串
    let convertedAmount: Decimal?  // 转换后的金额
    let convertedCurrency: String? // 转换后的货币代码
    let convertedFormatted: String? // 转换后格式化的金额字符串
    let exchangeRate: Decimal?     // 使用的汇率
}

// MARK: - 用户货币设置
struct UserCurrencySettings: Codable {
    let baseCurrency: String
    let locale: String
    let currencyInfo: CurrencyInfo
}

// MARK: - 汇率详情
struct RateDetail: Codable {
    let from: String
    let to: String
    let rate: Decimal
    let lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case from, to, rate, lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        rate = try container.decode(Decimal.self, forKey: .rate)

        if let dateString = try? container.decode(String.self, forKey: .lastUpdated) {
            lastUpdated = ISO8601DateFormatter().date(from: dateString)
        } else {
            lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        }
    }
}

// MARK: - 货币转换结果
struct CurrencyConversionResult: Codable {
    let originalAmount: Decimal
    let originalCurrency: String
    let convertedAmount: Decimal
    let convertedCurrency: String
    let rate: Decimal
    let formatted: String
}

// MARK: - 更新用户货币设置请求
struct UpdateUserCurrencyRequest: Codable {
    let baseCurrency: String?
    let locale: String?

    init(baseCurrency: String? = nil, locale: String? = nil) {
        self.baseCurrency = baseCurrency
        self.locale = locale
    }
}

// MARK: - 支持的货币列表
extension CurrencyInfo {
    static let supportedCurrencies: [CurrencyInfo] = [
        CurrencyInfo(code: "CNY", name: "Chinese Yuan", nameCn: "人民币", symbol: "¥", locale: "zh-CN"),
        CurrencyInfo(code: "USD", name: "US Dollar", nameCn: "美元", symbol: "$", locale: "en-US"),
        CurrencyInfo(code: "EUR", name: "Euro", nameCn: "欧元", symbol: "€", locale: "de-DE"),
        CurrencyInfo(code: "GBP", name: "British Pound", nameCn: "英镑", symbol: "£", locale: "en-GB"),
        CurrencyInfo(code: "JPY", name: "Japanese Yen", nameCn: "日元", symbol: "¥", locale: "ja-JP"),
        CurrencyInfo(code: "HKD", name: "Hong Kong Dollar", nameCn: "港币", symbol: "HK$", locale: "zh-HK"),
        CurrencyInfo(code: "TWD", name: "Taiwan Dollar", nameCn: "新台币", symbol: "NT$", locale: "zh-TW"),
        CurrencyInfo(code: "SGD", name: "Singapore Dollar", nameCn: "新加坡元", symbol: "S$", locale: "en-SG"),
        CurrencyInfo(code: "AUD", name: "Australian Dollar", nameCn: "澳元", symbol: "A$", locale: "en-AU"),
        CurrencyInfo(code: "CAD", name: "Canadian Dollar", nameCn: "加元", symbol: "C$", locale: "en-CA"),
        CurrencyInfo(code: "CHF", name: "Swiss Franc", nameCn: "瑞士法郎", symbol: "CHF", locale: "de-CH"),
        CurrencyInfo(code: "KRW", name: "South Korean Won", nameCn: "韩元", symbol: "₩", locale: "ko-KR"),
    ]

    static func find(byCode code: String) -> CurrencyInfo? {
        supportedCurrencies.first { $0.code == code }
    }
}
