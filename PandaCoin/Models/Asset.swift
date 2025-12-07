//
//  Account.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

// MARK: - 资产类型
enum AssetType: String, Codable, CaseIterable {
    case bank = "BANK"                   // 银行卡
    case investment = "INVESTMENT"       // 投资账户
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
    
    /// 是否为负债类型
    var isLiability: Bool {
        switch self {
        case .creditCard, .loan, .mortgage, .otherLiability:
            return true
        default:
            return false
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

// MARK: - 创建/更新资产请求
struct AssetRequest: Codable {
    let name: String
    let type: AssetType
    let balance: Decimal
    let currency: String?
}

struct UpdateAccountRequest: Codable {
    let name: String?
    let balance: Decimal?
}
