//
//  AssetUpdateCardContent.swift
//  PandaCoin
//
//  资产更新卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI

// MARK: - 资产更新卡片内容
struct AssetUpdateCardContent: View {
    @Binding var data: AssetUpdateParsed
    @State private var cardIdentifier: String = ""
    
    private var isCreditCard: Bool {
        data.assetType.uppercased() == "CREDIT_CARD"
    }
    
    private var isBankType: Bool {
        ["BANK", "SAVINGS", "DIGITAL_WALLET"].contains(data.assetType.uppercased())
    }
    
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
                
                // 卡号尾号（银行卡/储蓄卡）
                if isBankType, let identifier = data.cardIdentifier, !identifier.isEmpty {
                    Label("尾号 \(identifier)", systemImage: "creditcard")
                        .font(AppFont.body(size: 13, weight: .medium))
                        .foregroundColor(Theme.bambooGreen)
                }
                
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
            
            // 贷款专用信息（LOAN / MORTGAGE）
            if isLoanType {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 贷款期限和利率
                    HStack(spacing: Spacing.medium) {
                        if let months = data.loanTermMonths {
                            Label("\(months / 12)年\(months % 12 > 0 ? "\(months % 12)个月" : "")", systemImage: "calendar")
                                .font(AppFont.body(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        if let rate = data.interestRate {
                            Label(String(format: "%.2f%%", rate), systemImage: "percent")
                                .font(AppFont.body(size: 13))
                                .foregroundColor(rate == 0 ? Theme.income : Theme.warning)
                        }
                    }
                    
                    // 月供和还款日
                    HStack(spacing: Spacing.medium) {
                        if let payment = data.monthlyPayment {
                            Label("月供: ¥\(formatNumber(payment))", systemImage: "creditcard")
                                .font(AppFont.body(size: 13, weight: .medium))
                                .foregroundColor(Theme.expense)
                        }
                        
                        if let day = data.repaymentDay {
                            Label("每月\(day)日还款", systemImage: "calendar.badge.clock")
                                .font(AppFont.body(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    // 自动扣款设置
                    if data.repaymentDay != nil {
                        Divider()
                        
                        Toggle(isOn: Binding(
                            get: { data.autoRepayment ?? false },
                            set: { data.autoRepayment = $0 }
                        )) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(Theme.bambooGreen)
                                Text("启用自动扣款")
                                    .font(AppFont.body(size: 14, weight: .medium))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.bambooGreen))
                        
                        if data.autoRepayment == true {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("扣款来源账户")
                                    .font(AppFont.body(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                
                                if let source = data.sourceAccount, !source.isEmpty {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.income)
                                        Text(source)
                                            .font(AppFont.body(size: 14))
                                            .foregroundColor(Theme.text)
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(Theme.warning)
                                        Text("未设置，请在确认后手动设置")
                                            .font(AppFont.body(size: 13))
                                            .foregroundColor(Theme.warning)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Theme.separator.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
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
    
    private var isLoanType: Bool {
        ["LOAN", "MORTGAGE"].contains(data.assetType.uppercased())
    }
    
    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0"
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
