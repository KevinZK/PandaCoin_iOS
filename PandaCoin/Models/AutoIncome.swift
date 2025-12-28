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

    var displayName: String {
        switch self {
        case .salary: return "工资"
        case .housingFund: return "公积金"
        case .pension: return "养老金"
        case .rental: return "租金收入"
        case .investmentReturn: return "投资收益"
        case .other: return "其他收入"
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

    var defaultCategory: String {
        switch self {
        case .salary: return "工资"
        case .housingFund: return "公积金"
        case .pension: return "养老金"
        case .rental: return "租金"
        case .investmentReturn: return "投资收益"
        case .other: return "其他收入"
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

    /// 入账日描述
    var dayDescription: String {
        return "每月\(dayOfMonth)号"
    }

    /// 目标账户描述
    var targetAccountDescription: String {
        if let account = targetAccount {
            return account.name
        }
        return "未设置"
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
