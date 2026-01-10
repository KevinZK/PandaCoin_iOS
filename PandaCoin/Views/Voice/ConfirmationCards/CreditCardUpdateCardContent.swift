//
//  CreditCardUpdateCardContent.swift
//  PandaCoin
//
//  信用卡更新卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI

// MARK: - 信用卡更新卡片内容
struct CreditCardUpdateCardContent: View {
    @Binding var data: CreditCardParsed
    @State private var cardIdentifier: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            
            // 信用卡名称和发卡银行
            HStack(spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    // 显示信用卡名称
                    if !data.name.isEmpty {
                        Text(data.name)
                            .font(AppFont.body(size: 16, weight: .semibold))
                            .foregroundColor(Theme.text)
                    }
                    // 显示发卡银行（如果与名称不同）
                    if let institution = data.institutionName, !institution.isEmpty, institution != data.name {
                        Label(institution, systemImage: "building.2")
                            .font(AppFont.body(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
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
            
            // 自动扣款设置（信用卡）
            if data.repaymentDueDate != nil && !data.repaymentDueDate!.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
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
                        // 还款类型选择
                        VStack(alignment: .leading, spacing: 6) {
                            Text("还款类型")
                                .font(AppFont.body(size: 12))
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack(spacing: 12) {
                                repaymentTypeButton(title: "全额还款", type: "FULL", icon: "checkmark.circle.fill")
                                repaymentTypeButton(title: "最低还款", type: "MIN", icon: "minus.circle.fill")
                            }
                        }
                        
                        // 扣款来源
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
        .onAppear {
            cardIdentifier = data.cardIdentifier ?? ""
        }
        .onChange(of: cardIdentifier) { newValue in
            data.cardIdentifier = newValue.isEmpty ? nil : newValue
        }
    }
    
    @ViewBuilder
    private func repaymentTypeButton(title: String, type: String, icon: String) -> some View {
        let isSelected = (data.repaymentType ?? "FULL") == type
        Button(action: {
            data.repaymentType = type
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(AppFont.body(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.bambooGreen.opacity(0.15) : Theme.separator.opacity(0.3))
            .foregroundColor(isSelected ? Theme.bambooGreen : Theme.textSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.bambooGreen : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
