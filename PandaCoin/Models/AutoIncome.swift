//
//  AutoIncome.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/28.
//

import Foundation

// MARK: - 入账类型
enum IncomeType: String, Codable, CaseIterable {
    case salary = "SALARY"
    case housingFund = "HOUSING_FUND"
    case pension = "PENSION"
    case rental = "RENTAL"
    case investmentReturn = "INVESTMENT_RETURN"
    case other = "OTHER"

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .salary: return NSLocalizedString("income_type_salary", comment: "Salary")
        case .housingFund: return NSLocalizedString("income_type_housing_fund", comment: "Housing Fund")
        case .pension: return NSLocalizedString("income_type_pension", comment: "Pension")
        case .rental: return NSLocalizedString("income_type_rental", comment: "Rental Income")
        case .investmentReturn: return NSLocalizedString("income_type_investment_return", comment: "Investment Return")
        case .other: return NSLocalizedString("income_type_other", comment: "Other Income")
        }
    }

    var icon: String {
        switch self {
        case .salary: return "briefcase.fill"
        case .housingFund: return "building.columns.fill"
        case .pension: return "heart.circle.fill"
        case .rental: return "house.fill"
        case .investmentReturn: return "chart.line.uptrend.xyaxis"
        case .other: return "plus.circle.fill"
        }
    }

    /// 默认分类（使用枚举值，与后端保持一致）
    var defaultCategory: String {
        switch self {
        case .salary: return "INCOME_SALARY"
        case .housingFund: return "INCOME_HOUSING_FUND"
        case .pension: return "INCOME_PENSION"
        case .rental: return "INCOME_RENTAL"
        case .investmentReturn: return "INCOME_INVESTMENT"
        case .other: return "INCOME_OTHER"
        }
    }
}

// MARK: - 目标账户信息
struct TargetAccountInfo: Codable, Equatable {
    let id: String
    let name: String
    let type: String
    let balance: Double
}

// MARK: - 自动入账配置模型
struct AutoIncome: Codable, Identifiable {
    let id: String
    let name: String
    let incomeType: IncomeType
    let amount: Double
    let targetAccountId: String
    let category: String
    let dayOfMonth: Int
    let executeTime: String
    let reminderDaysBefore: Int
    let isEnabled: Bool
    let lastExecutedAt: Date?
    let nextExecuteAt: Date?
    let createdAt: Date
    let updatedAt: Date

    // 关联的目标账户信息
    let targetAccount: TargetAccountInfo?

    // MARK: - 计算属性

    /// 格式化金额
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "¥" + (formatter.string(from: NSNumber(value: amount)) ?? "0.00")
    }

    /// 格式化下次执行日期
    var formattedNextExecuteDate: String? {
        guard let date = nextExecuteAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: date)
    }

    /// 入账日描述（本地化）
    var dayDescription: String {
        return String(format: NSLocalizedString("auto_income_day_format", comment: "Day %d of each month"), dayOfMonth)
    }

    /// 目标账户描述
    var targetAccountDescription: String {
        if let account = targetAccount {
            return account.name
        }
        return NSLocalizedString("common_not_set", comment: "Not set")
    }
}

// MARK: - 自动入账执行日志
struct AutoIncomeLog: Codable, Identifiable {
    let id: String
    let autoIncomeId: String
    let status: String
    let amount: Double
    let recordId: String?
    let message: String?
    let executedAt: Date

    var isSuccess: Bool {
        return status == "SUCCESS"
    }

    var statusIcon: String {
        switch status {
        case "SUCCESS": return "checkmark.circle.fill"
        case "SKIPPED": return "forward.circle.fill"
        default: return "xmark.circle.fill"
        }
    }

    var statusColor: String {
        switch status {
        case "SUCCESS": return "green"
        case "SKIPPED": return "orange"
        default: return "red"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: executedAt)
    }
}

// MARK: - 创建自动入账请求
struct CreateAutoIncomeRequest: Codable {
    let name: String
    let incomeType: String
    let amount: Double
    let targetAccountId: String
    let category: String?
    let dayOfMonth: Int
    let executeTime: String?
    let reminderDaysBefore: Int?
    let isEnabled: Bool?
}

// MARK: - 更新自动入账请求
struct UpdateAutoIncomeRequest: Codable {
    let name: String?
    let incomeType: String?
    let amount: Double?
    let targetAccountId: String?
    let category: String?
    let dayOfMonth: Int?
    let executeTime: String?
    let reminderDaysBefore: Int?
    let isEnabled: Bool?
}

// MARK: - 执行结果
struct AutoIncomeExecutionResult: Codable {
    let success: Bool
    let incomeId: String
    let amount: Double
    let recordId: String?
    let message: String
}
