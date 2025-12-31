import Foundation

// MARK: - Budget Model
struct Budget: Codable, Identifiable {
    let id: String
    let month: String
    let category: String?
    let name: String?
    let amount: Double
    let isRecurring: Bool
    let userId: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, month, category, name, amount, isRecurring
        case userId
        case createdAt
        case updatedAt
    }
}

// MARK: - Budget Progress
struct BudgetProgress: Codable, Identifiable {
    let id: String
    let month: String
    let category: String?
    let name: String?
    let budgetAmount: Double
    let spentAmount: Double
    let remainingAmount: Double
    let usagePercent: Double
    let isOverBudget: Bool
    let isRecurring: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, month, category, name
        case budgetAmount
        case spentAmount
        case remainingAmount
        case usagePercent
        case isOverBudget
        case isRecurring
    }
    
    // 分类代码到中文名的映射（与AI解析输出保持一致）
    private static let categoryMap: [String: String] = [
        // 消费分类
        "FOOD": "餐饮",
        "TRANSPORT": "交通",
        "SHOPPING": "购物",
        "HOUSING": "住房",
        "ENTERTAINMENT": "娱乐",
        "HEALTH": "医疗",
        "EDUCATION": "教育",
        "COMMUNICATION": "通讯",
        "SPORTS": "运动",
        "BEAUTY": "美容",
        "TRAVEL": "旅行",
        "PETS": "宠物",
        "SUBSCRIPTION": "订阅",
        "FEES_AND_TAXES": "税费",
        "LOAN_REPAYMENT": "还贷",
        "OTHER": "其他"
    ]

    // 分类代码到图标的映射（与AI解析输出保持一致）
    private static let categoryIconMap: [String: String] = [
        "FOOD": "🍜",
        "TRANSPORT": "🚗",
        "SHOPPING": "🛍️",
        "HOUSING": "🏠",
        "ENTERTAINMENT": "🎬",
        "HEALTH": "💊",
        "EDUCATION": "📚",
        "COMMUNICATION": "📱",
        "SPORTS": "⚽",
        "BEAUTY": "💄",
        "TRAVEL": "✈️",
        "PETS": "🐾",
        "SUBSCRIPTION": "📺",
        "FEES_AND_TAXES": "🏛️",
        "LOAN_REPAYMENT": "💳",
        "OTHER": "📦"
    ]

    // 显示用的分类名（将英文代码映射为中文）
    var displayCategory: String {
        if let name = name, !name.isEmpty {
            return name
        }
        guard let category = category else {
            return "总预算"
        }
        return Self.categoryMap[category] ?? category
    }

    // 分类图标
    var categoryIcon: String {
        guard let category = category else {
            return "📊"  // 总预算图标
        }
        return Self.categoryIconMap[category] ?? "📦"
    }

    // 是否为总预算
    var isTotalBudget: Bool {
        category == nil
    }
}

// MARK: - Monthly Budget Summary
struct MonthlyBudgetSummary: Codable {
    let month: String
    let totalBudget: Double
    let totalSpent: Double
    let totalRemaining: Double
    let overallUsagePercent: Double
    let categoryBudgets: [BudgetProgress]
    
    enum CodingKeys: String, CodingKey {
        case month
        case totalBudget
        case totalSpent
        case totalRemaining
        case overallUsagePercent
        case categoryBudgets
    }
}

// MARK: - Create Budget Request
struct CreateBudgetRequest: Codable {
    let month: String
    let category: String?
    let amount: Double
    let isRecurring: Bool
}

// MARK: - Update Budget Request
struct UpdateBudgetRequest: Codable {
    let amount: Double
    let isRecurring: Bool?
}
