//
//  BudgetCardContent.swift
//  PandaCoin
//
//  预算卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI

// MARK: - 预算分类枚举（用于语音创建预算）
enum VoiceBudgetCategory: String, CaseIterable {
    case none = ""
    case food = "FOOD"
    case transport = "TRANSPORT"
    case shopping = "SHOPPING"
    case entertainment = "ENTERTAINMENT"
    case health = "HEALTH"
    case housing = "HOUSING"
    case education = "EDUCATION"
    case communication = "COMMUNICATION"
    case sports = "SPORTS"
    case beauty = "BEAUTY"
    case travel = "TRAVEL"
    case pets = "PETS"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .none: return "总预算"
        case .food: return "餐饮"
        case .transport: return "交通"
        case .shopping: return "购物"
        case .entertainment: return "娱乐"
        case .health: return "医疗"
        case .housing: return "住房"
        case .education: return "教育"
        case .communication: return "通讯"
        case .sports: return "运动"
        case .beauty: return "美容"
        case .travel: return "旅行"
        case .pets: return "宠物"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .none: return "📊"
        case .food: return "🍜"
        case .transport: return "🚗"
        case .shopping: return "🛍️"
        case .entertainment: return "🎬"
        case .health: return "💊"
        case .housing: return "🏠"
        case .education: return "📚"
        case .communication: return "📱"
        case .sports: return "⚽"
        case .beauty: return "💄"
        case .travel: return "✈️"
        case .pets: return "🐾"
        case .other: return "📦"
        }
    }

    static func from(_ category: String?) -> VoiceBudgetCategory {
        guard let category = category else { return .none }
        return VoiceBudgetCategory(rawValue: category) ?? .none
    }
}

// MARK: - 预算卡片内容
struct BudgetCardContent: View {
    @Binding var data: BudgetParsed

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 预算类型标签
            HStack {
                Text("📊")
                    .font(.system(size: 16))
                Text("总预算")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.bambooGreen)
                    .cornerRadius(10)
                Spacer()
            }

            // 预算金额
            Text(formatAmount())
                .font(AppFont.monoNumber(size: 28, weight: .bold))
                .foregroundColor(.purple)

            // 预算信息
            HStack(spacing: Spacing.medium) {
                Label(mapAction(data.action), systemImage: actionIcon)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)

                if let date = data.targetDate {
                    Label(date, systemImage: "calendar")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // 每月循环开关
            Divider()
                .padding(.vertical, 4)

            HStack {
                Image(systemName: data.isRecurring ? "repeat.circle.fill" : "repeat.circle")
                    .foregroundColor(data.isRecurring ? Theme.bambooGreen : Theme.textSecondary)
                    .font(.system(size: 16))

                Text("每月自动应用")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.text)

                Spacer()

                Toggle("", isOn: $data.isRecurring)
                    .labelsHidden()
                    .tint(Theme.bambooGreen)
            }

            // 提示
            Text("分类预算可在「预算管理」中设置")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    private func formatAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "¥\(formatter.string(from: NSDecimalNumber(decimal: data.targetAmount)) ?? "0.00")"
    }
    
    private var actionIcon: String {
        switch data.action {
        case "CREATE_BUDGET": return "plus.circle"
        case "UPDATE_BUDGET": return "pencil"
        default: return "target"
        }
    }
    
    private func mapAction(_ action: String) -> String {
        switch action {
        case "CREATE_BUDGET": return "创建预算"
        case "UPDATE_BUDGET": return "更新预算"
        default: return "预算"
        }
    }
    
    private func priorityBadge(_ priority: String) -> some View {
        let color: Color = {
            switch priority {
            case "HIGH": return .red
            case "MEDIUM": return .orange
            case "LOW": return .green
            default: return .gray
            }
        }()
        
        let text: String = {
            switch priority {
            case "HIGH": return "高"
            case "MEDIUM": return "中"
            case "LOW": return "低"
            default: return priority
            }
        }()
        
        return Text(text)
            .font(AppFont.body(size: 12, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(8)
    }
}
