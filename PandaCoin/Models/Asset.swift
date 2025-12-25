//
//  Account.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

// MARK: - 资产类型
enum AssetType: String, Codable, CaseIterable {
    case bank = "BANK"                   // 银行卡储蓄
    case investment = "INVESTMENT"       // 投资
    case cash = "CASH"                   // 现金
    case creditCard = "CREDIT_CARD"      // 信用卡
    case digitalWallet = "DIGITAL_WALLET" // 电子钱包（支付宝、微信支付等）
    case loan = "LOAN"                   // 贷款（负债）
    case mortgage = "MORTGAGE"           // 房贷
    case savings = "SAVINGS"             // 储蓄账户
    case retirement = "RETIREMENT"       // 养老金
    case crypto = "CRYPTO"               // 加密货币
    case property = "PROPERTY"           // 房产
    case vehicle = "VEHICLE"             // 车辆
    case otherAsset = "OTHER_ASSET"      // 其他资产
    case otherLiability = "OTHER_LIABILITY" // 其他负债
    
    /// 是否为负债类型
    var isLiability: Bool {
        switch self {
        case .creditCard, .loan, .mortgage, .otherLiability:
            return true
        default:
            return false
        }
    }
    
    /// 负债子分类
    enum LiabilityCategory {
        case debt      // 债务类（信用卡消费、其他负债）
        case loan      // 贷款类（贷款、房贷）
    }
    
    /// 获取负债分类（仅负债类型有值）
    var liabilityCategory: LiabilityCategory? {
        switch self {
        case .creditCard, .otherLiability:
            return .debt
        case .loan, .mortgage:
            return .loan
        default:
            return nil
        }
    }
    
    var displayName: String {
        switch self {
        case .bank: return L10n.Account.typeBank
        case .investment: return L10n.Account.typeInvestment
        case .cash: return L10n.Account.typeCash
        case .creditCard: return L10n.Account.typeCreditCard
        case .digitalWallet: return L10n.Account.typeDigitalWallet
        case .loan: return L10n.Account.typeLoan
        case .mortgage: return L10n.Account.typeMortgage
        case .savings: return L10n.Account.typeSavings
        case .retirement: return L10n.Account.typeRetirement
        case .crypto: return L10n.Account.typeCrypto
        case .property: return L10n.Account.typeProperty
        case .vehicle: return L10n.Account.typeVehicle
        case .otherAsset: return L10n.Account.typeOtherAsset
        case .otherLiability: return L10n.Account.typeOtherLiability
        }
    }
    
    var icon: String {
        switch self {
        case .bank: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.circle.fill"
        case .digitalWallet: return "iphone.gen3"
        case .loan: return "arrow.down.circle.fill"
        case .mortgage: return "house.fill"
        case .savings: return "building.columns.fill"
        case .retirement: return "figure.walk"
        case .crypto: return "bitcoinsign.circle.fill"
        case .property: return "building.2.fill"
        case .vehicle: return "car.fill"
        case .otherAsset: return "dollarsign.circle.fill"
        case .otherLiability: return "minus.circle.fill"
        }
    }
}

// MARK: - 资产模型
struct Asset: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: AssetType
    var balance: Decimal
    let currency: String
    let userId: String
    let createdAt: Date
    let updatedAt: Date
    
    // 贷款专用字段
    let loanTermMonths: Int?       // 贷款期限(月)
    let interestRate: Double?      // 年利率 (%)
    let monthlyPayment: Double?    // 月供金额
    let repaymentDay: Int?         // 还款日 (每月几号)
    let loanStartDate: Date?       // 贷款开始日期
    let institutionName: String?   // 贷款机构
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case balance
        case currency
        case userId
        case createdAt
        case updatedAt
        case loanTermMonths
        case interestRate
        case monthlyPayment
        case repaymentDay
        case loanStartDate
        case institutionName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(AssetType.self, forKey: .type)
        balance = try container.decode(Decimal.self, forKey: .balance)
        currency = try container.decode(String.self, forKey: .currency)
        userId = try container.decode(String.self, forKey: .userId)
        
        // 贷款字段（可选）
        loanTermMonths = try container.decodeIfPresent(Int.self, forKey: .loanTermMonths)
        interestRate = try container.decodeIfPresent(Double.self, forKey: .interestRate)
        monthlyPayment = try container.decodeIfPresent(Double.self, forKey: .monthlyPayment)
        repaymentDay = try container.decodeIfPresent(Int.self, forKey: .repaymentDay)
        institutionName = try container.decodeIfPresent(String.self, forKey: .institutionName)
        
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
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .loanStartDate) {
            loanStartDate = ISO8601DateFormatter().date(from: dateString)
        } else {
            loanStartDate = try container.decodeIfPresent(Date.self, forKey: .loanStartDate)
        }
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
    
    // 格式化月供显示
    var formattedMonthlyPayment: String? {
        guard let payment = monthlyPayment else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: payment))
    }
    
    // 贷款期限显示（年）
    var loanTermYears: Int? {
        guard let months = loanTermMonths else { return nil }
        return months / 12
    }
}

// MARK: - 创建/更新资产请求
struct AssetRequest: Codable {
    let name: String
    let type: AssetType
    let balance: Decimal
    let currency: String?
    
    // 贷款专用字段
    let loanTermMonths: Int?
    let interestRate: Double?
    let monthlyPayment: Double?
    let repaymentDay: Int?
    let loanStartDate: String?
    let institutionName: String?
    
    // 自动还款配置
    let autoRepayment: Bool?
    let sourceAccountId: String?
    let sourceAccountName: String?
    
    init(
        name: String,
        type: AssetType,
        balance: Decimal,
        currency: String? = "CNY",
        loanTermMonths: Int? = nil,
        interestRate: Double? = nil,
        monthlyPayment: Double? = nil,
        repaymentDay: Int? = nil,
        loanStartDate: String? = nil,
        institutionName: String? = nil,
        autoRepayment: Bool? = nil,
        sourceAccountId: String? = nil,
        sourceAccountName: String? = nil
    ) {
        self.name = name
        self.type = type
        self.balance = balance
        self.currency = currency
        self.loanTermMonths = loanTermMonths
        self.interestRate = interestRate
        self.monthlyPayment = monthlyPayment
        self.repaymentDay = repaymentDay
        self.loanStartDate = loanStartDate
        self.institutionName = institutionName
        self.autoRepayment = autoRepayment
        self.sourceAccountId = sourceAccountId
        self.sourceAccountName = sourceAccountName
    }
}

struct UpdateAccountRequest: Codable {
    let name: String?
    let balance: Decimal?
    let loanTermMonths: Int?
    let interestRate: Double?
    let monthlyPayment: Double?
    let repaymentDay: Int?
    let institutionName: String?
    
    init(
        name: String? = nil,
        balance: Decimal? = nil,
        loanTermMonths: Int? = nil,
        interestRate: Double? = nil,
        monthlyPayment: Double? = nil,
        repaymentDay: Int? = nil,
        institutionName: String? = nil
    ) {
        self.name = name
        self.balance = balance
        self.loanTermMonths = loanTermMonths
        self.interestRate = interestRate
        self.monthlyPayment = monthlyPayment
        self.repaymentDay = repaymentDay
        self.institutionName = institutionName
    }
}
