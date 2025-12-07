//
//  UnifiedConfirmationView.swift
//  PandaCoin
//
//  统一确认视图 - 支持多种事件类型
//

import SwiftUI

struct UnifiedConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    
    let events: [ParsedFinancialEvent]
    let onConfirm: ([ParsedFinancialEvent]) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        // 熊猫提示
                        VStack(spacing: Spacing.small) {
                            Text("🐼")
                                .font(.system(size: 50))
                            
                            Text("熊猫识别了\(events.count)条记录")
                                .font(AppFont.body(size: 16, weight: .medium))
                                .foregroundColor(Theme.text)
                            
                            Text("请确认是否正确")
                                .font(AppFont.body(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, Spacing.large)
                        
                        // 事件列表
                        VStack(spacing: Spacing.medium) {
                            ForEach(events) { event in
                                EventConfirmCard(event: event)
                            }
                        }
                        .padding(.horizontal, Spacing.medium)
                        
                        // 按钮
                        HStack(spacing: Spacing.medium) {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("取消")
                                    .font(AppFont.body(size: 16, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(CornerRadius.medium)
                            }
                            
                            Button(action: {
                                onConfirm(events)
                                dismiss()
                            }) {
                                Text("确认保存")
                                    .font(AppFont.body(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Theme.bambooGreen)
                                    .cornerRadius(CornerRadius.medium)
                            }
                        }
                        .padding(.horizontal, Spacing.medium)
                        .padding(.bottom, Spacing.large)
                    }
                }
            }
            .navigationTitle("确认记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 事件确认卡片
struct EventConfirmCard: View {
    let event: ParsedFinancialEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // 事件类型标签
            HStack {
                eventTypeLabel
                Spacer()
            }
            
            // 根据事件类型显示不同内容
            switch event.eventType {
            case .transaction:
                if let data = event.transactionData {
                    TransactionCardContent(data: data)
                }
            case .assetUpdate:
                if let data = event.assetUpdateData {
                    AssetUpdateCardContent(data: data)
                }
            case .budget:
                if let data = event.budgetData {
                    BudgetCardContent(data: data)
                }
            case .nullStatement:
                EmptyView()
            }
        }
        .padding(Spacing.medium)
        .background(Color.white)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(borderColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var eventTypeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: eventIcon)
                .font(.system(size: 12))
            Text(eventTypeName)
                .font(AppFont.body(size: 12, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, 4)
        .background(borderColor)
        .cornerRadius(12)
    }
    
    private var eventTypeName: String {
        switch event.eventType {
        case .transaction: return "交易记录"
        case .assetUpdate: return "资产更新"
        case .budget: return "预算"
        case .nullStatement: return "无效"
        }
    }
    
    private var eventIcon: String {
        switch event.eventType {
        case .transaction: return "arrow.left.arrow.right"
        case .assetUpdate: return "building.columns"
        case .budget: return "target"
        case .nullStatement: return "xmark"
        }
    }
    
    private var borderColor: Color {
        switch event.eventType {
        case .transaction:
            if let data = event.transactionData {
                return data.type == .expense ? Theme.expense : Theme.income
            }
            return Theme.textSecondary
        case .assetUpdate: return .blue
        case .budget: return .purple
        case .nullStatement: return Theme.textSecondary
        }
    }
}

// MARK: - 交易卡片内容
struct TransactionCardContent: View {
    let data: AIRecordParsed
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 金额
            Text(formatAmount())
                .font(AppFont.monoNumber(size: 24, weight: .bold))
                .foregroundColor(data.type == .expense ? Theme.expense : Theme.income)
            
            // 分类和账户
            HStack(spacing: Spacing.large) {
                Label(data.category, systemImage: "tag.fill")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.text)
                
                if !data.accountName.isEmpty {
                    Label(data.accountName, systemImage: "creditcard")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 描述
            if !data.description.isEmpty {
                Text(data.description)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    private func formatAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let amountStr = formatter.string(from: NSDecimalNumber(decimal: data.amount)) ?? "0.00"
        let prefix = data.type == .expense ? "-" : "+"
        return "\(prefix)¥\(amountStr)"
    }
}

// MARK: - 资产更新卡片内容
struct AssetUpdateCardContent: View {
    let data: AssetUpdateParsed
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 资产名称和金额
            HStack {
                Text(data.assetName)
                    .font(AppFont.body(size: 18, weight: .semibold))
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text(formatValue())
                    .font(AppFont.monoNumber(size: 20, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            // 资产类型
            HStack(spacing: Spacing.medium) {
                Label(mapAssetType(data.assetType), systemImage: assetIcon)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                
                if let institution = data.institutionName {
                    Label(institution, systemImage: "building.2")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func formatValue() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let symbol = data.currency == "USD" ? "$" : "¥"
        return "\(symbol)\(formatter.string(from: NSDecimalNumber(decimal: data.totalValue)) ?? "0.00")"
    }
    
    private var assetIcon: String {
        // AI 返回的是 category 类型，如 FOOD, SHOPPING, OTHER 等
        switch data.assetType.uppercased() {
        case "BANK_BALANCE", "BANK", "SAVINGS": return "building.columns"
        case "STOCK", "INVESTMENT": return "chart.line.uptrend.xyaxis"
        case "CRYPTO": return "bitcoinsign.circle"
        case "PHYSICAL_ASSET", "PROPERTY": return "house"
        case "LIABILITY", "CREDIT_CARD", "LOAN": return "creditcard"
        case "CASH": return "banknote"
        default: return "dollarsign.circle"
        }
    }
    
    private func mapAssetType(_ type: String) -> String {
        // AI 返回的是 category 类型
        switch type.uppercased() {
        case "BANK_BALANCE", "BANK", "SAVINGS": return "银行存款"
        case "STOCK", "INVESTMENT": return "股票"
        case "CRYPTO": return "加密货币"
        case "PHYSICAL_ASSET", "PROPERTY": return "实物资产"
        case "LIABILITY", "CREDIT_CARD", "LOAN": return "负债"
        case "FIXED_INCOME": return "固定收益"
        case "CASH": return "现金"
        default: return "资产"  // 改为通用名称
        }
    }
}

// MARK: - 预算卡片内容
struct BudgetCardContent: View {
    let data: BudgetParsed
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 预算名称和金额
            HStack {
                Text(data.name.isEmpty ? "新预算" : data.name)
                    .font(AppFont.body(size: 18, weight: .semibold))
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text(formatAmount())
                    .font(AppFont.monoNumber(size: 20, weight: .bold))
                    .foregroundColor(.purple)
            }
            
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
                
                if let priority = data.priority {
                    priorityBadge(priority)
                }
            }
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
        case "CREATE_SAVINGS": return "banknote"
        case "CREATE_DEBT_REPAYMENT": return "creditcard"
        case "UPDATE_TARGET": return "pencil"
        default: return "target"
        }
    }
    
    private func mapAction(_ action: String) -> String {
        switch action {
        case "CREATE_SAVINGS": return "储蓄目标"
        case "CREATE_DEBT_REPAYMENT": return "还债计划"
        case "UPDATE_TARGET": return "更新目标"
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

#Preview {
    UnifiedConfirmationView(
        events: [
            ParsedFinancialEvent(
                eventType: .transaction,
                transactionData: AIRecordParsed(
                    type: .expense,
                    amount: 35,
                    category: "FOOD",
                    accountName: "招商银行",
                    description: "午餐",
                    date: Date(),
                    confidence: 0.95
                ),
                assetUpdateData: nil,
                budgetData: nil
            ),
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK_BALANCE",
                    assetName: "工商银行",
                    totalValue: 50000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "工商银行"
                ),
                budgetData: nil
            )
        ],
        onConfirm: { _ in }
    )
}
