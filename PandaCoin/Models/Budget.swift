import Foundation

// MARK: - Budget Model
struct Budget: Codable, Identifiable {
    let id: String
    let month: String
    let category: String?
    let amount: Double
    let user_id: String
    let created_at: String
    let updated_at: String
    
    var userId: String { user_id }
    var createdAt: String { created_at }
    var updatedAt: String { updated_at }
}

// MARK: - Budget Progress
struct BudgetProgress: Codable, Identifiable {
    let id: String
    let month: String
    let category: String?
    let budget_amount: Double
    let spent_amount: Double
    let remaining_amount: Double
    let usage_percent: Double
    let is_over_budget: Bool
    
    var budgetAmount: Double { budget_amount }
    var spentAmount: Double { spent_amount }
    var remainingAmount: Double { remaining_amount }
    var usagePercent: Double { usage_percent }
    var isOverBudget: Bool { is_over_budget }
    
    // 显示用的分类名
    var displayCategory: String {
        category ?? "总预算"
    }
}

// MARK: - Monthly Budget Summary
struct MonthlyBudgetSummary: Codable {
    let month: String
    let total_budget: Double
    let total_spent: Double
    let total_remaining: Double
    let overall_usage_percent: Double
    let category_budgets: [BudgetProgress]
    
    var totalBudget: Double { total_budget }
    var totalSpent: Double { total_spent }
    var totalRemaining: Double { total_remaining }
    var overallUsagePercent: Double { overall_usage_percent }
    var categoryBudgets: [BudgetProgress] { category_budgets }
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
