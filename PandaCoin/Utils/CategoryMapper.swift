//
//  CategoryMapper.swift
//  PandaCoin
//
//  分类标识符与显示名称的映射工具
//  将后端英文标识符映射为用户友好的中文显示
//

import Foundation

struct CategoryMapper {
    
    // MARK: - 支出分类映射 (后端标识符 -> 中文名称, 图标)
    private static let expenseMapping: [String: (name: String, icon: String)] = [
        "FOOD": ("餐饮", "🍜"),
        "TRANSPORT": ("交通", "🚗"),
        "SHOPPING": ("购物", "🛍️"),
        "ENTERTAINMENT": ("娱乐", "🎮"),
        "MEDICAL": ("医疗", "💊"),
        "HOUSING": ("住房", "🏠"),
        "EDUCATION": ("教育", "📚"),
        "COMMUNICATION": ("通讯", "📱"),
        "SPORTS": ("运动", "⚽️"),
        "BEAUTY": ("美容", "💄"),
        "TRAVEL": ("旅行", "✈️"),
        "PET": ("宠物", "🐱"),
        "SUBSCRIPTION": ("订阅", "📺"),
        "FEES_AND_TAXES": ("税费", "📋"),
        "LOAN_REPAYMENT": ("还款", "💳"),
        "OTHER": ("其他", "📦"),
    ]
    
    // MARK: - 收入分类映射
    private static let incomeMapping: [String: (name: String, icon: String)] = [
        "SALARY": ("工资", "💰"),
        "INCOME_SALARY": ("工资", "💰"),
        "BONUS": ("奖金", "🎁"),
        "INVESTMENT": ("理财", "📈"),
        "PARTTIME": ("兼职", "💼"),
        "RED_PACKET": ("红包", "🧧"),
        "ASSET_SALE": ("资产出售", "🏷️"),
        "INITIAL_BALANCE": ("期初余额", "🏦"),
        "OTHER": ("其他", "💵"),
    ]
    
    // MARK: - 中文分类也支持（向后兼容）
    private static let chineseCategories: [String: String] = [
        "餐饮": "🍜", "交通": "🚗", "购物": "🛍️", "娱乐": "🎮",
        "医疗": "💊", "住房": "🏠", "教育": "📚", "通讯": "📱",
        "运动": "⚽️", "美容": "💄", "旅行": "✈️", "宠物": "🐱",
        "工资": "💰", "奖金": "🎁", "理财": "📈", "兼职": "💼",
        "红包": "🧧", "期初余额": "🏦", "其他": "📦", "订阅": "📺",
        "税费": "📋", "还款": "💳", "资产出售": "🏷️"
    ]
    
    /// 获取分类的显示名称
    /// - Parameter category: 后端返回的分类标识符（如 "FOOD"）或中文名称
    /// - Returns: 用户友好的中文显示名称
    static func displayName(for category: String) -> String {
        let key = category.uppercased()
        
        // 先尝试匹配支出分类
        if let mapped = expenseMapping[key] {
            return mapped.name
        }
        // 再尝试匹配收入分类
        if let mapped = incomeMapping[key] {
            return mapped.name
        }
        // 如果已经是中文，直接返回
        if chineseCategories[category] != nil {
            return category
        }
        // 未匹配到，返回原值
        return category
    }
    
    /// 获取分类的图标
    /// - Parameter category: 后端返回的分类标识符或中文名称
    /// - Returns: 对应的 emoji 图标
    static func icon(for category: String) -> String {
        let key = category.uppercased()
        
        if let mapped = expenseMapping[key] {
            return mapped.icon
        }
        if let mapped = incomeMapping[key] {
            return mapped.icon
        }
        if let icon = chineseCategories[category] {
            return icon
        }
        return "💰"
    }
}
