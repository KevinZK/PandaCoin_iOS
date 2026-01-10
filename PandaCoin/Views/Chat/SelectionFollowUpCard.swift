//
//  SelectionFollowUpCard.swift
//  PandaCoin
//
//  统一的选择器追问卡片 - 用于账户、信用卡等选择
//  样式与普通回复气泡一致，只是多了选择器
//

import SwiftUI

// MARK: - 账户选择来源类型
enum AccountSelectionSource {
    case defaultAccount      // 用户默认设置的账户
    case smartRecommend      // AI 智能推荐
    case userSelection       // 用户手动选择
    case none               // 无预选
    
    var statusText: String {
        switch self {
        case .defaultAccount:
            return "检测到您有默认的支出资产账户"
        case .smartRecommend:
            return "AI 智能推荐账户"
        case .userSelection:
            return ""
        case .none:
            return "请选择支付账户"
        }
    }
    
    var statusIcon: String {
        switch self {
        case .defaultAccount:
            return "star.fill"
        case .smartRecommend:
            return "sparkles"
        case .userSelection, .none:
            return "wallet.pass"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .defaultAccount:
            return .orange
        case .smartRecommend:
            return .purple
        case .userSelection, .none:
            return Theme.textSecondary
        }
    }
}

// MARK: - 统一选择器追问卡片
struct SelectionFollowUpCard: View {
    let needMoreInfo: NeedMoreInfoParsed
    let onSelection: (SelectedAccountInfo) -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var accountService = AssetService.shared
    @ObservedObject private var creditCardService = CreditCardService.shared
    @ObservedObject private var authService = AuthService.shared
    @State private var selectedAccount: SelectedAccountInfo?
    @State private var selectionSource: AccountSelectionSource = .none
    @State private var showPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 显示 AI 追问消息（优先显示）
            if !needMoreInfo.question.isEmpty {
                Text(needMoreInfo.question)
                    .font(AppFont.body(size: 15))
                    .foregroundColor(Theme.text)
            } else if let summary = partialDataSummary {
                // 兜底：显示已解析的部分信息（交易摘要）
                Text(summary)
                    .font(AppFont.body(size: 15))
                    .foregroundColor(Theme.text)
            }
            
            // 状态提示
            HStack(spacing: 6) {
                Image(systemName: selectionSource.statusIcon)
                    .font(.system(size: 12))
                    .foregroundColor(selectionSource.statusColor)
                Text(selectionSource.statusText)
                    .font(AppFont.body(size: 13))
                    .foregroundColor(selectionSource.statusColor)
            }
            .padding(.top, 4)
            
            // 账户选择按钮
            Button(action: { showPicker = true }) {
                HStack(spacing: 10) {
                    if let account = selectedAccount {
                        Image(systemName: account.icon)
                            .foregroundColor(Theme.bambooGreen)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(AppFont.body(size: 14, weight: .medium))
                                .foregroundColor(Theme.text)
                            if let subtitle = accountSubtitle(for: account) {
                                Text(subtitle)
                                    .font(AppFont.body(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    } else {
                        Image(systemName: "wallet.pass")
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 24)
                        Text("点击选择账户")
                            .font(AppFont.body(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedAccount != nil ? Theme.bambooGreen : Theme.separator, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("取消")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.separator.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    if let selected = selectedAccount {
                        onSelection(selected)
                    }
                }) {
                    Text("确认")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedAccount != nil ? Theme.bambooGreen : Theme.separator)
                        .cornerRadius(8)
                }
                .disabled(selectedAccount == nil)
            }
            .padding(.top, 4)
        }
        .padding(Spacing.medium)
        .background(Theme.background.opacity(0.95))
        .cornerRadius(16)
        .onAppear {
            initializeSelection()
        }
        .sheet(isPresented: $showPicker) {
            AccountPickerSheet(
                pickerType: needMoreInfo.pickerType ?? .expenseAccount,
                accounts: availableExpenseAccounts,
                creditCards: creditCardService.creditCards,
                investmentAccounts: investmentAccounts,
                selectedAccount: $selectedAccount,
                onSelect: { account in
                    selectedAccount = account
                    selectionSource = .userSelection
                    showPicker = false
                }
            )
        }
    }
    
    // MARK: - 初始化选择
    private func initializeSelection() {
        // 优先级1: 用户默认支出账户
        if let defaultAccountId = authService.currentUser?.defaultExpenseAccountId,
           let defaultAccount = accountService.accounts.first(where: { $0.id == defaultAccountId }) {
            selectedAccount = SelectedAccountInfo(
                id: defaultAccount.id,
                displayName: defaultAccount.name,
                type: .account,
                icon: defaultAccount.type.icon,
                cardIdentifier: nil
            )
            selectionSource = .defaultAccount
            return
        }
        
        // 优先级2: AI 智能推荐（根据交易描述匹配）
        if let recommended = smartRecommendAccount() {
            selectedAccount = recommended
            selectionSource = .smartRecommend
            return
        }
        
        // 优先级3: 无预选
        selectionSource = .none
    }
    
    // MARK: - AI 智能推荐账户
    private func smartRecommendAccount() -> SelectedAccountInfo? {
        guard let txData = needMoreInfo.partialTransactionData else { return nil }
        
        let description = txData.description.lowercased()
        
        // 根据消费描述智能匹配
        // 例如：包含"支付宝"、"微信"关键词 → 推荐数字钱包
        if description.contains("支付宝") || description.contains("alipay") {
            if let wallet = accountService.accounts.first(where: { 
                $0.type == .digitalWallet && $0.name.contains("支付宝") 
            }) {
                return SelectedAccountInfo(
                    id: wallet.id,
                    displayName: wallet.name,
                    type: .account,
                    icon: wallet.type.icon,
                    cardIdentifier: nil
                )
            }
        }
        
        if description.contains("微信") || description.contains("wechat") {
            if let wallet = accountService.accounts.first(where: { 
                $0.type == .digitalWallet && $0.name.contains("微信") 
            }) {
                return SelectedAccountInfo(
                    id: wallet.id,
                    displayName: wallet.name,
                    type: .account,
                    icon: wallet.type.icon,
                    cardIdentifier: nil
                )
            }
        }
        
        // 如果只有一个可用账户，自动推荐
        if availableExpenseAccounts.count == 1, let onlyAccount = availableExpenseAccounts.first {
            return SelectedAccountInfo(
                id: onlyAccount.id,
                displayName: onlyAccount.name,
                type: .account,
                icon: onlyAccount.type.icon,
                cardIdentifier: nil
            )
        }
        
        return nil
    }
    
    // MARK: - 部分数据摘要
    private var partialDataSummary: String? {
        if let tx = needMoreInfo.partialTransactionData {
            let typeStr = tx.type == .income ? "收入" : "支出"
            return "记录\(typeStr): \(tx.description) ¥\(tx.amount)"
        }
        if let holding = needMoreInfo.partialHoldingData {
            return "记录: \(holding.actionDisplayName) \(holding.name) \(Int(holding.quantity))股"
        }
        if let autoPayment = needMoreInfo.partialAutoPaymentData {
            return "记录: \(autoPayment.name) ¥\(autoPayment.amount)/月"
        }
        return nil
    }
    
    // MARK: - 账户副标题
    private func accountSubtitle(for account: SelectedAccountInfo) -> String? {
        if account.type == .creditCard {
            if let card = creditCardService.creditCards.first(where: { $0.id == account.id }) {
                return "可用额度: ¥\(String(format: "%.0f", card.availableCredit))"
            }
        } else {
            if let asset = accountService.accounts.first(where: { $0.id == account.id }) {
                return "余额: ¥\(asset.formattedBalance)"
            }
        }
        return nil
    }
    
    // MARK: - 账户过滤
    private var availableExpenseAccounts: [Asset] {
        accountService.accounts.filter { account in
            switch account.type {
            case .bank, .cash, .digitalWallet, .savings:
                return true
            default:
                return false
            }
        }
    }
    
    private var investmentAccounts: [Asset] {
        accountService.accounts.filter { $0.type == .investment }
    }
}

// MARK: - 账户选择 Sheet
struct AccountPickerSheet: View {
    let pickerType: FollowUpPickerType
    let accounts: [Asset]
    let creditCards: [CreditCard]
    let investmentAccounts: [Asset]
    @Binding var selectedAccount: SelectedAccountInfo?
    let onSelect: (SelectedAccountInfo) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                switch pickerType {
                case .expenseAccount, .autoPaymentSource:
                    expenseAccountSections
                case .incomeAccount:
                    incomeAccountSections
                case .creditCard:
                    creditCardSection
                case .investmentAccount:
                    investmentAccountSection
                default:
                    Text("暂无可选项")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private var expenseAccountSections: some View {
        if !accounts.isEmpty {
            Section("储蓄账户") {
                ForEach(accounts) { account in
                    accountRow(account: account)
                }
            }
        }
        
        if pickerType != .autoPaymentSource && !creditCards.isEmpty {
            Section("信用卡") {
                ForEach(creditCards) { card in
                    creditCardRow(card: card)
                }
            }
        }
        
        if accounts.isEmpty && (pickerType == .autoPaymentSource || creditCards.isEmpty) {
            Section {
                EmptyAccountView()
            }
        }
    }
    
    @ViewBuilder
    private var incomeAccountSections: some View {
        if !accounts.isEmpty {
            Section("收款账户") {
                ForEach(accounts) { account in
                    accountRow(account: account)
                }
            }
        } else {
            Section {
                EmptyAccountView()
            }
        }
    }
    
    @ViewBuilder
    private var creditCardSection: some View {
        if !creditCards.isEmpty {
            Section("信用卡") {
                ForEach(creditCards) { card in
                    creditCardRow(card: card)
                }
            }
        } else {
            Section {
                Text("暂无信用卡")
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    @ViewBuilder
    private var investmentAccountSection: some View {
        if !investmentAccounts.isEmpty {
            Section("投资账户") {
                ForEach(investmentAccounts) { account in
                    accountRow(account: account)
                }
            }
        } else {
            Section {
                Text("暂无投资账户")
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    private func accountRow(account: Asset) -> some View {
        Button(action: {
            onSelect(SelectedAccountInfo(
                id: account.id,
                displayName: account.name,
                type: .account,
                icon: account.type.icon,
                cardIdentifier: nil
            ))
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
    
    private func creditCardRow(card: CreditCard) -> some View {
        Button(action: {
            onSelect(SelectedAccountInfo(
                id: card.id,
                displayName: card.displayName,
                type: .creditCard,
                icon: "creditcard.circle.fill",
                cardIdentifier: card.cardIdentifier
            ))
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

// MARK: - 支出账户列表（含信用卡）
struct ExpenseAccountList: View {
    let accounts: [Asset]
    let creditCards: [CreditCard]
    @Binding var selectedAccount: SelectedAccountInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if !accounts.isEmpty {
                    Text("储蓄账户")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(accounts) { account in
                        AccountSelectionRow(
                            icon: account.type.icon,
                            iconColor: Theme.bambooGreen,
                            title: account.name,
                            subtitle: "余额: ¥\(account.formattedBalance)",
                            isSelected: selectedAccount?.id == account.id
                        ) {
                            selectedAccount = SelectedAccountInfo(
                                id: account.id,
                                displayName: account.name,
                                type: .account,
                                icon: account.type.icon,
                                cardIdentifier: nil
                            )
                        }
                    }
                }
                
                if !creditCards.isEmpty {
                    Text("信用卡")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    ForEach(creditCards) { card in
                        AccountSelectionRow(
                            icon: "creditcard.circle.fill",
                            iconColor: .purple,
                            title: card.displayName,
                            subtitle: "可用额度: ¥\(String(format: "%.0f", card.availableCredit))",
                            isSelected: selectedAccount?.id == card.id
                        ) {
                            selectedAccount = SelectedAccountInfo(
                                id: card.id,
                                displayName: card.displayName,
                                type: .creditCard,
                                icon: "creditcard.circle.fill",
                                cardIdentifier: card.cardIdentifier
                            )
                        }
                    }
                }
                
                if accounts.isEmpty && creditCards.isEmpty {
                    EmptyAccountView()
                }
            }
        }
        .frame(maxHeight: 250)
    }
}

// MARK: - 收入账户列表
struct IncomeAccountList: View {
    let accounts: [Asset]
    @Binding var selectedAccount: SelectedAccountInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(accounts) { account in
                    AccountSelectionRow(
                        icon: account.type.icon,
                        iconColor: Theme.bambooGreen,
                        title: account.name,
                        subtitle: "余额: ¥\(account.formattedBalance)",
                        isSelected: selectedAccount?.id == account.id
                    ) {
                        selectedAccount = SelectedAccountInfo(
                            id: account.id,
                            displayName: account.name,
                            type: .account,
                            icon: account.type.icon,
                            cardIdentifier: nil
                        )
                    }
                }
                
                if accounts.isEmpty {
                    EmptyAccountView()
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

// MARK: - 信用卡列表
struct CreditCardList: View {
    let creditCards: [CreditCard]
    @Binding var selectedAccount: SelectedAccountInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(creditCards) { card in
                    AccountSelectionRow(
                        icon: "creditcard.circle.fill",
                        iconColor: .purple,
                        title: card.displayName,
                        subtitle: "\(card.institutionName) · 尾号\(card.cardIdentifier)",
                        isSelected: selectedAccount?.id == card.id
                    ) {
                        selectedAccount = SelectedAccountInfo(
                            id: card.id,
                            displayName: card.displayName,
                            type: .creditCard,
                            icon: "creditcard.circle.fill",
                            cardIdentifier: card.cardIdentifier
                        )
                    }
                }
                
                if creditCards.isEmpty {
                    Text("暂无信用卡")
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

// MARK: - 投资账户列表
struct InvestmentAccountList: View {
    let accounts: [Asset]
    @Binding var selectedAccount: SelectedAccountInfo?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(accounts) { account in
                    AccountSelectionRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .blue,
                        title: account.name,
                        subtitle: "余额: ¥\(account.formattedBalance)",
                        isSelected: selectedAccount?.id == account.id
                    ) {
                        selectedAccount = SelectedAccountInfo(
                            id: account.id,
                            displayName: account.name,
                            type: .account,
                            icon: "chart.line.uptrend.xyaxis",
                            cardIdentifier: nil
                        )
                    }
                }
                
                if accounts.isEmpty {
                    Text("暂无投资账户")
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                }
            }
        }
        .frame(maxHeight: 200)
    }
}

// MARK: - 账户选择行
struct AccountSelectionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.text)
                    Text(subtitle)
                        .font(AppFont.body(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.bambooGreen)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.bambooGreen.opacity(0.1) : Theme.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.bambooGreen : Theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 空账户提示
struct EmptyAccountView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 32))
                .foregroundColor(Theme.textSecondary)
            Text("暂无可用资产类型")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
            Text("你可以资产模块添加资产账户或者让Finboo帮你添加：我的花旗银行储蓄卡有4000$")
                .font(AppFont.body(size: 12))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .padding()
    }
}

// MARK: - Preview
#Preview("选择器追问卡片 - 支出账户") {
    SelectionFollowUpCard(
        needMoreInfo: NeedMoreInfoParsed(
            originalIntent: .transaction,
            missingFields: ["source_account"],
            question: "请选择支付账户",
            pickerType: .expenseAccount,
            partialHoldingData: nil,
            partialAutoPaymentData: nil,
            partialTransactionData: AIRecordParsed(
                type: .expense,
                amount: 36,
                category: "FOOD",
                accountName: "",
                description: "晚饭",
                date: Date(),
                confidence: nil,
                cardIdentifier: nil
            ),
            partialAssetData: nil,
            partialCreditCardData: nil,
            partialBudgetData: nil
        ),
        onSelection: { _ in },
        onCancel: { }
    )
    .padding()
    .background(Theme.background)
}
