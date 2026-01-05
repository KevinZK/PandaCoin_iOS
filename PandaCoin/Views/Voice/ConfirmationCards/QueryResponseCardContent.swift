//
//  QueryResponseCardContent.swift
//  PandaCoin
//
//  查询响应卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI

// MARK: - 查询响应卡片内容
struct QueryResponseCardContent: View {
    let data: QueryResponseParsed
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 技能标签
            HStack {
                Text("📊")
                    .font(.system(size: 16))
                Text(skillName)
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.teal)
                    .cornerRadius(10)
                Spacer()
            }
            
            // 摘要
            Text(data.summary)
                .font(AppFont.body(size: 16, weight: .medium))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            
            // 金额信息
            if let totalExpense = data.totalExpense {
                HStack {
                    Text("总支出")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(formatAmount(totalExpense))
                        .font(AppFont.monoNumber(size: 20, weight: .bold))
                        .foregroundColor(Theme.expense)
                }
            }
            
            if let dailyAverage = data.dailyAverage {
                HStack {
                    Text("日均消费")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(formatAmount(dailyAverage))
                        .font(AppFont.monoNumber(size: 16, weight: .medium))
                        .foregroundColor(Theme.text)
                }
            }
            
            // 洞察
            if let insights = data.insights, !insights.isEmpty {
                Divider().padding(.vertical, 4)
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Text("💡")
                            .font(.system(size: 12))
                        Text(insight)
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            // 建议
            if let suggestions = data.suggestions, !suggestions.isEmpty {
                Divider().padding(.vertical, 4)
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Text("📌")
                            .font(.system(size: 12))
                        Text(suggestion)
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    private var skillName: String {
        switch data.skillUsed {
        case "bill-analysis": return "消费分析"
        case "budget-advisor": return "预算顾问"
        case "investment": return "投资分析"
        case "loan-advisor": return "贷款顾问"
        default: return "智能分析"
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "¥\(formatter.string(from: NSNumber(value: amount)) ?? "0.00")"
    }
}
