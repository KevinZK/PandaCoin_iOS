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
                Label(CategoryMapper.displayName(for: data.category), systemImage: "tag.fill")
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
                HStack(spacing: 8) {
                    Text(assetIcon)
                        .font(.system(size: 20))
                    Text(data.assetName)
                        .font(AppFont.body(size: 18, weight: .semibold))
                        .foregroundColor(Theme.text)
                }
                
                Spacer()
                
                Text(formatValue())
                    .font(AppFont.monoNumber(size: 20, weight: .bold))
                    .foregroundColor(valueColor)
            }
            
            // 根据资产类型显示不同的次要信息
            HStack(spacing: Spacing.medium) {
                // 资产分类标签
                Text(assetCategoryLabel)
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(assetCategoryColor)
                    .cornerRadius(10)
                
                // 机构名称
                if let institution = data.institutionName, !institution.isEmpty {
                    Label(institution, systemImage: "building.2")
                        .font(AppFont.body(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 特殊信息行（根据资产类型）
            if hasExtraInfo {
                HStack(spacing: Spacing.medium) {
                    // 定期存款：显示利率和到期日
                    if let rate = data.interestRateAPY {
                        Label(String(format: "%.2f%% APY", rate), systemImage: "percent")
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.income)
                    }
                    
                    if let maturity = data.maturityDate {
                        Label("到期: \(maturity)", systemImage: "calendar")
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    // 股票/加密货币：显示数量
                    if let qty = data.quantity, qty > 0 {
                        Label(formatQuantity(qty), systemImage: "number")
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var hasExtraInfo: Bool {
        data.interestRateAPY != nil || data.maturityDate != nil || (data.quantity ?? 0) > 0
    }
    
    private var assetIcon: String {
        switch data.assetType.uppercased() {
        case "BANK_BALANCE":
            return data.interestRateAPY != nil ? "💰" : "🏦"
        case "STOCK":
            return "📈"
        case "CRYPTO":
            return "₿"
        case "FIXED_INCOME":
            return "📊"
        case "PHYSICAL_ASSET":
            return "🏠"
        case "LIABILITY":
            return "💳"
        default:
            return "💵"
        }
    }
    
    private var assetCategoryLabel: String {
        switch data.assetType.uppercased() {
        case "BANK_BALANCE":
            if data.interestRateAPY != nil {
                return "定期存款"
            }
            return "活期存款"
        case "STOCK":
            return "股票"
        case "CRYPTO":
            return "加密货币"
        case "FIXED_INCOME":
            return "固定收益"
        case "PHYSICAL_ASSET":
            return "实物资产"
        case "LIABILITY":
            return "负债"
        default:
            return "资产"
        }
    }
    
    private var assetCategoryColor: Color {
        switch data.assetType.uppercased() {
        case "BANK_BALANCE":
            return data.interestRateAPY != nil ? .orange : .blue
        case "STOCK":
            return .green
        case "CRYPTO":
            return .purple
        case "FIXED_INCOME":
            return .teal
        case "PHYSICAL_ASSET":
            return .brown
        case "LIABILITY":
            return .red
        default:
            return .gray
        }
    }
    
    private var valueColor: Color {
        switch data.assetType.uppercased() {
        case "LIABILITY":
            return Theme.expense
        default:
            return .blue
        }
    }
    
    private func formatValue() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let symbol = currencySymbol(data.currency)
        let prefix = data.assetType.uppercased() == "LIABILITY" ? "-" : ""
        return "\(prefix)\(symbol)\(formatter.string(from: NSDecimalNumber(decimal: data.totalValue)) ?? "0.00")"
    }
    
    private func currencySymbol(_ currency: String) -> String {
        switch currency.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "HKD": return "HK$"
        default: return "¥"
        }
    }
    
    private func formatQuantity(_ qty: Double) -> String {
        if qty == floor(qty) {
            return "\(Int(qty)) 份"
        }
        return String(format: "%.4f 份", qty)
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

#Preview("统一确认页面 - 全部类型") {
    UnifiedConfirmationView(
        events: [
            // TRANSACTION - 支出
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
            // TRANSACTION - 收入
            ParsedFinancialEvent(
                eventType: .transaction,
                transactionData: AIRecordParsed(
                    type: .income,
                    amount: 8000,
                    category: "INCOME_SALARY",
                    accountName: "工商银行",
                    description: "工资",
                    date: Date(),
                    confidence: 0.98
                ),
                assetUpdateData: nil,
                budgetData: nil
            ),
            // ASSET_UPDATE - 活期存款
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK_BALANCE",
                    assetName: "工商银行储蓄卡",
                    totalValue: 50000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "工商银行",
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false
                ),
                budgetData: nil
            ),
            // ASSET_UPDATE - 定期存款
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK_BALANCE",
                    assetName: "招商银行定期",
                    totalValue: 100000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    quantity: nil,
                    interestRateAPY: 2.85,
                    maturityDate: "2025-06-30",
                    isInitialRecord: false
                ),
                budgetData: nil
            ),
            // ASSET_UPDATE - 股票
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "STOCK",
                    assetName: "腾讯控股",
                    totalValue: 38500,
                    currency: "HKD",
                    date: Date(),
                    institutionName: "富途证券",
                    quantity: 100,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false
                ),
                budgetData: nil
            ),
            // BUDGET - 储蓄目标
            ParsedFinancialEvent(
                eventType: .budget,
                transactionData: nil,
                assetUpdateData: nil,
                budgetData: BudgetParsed(
                    action: "CREATE_SAVINGS",
                    name: "旅游基金",
                    targetAmount: 20000,
                    targetDate: "2025-06",
                    priority: "HIGH"
                )
            )
        ],
        onConfirm: { _ in }
    )
}

#Preview("资产更新卡片 - 活期存款") {
    VStack {
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK_BALANCE",
                    assetName: "工商银行储蓄卡",
                    totalValue: 50000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "工商银行",
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false
                ),
                budgetData: nil
            )
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 定期存款") {
    VStack {
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK_BALANCE",
                    assetName: "招商银行定期",
                    totalValue: 100000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    quantity: nil,
                    interestRateAPY: 2.85,
                    maturityDate: "2025-06-30",
                    isInitialRecord: false
                ),
                budgetData: nil
            )
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 股票") {
    VStack {
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "STOCK",
                    assetName: "腾讯控股",
                    totalValue: 38500,
                    currency: "HKD",
                    date: Date(),
                    institutionName: "富途证券",
                    quantity: 100,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false
                ),
                budgetData: nil
            )
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 加密货币") {
    VStack {
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "CRYPTO",
                    assetName: "Bitcoin",
                    totalValue: 45000,
                    currency: "USD",
                    date: Date(),
                    institutionName: "Binance",
                    quantity: 0.5,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false
                ),
                budgetData: nil
            )
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 负债") {
    VStack {
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "LIABILITY",
                    assetName: "招商信用卡",
                    totalValue: 5000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false
                ),
                budgetData: nil
            )
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("交易记录卡片") {
    VStack(spacing: 16) {
        // 支出
        EventConfirmCard(
            event: ParsedFinancialEvent(
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
            )
        )
        
        // 收入
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .transaction,
                transactionData: AIRecordParsed(
                    type: .income,
                    amount: 8000,
                    category: "INCOME_SALARY",
                    accountName: "工商银行",
                    description: "工资",
                    date: Date(),
                    confidence: 0.98
                ),
                assetUpdateData: nil,
                budgetData: nil
            )
        )
    }
    .padding()
    .background(Theme.background)
}

#Preview("预算卡片") {
    VStack(spacing: 16) {
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .budget,
                transactionData: nil,
                assetUpdateData: nil,
                budgetData: BudgetParsed(
                    action: "CREATE_SAVINGS",
                    name: "旅游基金",
                    targetAmount: 20000,
                    targetDate: "2025-06",
                    priority: "HIGH"
                )
            )
        )
        
        EventConfirmCard(
            event: ParsedFinancialEvent(
                eventType: .budget,
                transactionData: nil,
                assetUpdateData: nil,
                budgetData: BudgetParsed(
                    action: "CREATE_DEBT_REPAYMENT",
                    name: "信用卡还款",
                    targetAmount: 5000,
                    targetDate: "2025-01",
                    priority: "MEDIUM"
                )
            )
        )
    }
    .padding()
    .background(Theme.background)
}
