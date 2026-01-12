//
//  Statistics.swift
//  PandaCoin
//
//  统计报表相关数据模型
//

import Foundation

// MARK: - 格式化金额响应（统计用）
struct FormattedAmount: Codable {
    let amount: Double
    let formatted: String
}

// MARK: - 基础统计数据
struct RecordStatistics: Codable {
    let period: String
    let startDate: Date
    let endDate: Date
    let totalIncome: Decimal
    let totalExpense: Decimal
    let balance: Decimal
    let savingsRate: Double
    let categoryStats: [String: Decimal]
    let incomeCategoryStats: [String: Decimal]?
    let recordCount: Int

    // 货币格式化字段（后端返回）
    let baseCurrency: String?
    let totalIncomeFormatted: String?
    let totalExpenseFormatted: String?
    let balanceFormatted: String?
}

// MARK: - 趋势数据点
struct TrendDataPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let income: Double
    let expense: Double
    let balance: Double

    // 货币格式化字段（后端返回）
    let incomeFormatted: String?
    let expenseFormatted: String?
    let balanceFormatted: String?
}

// MARK: - 趋势统计
struct TrendStatistics: Codable {
    let period: String  // daily, weekly, monthly
    let startDate: String
    let endDate: String
    let data: [TrendDataPoint]
    let summary: TrendSummary

    // 货币格式化
    let baseCurrency: String?

    struct TrendSummary: Codable {
        let totalIncome: Double
        let totalExpense: Double
        let avgDailyExpense: Double
        let maxExpenseDay: String
        let maxExpenseAmount: Double

        // 货币格式化字段
        let totalIncomeFormatted: String?
        let totalExpenseFormatted: String?
        let avgDailyExpenseFormatted: String?
        let maxExpenseAmountFormatted: String?
    }
}

// MARK: - 环比对比项
struct ComparisonItem: Codable, Identifiable {
    var id: String { category }
    let category: String
    let currentAmount: Double
    let previousAmount: Double
    let change: Double
    let changePercent: Double

    // 货币格式化字段
    let currentAmountFormatted: String?
    let previousAmountFormatted: String?
    let changeFormatted: String?
}

// MARK: - 环比对比统计
struct ComparisonStatistics: Codable {
    let currentPeriod: String
    let previousPeriod: String
    let current: PeriodStats
    let previous: PeriodStats
    let changes: PeriodChanges
    let categoryComparison: [ComparisonItem]

    // 货币格式化
    let baseCurrency: String?

    struct PeriodStats: Codable {
        let totalIncome: Double
        let totalExpense: Double
        let balance: Double
        let savingsRate: Double

        // 货币格式化字段
        let totalIncomeFormatted: String?
        let totalExpenseFormatted: String?
        let balanceFormatted: String?
    }

    struct PeriodChanges: Codable {
        let incomeChange: Double
        let incomeChangePercent: Double
        let expenseChange: Double
        let expenseChangePercent: Double
        let balanceChange: Double
    }
}

// MARK: - 收入分析项
struct IncomeAnalysisItem: Codable, Identifiable {
    var id: String { category }
    let category: String
    let amount: Double
    let percent: Double
    let count: Int
    let isFixed: Bool
}

// MARK: - 收入分析
struct IncomeAnalysis: Codable {
    let period: String
    let totalIncome: Double
    let fixedIncome: Double
    let variableIncome: Double
    let fixedIncomeRatio: Double
    let categories: [IncomeAnalysisItem]
    let trend: [TrendDataPoint]
}

// MARK: - 健康度指标状态
enum HealthStatus: String, Codable {
    case excellent
    case good
    case fair
    case poor

    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - 健康度指标项
struct HealthMetricItem: Codable {
    let value: Double
    let score: Double
    let status: HealthStatus
    let suggestion: String
}

// MARK: - 健康度指标集合
struct HealthMetrics: Codable {
    let savingsRate: HealthMetricItem
    let essentialExpenseRatio: HealthMetricItem
    let debtRatio: HealthMetricItem
    let liquidityRatio: HealthMetricItem
    let budgetAdherence: HealthMetricItem
}

// MARK: - 财务健康等级
enum HealthGrade: String, Codable {
    case A, B, C, D, F

    var displayName: String {
        switch self {
        case .A: return "优秀"
        case .B: return "良好"
        case .C: return "中等"
        case .D: return "较差"
        case .F: return "需改善"
        }
    }

    var color: String {
        switch self {
        case .A: return "green"
        case .B: return "blue"
        case .C: return "orange"
        case .D: return "red"
        case .F: return "red"
        }
    }
}

// MARK: - 财务健康度
struct FinancialHealth: Codable {
    let overallScore: Int
    let grade: HealthGrade
    let metrics: HealthMetrics
    let suggestions: [String]
}

// MARK: - 分类趋势
struct CategoryTrend: Codable {
    let category: String
    let data: [CategoryTrendPoint]
    let average: Double
    let trend: TrendDirection

    struct CategoryTrendPoint: Codable, Identifiable {
        var id: String { month }
        let month: String
        let amount: Double
    }

    enum TrendDirection: String, Codable {
        case up
        case down
        case stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: String {
            switch self {
            case .up: return "red"
            case .down: return "green"
            case .stable: return "gray"
            }
        }
    }
}

// MARK: - 统计周期枚举
enum StatisticsPeriod: String, CaseIterable {
    case month = "month"
    case year = "year"

    var displayName: String {
        switch self {
        case .month: return "本月"
        case .year: return "本年"
        }
    }
}

// MARK: - 趋势周期枚举
enum TrendPeriod: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .daily: return "日"
        case .weekly: return "周"
        case .monthly: return "月"
        }
    }
}
