//
//  CategoryMapper.swift
//  PandaCoin
//
//  分类标识符与显示名称的映射工具
//  将后端英文标识符映射为用户友好的本地化显示
//

import Foundation

struct CategoryMapper {

    // MARK: - 分类枚举键 -> 本地化键映射
    private static let categoryLocalizationKeys: [String: String] = [
        // 支出分类
        "FOOD": "category_food",
        "TRANSPORT": "category_transport",
        "SHOPPING": "category_shopping",
        "ENTERTAINMENT": "category_entertainment",
        "HEALTH": "category_medical",
        "MEDICAL": "category_medical",
        "HOUSING": "category_housing",
        "EDUCATION": "category_education",
        "COMMUNICATION": "category_communication",
        "SPORTS": "category_sports",
        "BEAUTY": "category_beauty",
        "TRAVEL": "category_travel",
        "PETS": "category_pets",
        "PET": "category_pets",
        "SUBSCRIPTION": "category_subscription",
        "FEES_AND_TAXES": "category_fees_taxes",
        "LOAN_REPAYMENT": "category_loan_repayment",
        "OTHER": "category_other",

        // 收入分类
        "SALARY": "category_salary",
        "INCOME_SALARY": "category_salary",
        "BONUS": "category_bonus",
        "INCOME_BONUS": "category_bonus",
        "INVESTMENT": "category_investment",
        "INCOME_INVESTMENT": "category_investment",
        "PARTTIME": "category_parttime",
        "INCOME_FREELANCE": "category_parttime",
        "RED_PACKET": "category_red_packet",
        "INCOME_GIFT": "category_red_packet",
        "ASSET_SALE": "category_asset_sale",
        "INITIAL_BALANCE": "category_initial_balance",
        "INCOME_OTHER": "category_other_income",

        // 自动入账收入类型
        "INCOME_HOUSING_FUND": "income_type_housing_fund",
        "INCOME_PENSION": "income_type_pension",
        "INCOME_RENTAL": "income_type_rental",
    ]

    // MARK: - 分类图标映射
    private static let categoryIcons: [String: String] = [
        // 支出分类
        "FOOD": "🍜",
        "TRANSPORT": "🚗",
        "SHOPPING": "🛍️",
        "ENTERTAINMENT": "🎮",
        "HEALTH": "💊",
        "MEDICAL": "💊",
        "HOUSING": "🏠",
        "EDUCATION": "📚",
        "COMMUNICATION": "📱",
        "SPORTS": "⚽️",
        "BEAUTY": "💄",
        "TRAVEL": "✈️",
        "PETS": "🐱",
        "PET": "🐱",
        "SUBSCRIPTION": "📺",
        "FEES_AND_TAXES": "📋",
        "LOAN_REPAYMENT": "💳",
        "OTHER": "📦",

        // 收入分类
        "SALARY": "💰",
        "INCOME_SALARY": "💰",
        "BONUS": "🎁",
        "INCOME_BONUS": "🎁",
        "INVESTMENT": "📈",
        "INCOME_INVESTMENT": "📈",
        "PARTTIME": "💼",
        "INCOME_FREELANCE": "💼",
        "RED_PACKET": "🧧",
        "INCOME_GIFT": "🧧",
        "ASSET_SALE": "🏷️",
        "INITIAL_BALANCE": "🏦",
        "INCOME_OTHER": "💵",

        // 自动入账收入类型
        "INCOME_HOUSING_FUND": "🏠",
        "INCOME_PENSION": "👴",
        "INCOME_RENTAL": "🏘️",
    ]

    /// 获取分类的显示名称（本地化）
    /// - Parameter category: 后端返回的分类标识符（如 "FOOD"）
    /// - Returns: 用户友好的本地化显示名称
    static func displayName(for category: String) -> String {
        let key = category.uppercased()

        // 先尝试匹配已知的分类标识符
        if let localizationKey = categoryLocalizationKeys[key] {
            return NSLocalizedString(localizationKey, comment: "")
        }

        // 未匹配到，返回原值
        return category
    }

    /// 获取分类的图标
    /// - Parameter category: 后端返回的分类标识符
    /// - Returns: 对应的 emoji 图标
    static func icon(for category: String) -> String {
        let key = category.uppercased()

        if let icon = categoryIcons[key] {
            return icon
        }
        return "💰"
    }

    /// 判断分类是否为固定收入类型（用于自动入账检测）
    /// - Parameter category: 分类标识符
    /// - Returns: 是否为固定收入
    static func isFixedIncomeCategory(_ category: String) -> Bool {
        let key = category.uppercased()
        let fixedIncomeCategories: Set<String> = [
            "SALARY", "INCOME_SALARY",
            "INCOME_HOUSING_FUND",
            "INCOME_PENSION",
            "INCOME_RENTAL"
        ]
        return fixedIncomeCategories.contains(key)
    }

    /// 从分类推断 IncomeType
    /// - Parameter category: 分类标识符
    /// - Returns: 对应的 IncomeType
    static func inferIncomeType(from category: String) -> IncomeType {
        let key = category.uppercased()
        switch key {
        case "SALARY", "INCOME_SALARY":
            return .salary
        case "INCOME_HOUSING_FUND":
            return .housingFund
        case "INCOME_PENSION":
            return .pension
        case "INCOME_RENTAL":
            return .rental
        case "INVESTMENT", "INCOME_INVESTMENT":
            return .investmentReturn
        default:
            return .other
        }
    }
}
