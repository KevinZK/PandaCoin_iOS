//
//  UnifiedConfirmationView.swift
//  PandaCoin
//
//  统一确认视图 - 支持多种事件类型
//

import SwiftUI

struct UnifiedConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var editableEvents: [ParsedFinancialEvent]
    let onConfirm: ([ParsedFinancialEvent]) -> Void
    
    init(events: [ParsedFinancialEvent], onConfirm: @escaping ([ParsedFinancialEvent]) -> Void) {
        self._editableEvents = State(initialValue: events)
        self.onConfirm = onConfirm
    }
    
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
                            
                            Text("熊猫识别了\(editableEvents.count)条记录")
                                .font(AppFont.body(size: 16, weight: .medium))
                                 .foregroundColor(Theme.text)
                            
                            Text("请确认是否正确")
                                .font(AppFont.body(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, Spacing.large)
                        
                        // 事件列表
                        VStack(spacing: Spacing.medium) {
                            ForEach(editableEvents.indices, id: \.self) { index in
                                EventConfirmCard(event: $editableEvents[index])
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
                                onConfirm(editableEvents)
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
    @Binding var event: ParsedFinancialEvent
    
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
                if event.transactionData != nil {
                    TransactionCardContent(data: Binding(
                        get: { event.transactionData! },
                        set: { event.transactionData = $0 }
                    ))
                }
            case .assetUpdate:
                if event.assetUpdateData != nil {
                    AssetUpdateCardContent(data: Binding(
                        get: { event.assetUpdateData! },
                        set: { event.assetUpdateData = $0 }
                    ))
                }
            case .creditCardUpdate:
                if event.creditCardData != nil {
                    CreditCardUpdateCardContent(data: Binding(
                        get: { event.creditCardData! },
                        set: { event.creditCardData = $0 }
                    ))
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
        case .creditCardUpdate: return "信用卡"
        case .budget: return "预算"
        case .nullStatement: return "无效"
        }
    }
    
    private var eventIcon: String {
        switch event.eventType {
        case .transaction: return "arrow.left.arrow.right"
        case .assetUpdate: return "building.columns"
        case .creditCardUpdate: return "creditcard"
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
        case .creditCardUpdate: return .orange
        case .budget: return .purple
        case .nullStatement: return Theme.textSecondary
        }
    }
}

// MARK: - 交易卡片内容
struct TransactionCardContent: View {
    @Binding var data: AIRecordParsed
    @State private var cardIdentifier: String = ""
    
    // 是否涉及信用卡（根据账户名称判断）
    private var involvesCreditCard: Bool {
        data.accountName.contains("信用卡") || data.cardIdentifier != nil
    }
    
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
            
            // 信用卡标识选择器（仅当交易涉及信用卡时显示）
            if involvesCreditCard {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("关联信用卡")
                        .font(AppFont.body(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    
                    CardIdentifierPicker(
                        cardIdentifier: $cardIdentifier,
                        placeholder: "请输入卡片标识（如尾号）"
                    )
                }
            }
        }
        .onAppear {
            cardIdentifier = data.cardIdentifier ?? ""
        }
        .onChange(of: cardIdentifier) { newValue in
            data.cardIdentifier = newValue.isEmpty ? nil : newValue
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
    @Binding var data: AssetUpdateParsed
    @State private var cardIdentifier: String = ""
    
    // 是否是信用卡类型
    private var isCreditCard: Bool {
        data.assetType.uppercased() == "CREDIT_CARD"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 资产名称和金额
            HStack {
                HStack(spacing: 8) {
                    Text(assetIcon)
                        .font(.system(size: 20))
                    if data.assetName.isEmpty {
                        if let institution = data.institutionName, !institution.isEmpty {
                            Text(institution + "储蓄卡") // en: deposit card
                                .font(AppFont.body(size: 18, weight: .semibold))
                                .foregroundColor(Theme.text)
                        }
                        
                    } else {
                        Text(data.assetName)
                            .font(AppFont.body(size: 18, weight: .semibold))
                            .foregroundColor(Theme.text)
                    }
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
            
            // 还款计划（负债类）
            if let repayment = data.repaymentAmount, repayment > 0 {
                HStack(spacing: Spacing.small) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(Theme.expense)
                    Text("还款: \(formatRepayment(repayment))/\(formatSchedule(data.repaymentSchedule))")
                        .font(AppFont.body(size: 13, weight: .medium))
                        .foregroundColor(Theme.expense)
                }
            }
            
            // 信用卡标识选择器（仅当 asset_type = CREDIT_CARD 时显示）
            if isCreditCard {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("关联信用卡")
                        .font(AppFont.body(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    
                    CardIdentifierPicker(
                        cardIdentifier: $cardIdentifier,
                        placeholder: "请输入卡片标识（如尾号）"
                    )
                }
            }
        }
        .onAppear {
            cardIdentifier = data.cardIdentifier ?? ""
        }
        .onChange(of: cardIdentifier) { newValue in
            data.cardIdentifier = newValue.isEmpty ? nil : newValue
        }
    }
    
    // MARK: - 计算属性
    
    private var hasExtraInfo: Bool {
        data.interestRateAPY != nil || data.maturityDate != nil || (data.quantity ?? 0) > 0
    }
    
    private func formatRepayment(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let symbol = currencySymbol(data.currency)
        return "\(symbol)\(formatter.string(from: NSNumber(value: amount)) ?? "0")"
    }
    
    private func formatSchedule(_ schedule: String?) -> String {
        switch schedule?.uppercased() {
        case "WEEKLY": return "周"
        case "MONTHLY": return "月"
        case "YEARLY": return "年"
        default: return "月"
        }
    }
    
    private var assetIcon: String {
        switch data.assetType.uppercased() {
        case "BANK":
            return "🏦"
        case "SAVINGS":
            return data.interestRateAPY != nil ? "💰" : "🏦"
        case "INVESTMENT":
            return "📈"
        case "CRYPTO":
            return "₿"
        case "CASH":
            return "💵"
        case "CREDIT_CARD":
            return "💳"
        case "DIGITAL_WALLET":
            return "📱"
        case "LOAN":
            return "📝"
        case "MORTGAGE":
            return "🏠"
        case "RETIREMENT":
            return "👴"
        case "PROPERTY":
            return "🏠"
        case "VEHICLE":
            return "🚗"
        case "OTHER_ASSET":
            return "📦"
        case "OTHER_LIABILITY":
            return "📋"
        default:
            return "💵"
        }
    }
    
    private var assetCategoryLabel: String {
        switch data.assetType.uppercased() {
        case "BANK":
            return "银行账户"
        case "SAVINGS":
            return data.interestRateAPY != nil ? "定期存款" : "储蓄账户"
        case "INVESTMENT":
            return "投资账户"
        case "CRYPTO":
            return "加密货币"
        case "CASH":
            return "现金"
        case "CREDIT_CARD":
            return "信用卡"
        case "DIGITAL_WALLET":
            return "电子钱包"
        case "LOAN":
            return "贷款"
        case "MORTGAGE":
            return "房贷"
        case "RETIREMENT":
            return "退休金"
        case "PROPERTY":
            return "房产"
        case "VEHICLE":
            return "车辆"
        case "OTHER_ASSET":
            return "其他资产"
        case "OTHER_LIABILITY":
            return "其他负债"
        default:
            return "资产"
        }
    }
    
    private var assetCategoryColor: Color {
        switch data.assetType.uppercased() {
        case "BANK", "SAVINGS":
            return data.interestRateAPY != nil ? .orange : .blue
        case "INVESTMENT":
            return .green
        case "CRYPTO":
            return .purple
        case "CASH":
            return .mint
        case "CREDIT_CARD", "LOAN", "MORTGAGE", "OTHER_LIABILITY":
            return .red
        case "DIGITAL_WALLET":
            return .cyan
        case "RETIREMENT":
            return .indigo
        case "PROPERTY":
            return .brown
        case "VEHICLE":
            return .gray
        case "OTHER_ASSET":
            return .teal
        default:
            return .gray
        }
    }
    
    private var valueColor: Color {
        switch data.assetType.uppercased() {
        case "CREDIT_CARD", "LOAN", "MORTGAGE", "OTHER_LIABILITY":
            return Theme.expense
        default:
            return .blue
        }
    }
    
    private var isLiability: Bool {
        ["CREDIT_CARD", "LOAN", "MORTGAGE", "OTHER_LIABILITY"].contains(data.assetType.uppercased())
    }
    
    private func formatValue() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let symbol = currencySymbol(data.currency)
        let prefix = isLiability ? "-" : ""
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

// MARK: - 信用卡更新卡片内容
struct CreditCardUpdateCardContent: View {
    @Binding var data: CreditCardParsed
    @State private var cardIdentifier: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            
            // 发卡银行
            HStack(spacing: Spacing.medium) {
                
                if let institution = data.institutionName, !institution.isEmpty {
                    Label(institution, systemImage: "building.2")
                        .font(AppFont.body(size: 18, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                // 显示信用额度（正数，不是待还金额）
                if let limit = data.creditLimit, limit > 0 {
                    Text(formatCreditLimit(limit))
                        .font(AppFont.monoNumber(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    
                }
            }

            if data.outstandingBalance > 0 {
                // 仅当没有额度但有待还金额时显示
                Text("待还金额：\(formatBalance())")
                    .font(AppFont.monoNumber(size: 16, weight: .bold))
                    .foregroundColor(Theme.expense)
            }
            
            // 额度和还款日
            HStack(spacing: Spacing.medium) {
                
                if let dueDate = data.repaymentDueDate, !dueDate.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundColor(Theme.expense)
                        Text("还款日: 每月\(dueDate)号")
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundColor(Theme.expense)
                    }
                }
            }
            
            // 卡片标识输入
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("卡片标识")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                
                CardIdentifierPicker(
                    cardIdentifier: $cardIdentifier,
                    placeholder: "请输入卡片标识（如尾号）"
                )
            }
        }
        .onAppear {
            cardIdentifier = data.cardIdentifier ?? ""
        }
        .onChange(of: cardIdentifier) { newValue in
            data.cardIdentifier = newValue.isEmpty ? nil : newValue
        }
    }
    
    private func formatBalance() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let symbol = currencySymbol(data.currency)
        // 待还金额显示为负数（仅当有待还金额时）
        if data.outstandingBalance > 0 {
            return "-\(symbol)\(formatter.string(from: NSDecimalNumber(decimal: data.outstandingBalance)) ?? "0.00")"
        }
        return "\(symbol)0.00"
    }
    
    private func formatCreditLimit(_ limit: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let symbol = currencySymbol(data.currency)
        return "\(symbol)\(formatter.string(from: NSNumber(value: limit)) ?? "0")"
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
                creditCardData: nil,
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
                creditCardData: nil,
                budgetData: nil
            ),
            // ASSET_UPDATE - 活期存款
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK",
                    assetName: "工商银行储蓄卡",
                    totalValue: 50000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "工商银行",
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ),
            // ASSET_UPDATE - 定期存款
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "SAVINGS",
                    assetName: "招商银行定期",
                    totalValue: 100000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    quantity: nil,
                    interestRateAPY: 2.85,
                    maturityDate: "2025-06-30",
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ),
            // ASSET_UPDATE - 股票
            ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "INVESTMENT",
                    assetName: "腾讯控股",
                    totalValue: 38500,
                    currency: "HKD",
                    date: Date(),
                    institutionName: "富途证券",
                    quantity: 100,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ),
            // BUDGET - 预算
            ParsedFinancialEvent(
                eventType: .budget,
                transactionData: nil,
                assetUpdateData: nil,
                creditCardData: nil,
                budgetData: BudgetParsed(
                    action: "CREATE_BUDGET",
                    name: "旅游基金",
                    targetAmount: 20000,
                    currency: "CNY",
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
            event: .constant(ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "BANK",
                    assetName: "工商银行储蓄卡",
                    totalValue: 50000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "工商银行",
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ))
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 定期存款") {
    VStack {
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "SAVINGS",
                    assetName: "招商银行定期",
                    totalValue: 100000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    quantity: nil,
                    interestRateAPY: 2.85,
                    maturityDate: "2025-06-30",
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ))
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 股票") {
    VStack {
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "INVESTMENT",
                    assetName: "腾讯控股",
                    totalValue: 38500,
                    currency: "HKD",
                    date: Date(),
                    institutionName: "富途证券",
                    quantity: 100,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ))
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 加密货币") {
    VStack {
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
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
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: nil,
                    repaymentSchedule: nil
                ),
                creditCardData: nil,
                budgetData: nil
            ))
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 信用卡") {
    VStack {
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "CREDIT_CARD",
                    assetName: "招商信用卡",
                    totalValue: 5000,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: 5000,
                    repaymentSchedule: "MONTHLY"
                ),
                creditCardData: nil,
                budgetData: nil
            ))
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("资产更新卡片 - 房贷") {
    VStack {
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .assetUpdate,
                transactionData: nil,
                assetUpdateData: AssetUpdateParsed(
                    assetType: "MORTGAGE",
                    assetName: "房产贷款",
                    totalValue: 100000,
                    currency: "USD",
                    date: Date(),
                    institutionName: nil,
                    quantity: nil,
                    interestRateAPY: nil,
                    maturityDate: nil,
                    isInitialRecord: false,
                    costBasis: nil,
                    costBasisCurrency: nil,
                    projectedValue: nil,
                    location: nil,
                    repaymentAmount: 3000,
                    repaymentSchedule: "MONTHLY"
                ),
                creditCardData: nil,
                budgetData: nil
            ))
        )
        .padding()
    }
    .background(Theme.background)
}

#Preview("信用卡更新卡片") {
    VStack(spacing: 16) {
        // 花旗信用卡
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .creditCardUpdate,
                transactionData: nil,
                assetUpdateData: nil,
                creditCardData: CreditCardParsed(
                    name: "花旗信用卡",
                    outstandingBalance: 500,
                    currency: "USD",
                    date: Date(),
                    institutionName: "花旗银行",
                    creditLimit: 53000,
                    repaymentDueDate: "04"
                ),
                budgetData: nil
            ))
        )
        
        // 招商信用卡
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .creditCardUpdate,
                transactionData: nil,
                assetUpdateData: nil,
                creditCardData: CreditCardParsed(
                    name: "招商信用卡",
                    outstandingBalance: 8500,
                    currency: "CNY",
                    date: Date(),
                    institutionName: "招商银行",
                    creditLimit: 50000,
                    repaymentDueDate: "15"
                ),
                budgetData: nil
            ))
        )
    }
    .padding()
    .background(Theme.background)
}

#Preview("交易记录卡片") {
    VStack(spacing: 16) {
        // 支出
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
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
                creditCardData: nil,
                budgetData: nil
            ))
        )
        
        // 收入
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
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
                creditCardData: nil,
                budgetData: nil
            ))
        )
    }
    .padding()
    .background(Theme.background)
}

#Preview("预算卡片") {
    VStack(spacing: 16) {
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .budget,
                transactionData: nil,
                assetUpdateData: nil,
                creditCardData: nil,
                budgetData: BudgetParsed(
                    action: "CREATE_BUDGET",
                    name: "旅游基金",
                    targetAmount: 20000,
                    currency: "CNY",
                    targetDate: "2025-06",
                    priority: "HIGH"
                )
            ))
        )
        
        EventConfirmCard(
            event: .constant(ParsedFinancialEvent(
                eventType: .budget,
                transactionData: nil,
                assetUpdateData: nil,
                creditCardData: nil,
                budgetData: BudgetParsed(
                    action: "UPDATE_BUDGET",
                    name: "信用卡还款",
                    targetAmount: 5000,
                    currency: "CNY",
                    targetDate: "2025-01",
                    priority: "MEDIUM"
                )
            ))
        )
    }
    .padding()
    .background(Theme.background)
}
