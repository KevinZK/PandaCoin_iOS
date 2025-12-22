import Foundation

// MARK: - Budget Model
struct Budget: Codable, Identifiable {
    let id: String
    let month: String
    let category: String?
    let amount: Double
    let userId: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, month, category, amount
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
    let budgetAmount: Double
    let spentAmount: Double
    let remainingAmount: Double
    let usagePercent: Double
    let isOverBudget: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, month, category
        case budgetAmount
        case spentAmount
        case remainingAmount
        case usagePercent
        case isOverBudget
    }
    
    // 显示用的分类名
    var displayCategory: String {
        category ?? "总预算"
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
}

// MARK: - Update Budget Request
struct UpdateBudgetRequest: Codable {
    let amount: Double
}
