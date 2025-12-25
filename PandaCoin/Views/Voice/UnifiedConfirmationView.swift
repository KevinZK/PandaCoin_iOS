//
//  UnifiedConfirmationView.swift
//  PandaCoin
//
//  统一确认视图 - 支持多种事件类型
//

import SwiftUI
import Combine

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
                                .background(Theme.cardBackground)
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
                if event.budgetData != nil {
                    BudgetCardContent(data: Binding(
                        get: { event.budgetData! },
                        set: { event.budgetData = $0 }
                    ))
                }
            case .nullStatement:
                EmptyView()
            }
        }
        .padding(Spacing.medium)
        .background(Theme.cardBackground)
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
    @State private var showAccountPicker = false
    @State private var selectedAccountType: SelectedAccountInfo?
    @State private var isSmartRecommended = false  // 是否是智能推荐的（用户可以修改）
    @State private var originalCardIdentifier: String? = nil  // 保存 AI 原始返回的 cardIdentifier
    @State private var originalAccountName: String = ""  // 保存 AI 原始返回的账户名（用于判断是否需要显示选择器）
    @State private var usedDefaultAccount = false  // 是否使用了默认账户预填
    
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var accountService = AssetService.shared
    @ObservedObject private var creditCardService = CreditCardService.shared
    
    // 是否涉及信用卡（根据账户名称判断）- 用于 AI 识别出信用卡但没有具体尾号的情况
    private var involvesCreditCard: Bool {
        data.accountName.contains("信用卡") || data.cardIdentifier != nil
    }
    
    // 是否需要显示账户选择器（支出类型且 AI 未识别出账户，或者使用了默认账户预填）
    private var shouldShowAccountPicker: Bool {
        data.type == .expense && (originalAccountName.isEmpty || usedDefaultAccount)
    }
    
    // 是否需要显示信用卡选择器（AI 识别出信用卡但没有明确尾号）
    // 使用 originalCardIdentifier 来判断，避免被 onChange 修改后的值影响
    private var shouldShowCreditCardPicker: Bool {
        involvesCreditCard &&
        !originalAccountName.isEmpty &&  // AI 识别出了账户名
        !usedDefaultAccount &&  // 不是默认账户预填的情况
        (originalCardIdentifier == nil || originalCardIdentifier?.isEmpty == true)
    }
    
    // 是否已经选择了账户（通过选择器或智能推荐或默认账户）
    private var hasSelectedAccount: Bool {
        selectedAccountType != nil
    }
    
    // 显示的账户名称（包含卡片尾号）
    private var displayAccountName: String {
        if let selected = selectedAccountType {
            return selected.displayName
        }
        
        // 如果有卡片标识，显示在账户名称后面
        if let identifier = data.cardIdentifier, !identifier.isEmpty {
            if data.accountName.isEmpty {
                return "信用卡 (\(identifier))"
            }
            // 避免重复显示尾号（如账户名已经包含尾号）
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
            
            // 支出账户选择（当 AI 未识别出账户时显示，或使用了默认账户时显示供用户修改）
            if shouldShowAccountPicker {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    if !hasSelectedAccount {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text("请选择支出账户")
                                .font(AppFont.body(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    } else if usedDefaultAccount {
                        // 使用了默认账户，提示用户可以修改
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(Theme.bambooGreen)
                                .font(.system(size: 14))
                            Text("已使用默认账户（可点击修改）")
                                .font(AppFont.body(size: 12, weight: .medium))
                                .foregroundColor(Theme.bambooGreen)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.bambooGreen)
                                .font(.system(size: 14))
                            Text("已选择支出账户")
                                .font(AppFont.body(size: 12, weight: .medium))
                                .foregroundColor(Theme.bambooGreen)
                        }
                    }
                    
                    Button(action: { showAccountPicker = true }) {
                        HStack {
                            Image(systemName: selectedAccountType == nil ? "wallet.pass" : selectedAccountType!.icon)
                                .foregroundColor(selectedAccountType == nil ? Theme.textSecondary : Theme.bambooGreen)
                            
                            Text(selectedAccountType?.displayName ?? "选择账户或信用卡")
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
            
            // 信用卡选择器（当 AI 识别出信用卡但没有具体尾号时显示）
            // 智能推荐会预填充，但用户可以修改
            if shouldShowCreditCardPicker {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    if hasSelectedAccount {
                        HStack {
                            Image(systemName: isSmartRecommended ? "sparkles" : "checkmark.circle.fill")
                                .foregroundColor(Theme.bambooGreen)
                                .font(.system(size: 14))
                            Text(isSmartRecommended ? "智能推荐（可修改）" : "已选择信用卡")
                                .font(AppFont.body(size: 12, weight: .medium))
                                .foregroundColor(Theme.bambooGreen)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text("请选择信用卡")
                                .font(AppFont.body(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    
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
            // 保存 AI 原始返回的值，用于判断是否需要显示选择器
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
            // 用户从选择器中选择后，清除智能推荐和默认账户标记
            if selectedAccountType != nil {
                isSmartRecommended = false
                usedDefaultAccount = false  // 用户手动选择了，不再是默认账户
            }
        }) {
            ExpenseAccountPickerSheet(
                selectedAccount: $selectedAccountType,
                accounts: accountService.accounts,
                creditCards: creditCardService.creditCards
            )
        }
    }
    
    private func loadDefaultAccountIfNeeded() {
        // 只有当 AI 没有识别出账户时才加载默认账户
        guard data.type == .expense,
              originalAccountName.isEmpty,
              selectedAccountType == nil else { return }
        
        // 尝试加载默认账户
        if let user = authService.currentUser,
           let accountId = user.defaultExpenseAccountId,
           let accountType = user.defaultExpenseAccountType {
            if accountType == "ACCOUNT" {
                if let account = accountService.accounts.first(where: { $0.id == accountId }) {
                    selectedAccountType = SelectedAccountInfo(
                        id: account.id,
                        displayName: account.name,
                        type: .account,
                        icon: account.type.icon,
                        cardIdentifier: nil
                    )
                    usedDefaultAccount = true  // 标记使用了默认账户
                }
            } else if accountType == "CREDIT_CARD" {
                if let card = creditCardService.creditCards.first(where: { $0.id == accountId }) {
                    selectedAccountType = SelectedAccountInfo(
                        id: card.id,
                        displayName: card.displayName,
                        type: .creditCard,
                        icon: "creditcard.circle.fill",
                        cardIdentifier: card.cardIdentifier
                    )
                    usedDefaultAccount = true  // 标记使用了默认账户
                }
            }
        }
    }
    
    /// 尝试智能推荐信用卡（当账户名称包含机构名称但没有卡片标识时）
    private func trySmartRecommendation() {
        // 如果账户名称不为空且包含"信用卡"，尝试智能推荐
        guard !data.accountName.isEmpty,
              data.accountName.contains("信用卡"),
              data.cardIdentifier == nil else { return }
        
        // 提取机构名称（去掉"信用卡"后缀）
        let institutionName = data.accountName
            .replacingOccurrences(of: "信用卡", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        guard !institutionName.isEmpty else { return }
        
        // 调用后端 API 获取推荐的信用卡
        authService.getRecommendedAccount(institutionName: institutionName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [self] response in
                    if let recommended = response.recommended {
                        // 智能推荐信用卡（用户可以修改）
                        self.selectedAccountType = SelectedAccountInfo(
                            id: recommended.id,
                            displayName: recommended.displayName,
                            type: .creditCard,
                            icon: "creditcard.circle.fill",
                            cardIdentifier: recommended.cardIdentifier
                        )
                        self.cardIdentifier = recommended.cardIdentifier
                        self.isSmartRecommended = true  // 标记为智能推荐，用户可以修改
                    }
                    // 如果没有匹配或有多张匹配，让用户手动选择（不预填充）
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

// MARK: - 支出账户选择器 Sheet
struct ExpenseAccountPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedAccount: SelectedAccountInfo?
    
    let accounts: [Asset]
    let creditCards: [CreditCard]
    
    // 过滤出可用于支出的账户（排除房产、车辆等）
    private var expenseAccounts: [Asset] {
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
                if !expenseAccounts.isEmpty {
                    Section("储蓄账户") {
                        ForEach(expenseAccounts) { account in
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
                
                if !creditCards.isEmpty {
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
                
                if expenseAccounts.isEmpty && creditCards.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "wallet.pass")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text("暂无可用账户")
                                .foregroundColor(Theme.textSecondary)
                            Text("请先添加储蓄账户或信用卡")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("选择支出账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
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
                    
                    // 自动还款设置
                    if data.repaymentDay != nil {
                        Divider()
                        
                        Toggle(isOn: Binding(
                            get: { data.autoRepayment ?? false },
                            set: { data.autoRepayment = $0 }
                        )) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(Theme.bambooGreen)
                                Text("启用自动还款")
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

// MARK: - 预算卡片内容
struct BudgetCardContent: View {
    @Binding var data: BudgetParsed
    
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
            
            // 自动还款设置（信用卡）
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
                            Text("启用自动还款")
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
                    priority: "HIGH",
                    isRecurring: false
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
                    priority: "HIGH",
                    isRecurring: true
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
                    priority: "MEDIUM",
                    isRecurring: false
                )
            ))
        )
    }
    .padding()
    .background(Theme.background)
}
