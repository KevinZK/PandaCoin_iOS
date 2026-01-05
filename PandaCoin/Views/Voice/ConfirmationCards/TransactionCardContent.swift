//
//  TransactionCardContent.swift
//  PandaCoin
//
//  交易卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI
import Combine

// MARK: - 交易卡片内容
struct TransactionCardContent: View {
    @Binding var data: AIRecordParsed
    @State private var cardIdentifier: String = ""
    @State private var showAccountPicker = false
    @State private var selectedAccountType: SelectedAccountInfo?
    @State private var isSmartRecommended = false
    @State private var originalCardIdentifier: String? = nil
    @State private var originalAccountName: String = ""
    @State private var usedDefaultAccount = false
    
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var accountService = AssetService.shared
    @ObservedObject private var creditCardService = CreditCardService.shared
    
    private var involvesCreditCard: Bool {
        data.accountName.contains("信用卡") || data.cardIdentifier != nil
    }
    
    private var shouldShowAccountPicker: Bool {
        (data.type == .expense && !involvesCreditCard) || data.type == .income
    }
    
    private var shouldShowCreditCardPicker: Bool {
        involvesCreditCard
    }
    
    private var hasSelectedAccount: Bool {
        selectedAccountType != nil
    }
    
    // 显示的账户名称（包含卡片尾号）
    private var displayAccountName: String {
        if let selected = selectedAccountType {
            return selected.displayName
        }
        if let identifier = data.cardIdentifier, !identifier.isEmpty {
            if data.accountName.isEmpty {
                return "信用卡 (\(identifier))"
            }
            if !data.accountName.contains(identifier) {
                return "\(data.accountName) (\(identifier))"
            }
        }
        return data.accountName
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
                
                if !displayAccountName.isEmpty {
                    Label(displayAccountName, systemImage: "creditcard")
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
            
            // 支出账户选择
            if shouldShowAccountPicker {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    accountPickerStatusView
                    
                    Button(action: { showAccountPicker = true }) {
                        HStack {
                            Image(systemName: selectedAccountType == nil ? "wallet.pass" : selectedAccountType!.icon)
                                .foregroundColor(selectedAccountType == nil ? Theme.textSecondary : Theme.bambooGreen)
                            
                            Text(selectedAccountType?.displayName ?? (data.type == .income ? "选择收款账户" : "选择账户或信用卡"))
                                .font(AppFont.body(size: 14))
                                .foregroundColor(selectedAccountType == nil ? Theme.textSecondary : Theme.text)
                            
                            Spacer()
                            
                            if usedDefaultAccount {
                                Text("默认")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.bambooGreen)
                                    .cornerRadius(4)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.cardBackground)
                        .cornerRadius(CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .stroke(hasSelectedAccount ? Theme.bambooGreen.opacity(0.5) : Color.orange.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 信用卡选择器
            if shouldShowCreditCardPicker {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    creditCardPickerStatusView
                    
                    Button(action: { showAccountPicker = true }) {
                        HStack {
                            Image(systemName: hasSelectedAccount ? "creditcard.circle.fill" : "creditcard")
                                .foregroundColor(hasSelectedAccount ? Theme.bambooGreen : Theme.textSecondary)
                            
                            Text(selectedAccountType?.displayName ?? "选择一张信用卡")
                                .font(AppFont.body(size: 14))
                                .foregroundColor(hasSelectedAccount ? Theme.text : Theme.textSecondary)
                            
                            Spacer()
                            
                            if isSmartRecommended {
                                Text("点击修改")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.cardBackground)
                        .cornerRadius(CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .stroke(hasSelectedAccount ? Theme.bambooGreen.opacity(0.5) : Color.orange.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            originalAccountName = data.accountName
            originalCardIdentifier = data.cardIdentifier
            cardIdentifier = data.cardIdentifier ?? ""
            loadDefaultAccountIfNeeded()
            trySmartRecommendation()
        }
        .onChange(of: cardIdentifier) { newValue in
            data.cardIdentifier = newValue.isEmpty ? nil : newValue
        }
        .onChange(of: selectedAccountType) { newValue in
            if let account = newValue {
                data.accountName = account.displayName
                if account.type == .creditCard {
                    data.cardIdentifier = account.cardIdentifier
                }
            }
        }
        .sheet(isPresented: $showAccountPicker, onDismiss: {
            if selectedAccountType != nil {
                isSmartRecommended = false
                usedDefaultAccount = false
            }
        }) {
            ExpenseAccountPickerSheet(
                selectedAccount: $selectedAccountType,
                accounts: accountService.accounts,
                creditCards: creditCardService.creditCards,
                isIncome: data.type == .income
            )
        }
    }
    
    // MARK: - 信用卡选择器状态视图
    @ViewBuilder
    private var creditCardPickerStatusView: some View {
        if !hasSelectedAccount {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("请选择信用卡")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
        } else if isSmartRecommended {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.bambooGreen)
                    .font(.system(size: 14))
                Text("智能推荐（可修改）")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.bambooGreen)
            }
        } else if originalCardIdentifier != nil && !(originalCardIdentifier?.isEmpty ?? true) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.bambooGreen)
                    .font(.system(size: 14))
                Text("已识别信用卡（可修改）")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.bambooGreen)
            }
        } else {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.bambooGreen)
                    .font(.system(size: 14))
                Text("已选择信用卡")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.bambooGreen)
            }
        }
    }
    
    // MARK: - 账户选择器状态视图
    @ViewBuilder
    private var accountPickerStatusView: some View {
        let accountTypeText = data.type == .income ? "收入账户" : "支出账户"
        
        if !hasSelectedAccount {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("请选择\(accountTypeText)")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
        } else if usedDefaultAccount {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(Theme.bambooGreen)
                    .font(.system(size: 14))
                Text("已使用默认账户（可修改）")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.bambooGreen)
            }
        } else if !originalAccountName.isEmpty {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.bambooGreen)
                    .font(.system(size: 14))
                Text("已自动匹配（可修改）")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.bambooGreen)
            }
        } else {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.bambooGreen)
                    .font(.system(size: 14))
                Text("已选择\(accountTypeText)")
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.bambooGreen)
            }
        }
    }
    
    private func loadDefaultAccountIfNeeded() {
        guard (data.type == .expense && !involvesCreditCard) || data.type == .income,
              selectedAccountType == nil else { return }
        
        if !originalAccountName.isEmpty {
            if let matchedAccount = accountService.accounts.first(where: { $0.name == originalAccountName }) {
                selectedAccountType = SelectedAccountInfo(
                    id: matchedAccount.id,
                    displayName: matchedAccount.name,
                    type: .account,
                    icon: matchedAccount.type.icon,
                    cardIdentifier: nil
                )
                usedDefaultAccount = false
                return
            }
        }
        
        if let user = authService.currentUser {
            let defaultAccountId: String?
            let defaultAccountType: String?
            
            if data.type == .income {
                defaultAccountId = user.defaultIncomeAccountId
                defaultAccountType = user.defaultIncomeAccountType
            } else {
                defaultAccountId = user.defaultExpenseAccountId
                defaultAccountType = user.defaultExpenseAccountType
            }
            
            if let accountId = defaultAccountId, let accountType = defaultAccountType {
                if accountType == "ACCOUNT" {
                    if let account = accountService.accounts.first(where: { $0.id == accountId }) {
                        selectedAccountType = SelectedAccountInfo(
                            id: account.id,
                            displayName: account.name,
                            type: .account,
                            icon: account.type.icon,
                            cardIdentifier: nil
                        )
                        usedDefaultAccount = true
                    }
                } else if accountType == "CREDIT_CARD" && data.type == .expense {
                    if let card = creditCardService.creditCards.first(where: { $0.id == accountId }) {
                        selectedAccountType = SelectedAccountInfo(
                            id: card.id,
                            displayName: card.displayName,
                            type: .creditCard,
                            icon: "creditcard.circle.fill",
                            cardIdentifier: card.cardIdentifier
                        )
                        usedDefaultAccount = true
                    }
                }
            }
        }
    }
    
    private func trySmartRecommendation() {
        if let identifier = data.cardIdentifier, !identifier.isEmpty {
            if let matchedCard = creditCardService.creditCards.first(where: { $0.cardIdentifier == identifier }) {
                selectedAccountType = SelectedAccountInfo(
                    id: matchedCard.id,
                    displayName: matchedCard.displayName,
                    type: .creditCard,
                    icon: "creditcard.circle.fill",
                    cardIdentifier: matchedCard.cardIdentifier
                )
                isSmartRecommended = false
                return
            }
        }
        
        guard !data.accountName.isEmpty,
              data.accountName.contains("信用卡"),
              data.cardIdentifier == nil else { return }
        
        let institutionName = data.accountName
            .replacingOccurrences(of: "信用卡", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard !institutionName.isEmpty else { return }
        
        authService.getRecommendedAccount(institutionName: institutionName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [self] response in
                    if let recommended = response.recommended {
                        self.selectedAccountType = SelectedAccountInfo(
                            id: recommended.id,
                            displayName: recommended.displayName,
                            type: .creditCard,
                            icon: "creditcard.circle.fill",
                            cardIdentifier: recommended.cardIdentifier
                        )
                        self.cardIdentifier = recommended.cardIdentifier
                        self.isSmartRecommended = true
                    }
                }
            )
            .store(in: &creditCardService.cancellables)
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

// MARK: - 选中的账户信息
struct SelectedAccountInfo: Equatable {
    let id: String
    let displayName: String
    let type: DefaultAccountType
    let icon: String
    let cardIdentifier: String?
}

// MARK: - 账户选择器 Sheet（支持支出和收入类型）
struct ExpenseAccountPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedAccount: SelectedAccountInfo?

    let accounts: [Asset]
    let creditCards: [CreditCard]
    let isIncome: Bool

    init(selectedAccount: Binding<SelectedAccountInfo?>, accounts: [Asset], creditCards: [CreditCard], isIncome: Bool = false) {
        self._selectedAccount = selectedAccount
        self.accounts = accounts
        self.creditCards = creditCards
        self.isIncome = isIncome
    }

    private var availableAccounts: [Asset] {
        accounts.filter { account in
            switch account.type {
            case .bank, .cash, .digitalWallet, .savings:
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !availableAccounts.isEmpty {
                    Section(isIncome ? "收款账户" : "储蓄账户") {
                        ForEach(availableAccounts) { account in
                            Button(action: {
                                selectedAccount = SelectedAccountInfo(
                                    id: account.id,
                                    displayName: account.name,
                                    type: .account,
                                    icon: account.type.icon,
                                    cardIdentifier: nil
                                )
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: account.type.icon)
                                        .foregroundColor(Theme.bambooGreen)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text(account.name)
                                            .foregroundColor(Theme.text)
                                        Text("余额: ¥\(account.formattedBalance)")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedAccount?.id == account.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.bambooGreen)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if !isIncome && !creditCards.isEmpty {
                    Section("信用卡") {
                        ForEach(creditCards) { card in
                            Button(action: {
                                selectedAccount = SelectedAccountInfo(
                                    id: card.id,
                                    displayName: card.displayName,
                                    type: .creditCard,
                                    icon: "creditcard.circle.fill",
                                    cardIdentifier: card.cardIdentifier
                                )
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "creditcard.circle.fill")
                                        .foregroundColor(.purple)
                                        .frame(width: 30)

                                    VStack(alignment: .leading) {
                                        Text(card.displayName)
                                            .foregroundColor(Theme.text)
                                        Text("可用额度: ¥\(String(format: "%.0f", card.availableCredit))")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }

                                    Spacer()

                                    if selectedAccount?.id == card.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.bambooGreen)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                let hasNoOptions = isIncome ? availableAccounts.isEmpty : (availableAccounts.isEmpty && creditCards.isEmpty)
                if hasNoOptions {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "wallet.pass")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text("暂无可用账户")
                                .foregroundColor(Theme.textSecondary)
                            Text(isIncome ? "请先添加储蓄账户" : "请先添加储蓄账户或信用卡")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle(isIncome ? "选择收入账户" : "选择支出账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
