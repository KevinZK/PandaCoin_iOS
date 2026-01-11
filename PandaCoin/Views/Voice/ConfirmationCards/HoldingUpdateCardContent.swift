//
//  HoldingUpdateCardContent.swift
//  PandaCoin
//
//  持仓更新卡片内容 - 从 UnifiedConfirmationView 拆分
//

import SwiftUI
import Combine

// MARK: - 持仓更新卡片内容
struct HoldingUpdateCardContent: View {
    @Binding var data: HoldingUpdateParsed
    @ObservedObject private var accountService = AssetService.shared
    @State private var showAccountPicker = false
    @State private var selectedAccountId: String?
    @State private var isLoadingAccounts = true

    private var investmentAccounts: [Asset] {
        // 投资类账户：证券投资、加密货币、养老金
        accountService.accounts.filter {
            $0.type == .investment || $0.type == .crypto || $0.type == .retirement
        }
    }

    private var hasValidPrice: Bool {
        data.price > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 资产名称和交易类型
            HStack {
                HStack(spacing: 8) {
                    Text(typeIcon)
                        .font(.system(size: 20))
                    Text(data.name)
                        .font(AppFont.body(size: 18, weight: .semibold))
                        .foregroundColor(Theme.text)

                    if let code = data.tickerCode, !code.isEmpty {
                        Text(code)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.bambooGreen)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // 买入/卖出/持有标签
                Text(data.actionDisplayName)
                    .font(AppFont.body(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(actionColor)
                    .cornerRadius(8)
            }

            // 金额显示（仅当有有效价格时显示）
            if hasValidPrice {
                Text(formattedAmount)
                    .font(AppFont.monoNumber(size: 24, weight: .bold))
                    .foregroundColor(actionColor)
            }

            // 数量（和单价，如果有）
            HStack(spacing: Spacing.medium) {
                Label("\(formattedQuantity) \(unitName)", systemImage: "number")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)

                if hasValidPrice {
                    Label("@ \(currencySymbol)\(formattedPrice)", systemImage: "tag")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // 市场和类型标签
            HStack(spacing: 8) {
                Text(data.typeDisplayName)
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor)
                    .cornerRadius(10)

                Text(data.marketDisplayName)
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue)
                    .cornerRadius(10)
            }

            // 手续费（如果有）
            if let fee = data.fee, fee > 0 {
                HStack {
                    Image(systemName: "percent")
                        .font(.system(size: 12))
                    Text("手续费: \(currencySymbol)\(String(format: "%.2f", fee))")
                        .font(AppFont.body(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // 证券账户选择
            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if isLoadingAccounts {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载账户中...")
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Image(systemName: investmentAccounts.isEmpty ? "exclamationmark.triangle.fill" : "building.2")
                            .foregroundColor(investmentAccounts.isEmpty ? .orange : Theme.bambooGreen)
                            .font(.system(size: 14))
                        Text(investmentAccounts.isEmpty ? "请先创建证券账户" : "选择证券账户")
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundColor(investmentAccounts.isEmpty ? .orange : Theme.bambooGreen)
                    }
                }

                if !isLoadingAccounts && !investmentAccounts.isEmpty {
                    Button(action: { showAccountPicker = true }) {
                        HStack {
                            Image(systemName: "wallet.pass")
                                .foregroundColor(selectedAccountId == nil ? Theme.textSecondary : Theme.bambooGreen)

                            Text(selectedAccountName)
                                .font(AppFont.body(size: 14))
                                .foregroundColor(selectedAccountId == nil ? Theme.textSecondary : Theme.text)

                            Spacer()

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
                                .stroke(selectedAccountId != nil ? Theme.bambooGreen.opacity(0.5) : Color.orange.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            refreshAccountsAndMatch()
        }
        .onChange(of: selectedAccountId) { newValue in
            data.accountId = newValue
            if let id = newValue,
               let account = investmentAccounts.first(where: { $0.id == id }) {
                data.accountName = account.name
            }
        }
        .sheet(isPresented: $showAccountPicker) {
            InvestmentAccountPickerSheet(
                selectedAccountId: $selectedAccountId,
                accounts: investmentAccounts
            )
        }
    }

    // MARK: - 刷新账户并匹配
    private func refreshAccountsAndMatch() {
        isLoadingAccounts = true

        let holdingService = HoldingService.shared

        Publishers.Zip(
            accountService.fetchAssets(),
            holdingService.fetchHoldings()
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { _ in
                isLoadingAccounts = false
                matchAccountAfterRefresh()
            },
            receiveValue: { [weak accountService] assets, _ in
                // 确保账户数据在 receiveCompletion 之前更新
                accountService?.accounts = assets
            }
        )
        .store(in: &accountService.cancellables)
    }

    private func matchAccountAfterRefresh() {
        if data.holdingAction == "SELL" {
            let holdingService = HoldingService.shared
            let allHoldings = holdingService.holdings

            if let code = data.tickerCode, !code.isEmpty {
                if let matched = allHoldings.first(where: { $0.tickerCode?.uppercased() == code.uppercased() }) {
                    selectedAccountId = matched.investmentId
                    data.accountId = matched.investmentId
                    if let account = investmentAccounts.first(where: { $0.id == matched.investmentId }) {
                        data.accountName = account.name
                    }
                    return
                }
            }

            if let matched = allHoldings.first(where: { holding in
                holding.name.lowercased().contains(data.name.lowercased()) ||
                data.name.lowercased().contains(holding.name.lowercased())
            }) {
                selectedAccountId = matched.investmentId
                data.accountId = matched.investmentId
                if let account = investmentAccounts.first(where: { $0.id == matched.investmentId }) {
                    data.accountName = account.name
                }
                return
            }
        }

        if let accountName = data.accountName {
            if let matched = investmentAccounts.first(where: { $0.name.contains(accountName) || accountName.contains($0.name) }) {
                selectedAccountId = matched.id
                data.accountId = matched.id
                return
            }
        }
        if selectedAccountId == nil && investmentAccounts.count == 1 {
            selectedAccountId = investmentAccounts.first?.id
            data.accountId = investmentAccounts.first?.id
        }
    }

    // MARK: - 计算属性

    private var selectedAccountName: String {
        if let id = selectedAccountId,
           let account = investmentAccounts.first(where: { $0.id == id }) {
            return account.name
        }
        return "选择证券账户"
    }

    private var typeIcon: String {
        switch data.holdingType {
        case "STOCK": return "📈"
        case "ETF": return "📊"
        case "FUND": return "📉"
        case "BOND": return "📋"
        case "CRYPTO": return "₿"
        case "OPTION": return "📐"
        default: return "💵"
        }
    }

    private var typeColor: Color {
        switch data.holdingType {
        case "STOCK": return .blue
        case "ETF": return .purple
        case "FUND": return .green
        case "BOND": return .orange
        case "CRYPTO": return .yellow
        case "OPTION": return .red
        default: return .gray
        }
    }

    private var unitName: String {
        switch data.holdingType {
        case "STOCK", "ETF": return "股"
        case "FUND": return "份"
        case "BOND": return "份"
        case "CRYPTO": return "个"
        default: return "份"
        }
    }

    private var currencySymbol: String {
        switch data.currency.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY", "CNY": return "¥"
        case "HKD": return "HK$"
        default: return "¥"
        }
    }

    private var formattedAmount: String {
        let prefix: String
        switch data.holdingAction.uppercased() {
        case "BUY": prefix = "-"
        case "SELL": prefix = "+"
        default: prefix = ""  // HOLD 等不显示前缀
        }
        return "\(prefix)\(currencySymbol)\(data.formattedAmount)"
    }

    private var actionColor: Color {
        switch data.holdingAction.uppercased() {
        case "BUY": return Theme.expense
        case "SELL": return Theme.income
        case "HOLD": return Theme.bambooGreen
        default: return Theme.textSecondary
        }
    }

    private var formattedQuantity: String {
        if data.holdingType == "CRYPTO" {
            return String(format: "%.4f", data.quantity)
        }
        return String(format: "%.0f", data.quantity)
    }

    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: data.price)) ?? "0.00"
    }
}

// MARK: - 投资账户选择器
struct InvestmentAccountPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedAccountId: String?
    let accounts: [Asset]

    var body: some View {
        NavigationView {
            List {
                if accounts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary)
                            Text("暂无投资账户")
                                .foregroundColor(Theme.textSecondary)
                            Text("请先在资产管理中添加投资账户或加密货币账户")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    Section("投资/加密货币账户") {
                        ForEach(accounts) { account in
                            Button(action: {
                                selectedAccountId = account.id
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: account.type.icon)
                                        .foregroundColor(account.type == .crypto ? .yellow : .orange)
                                        .frame(width: 30)

                                    VStack(alignment: .leading) {
                                        Text(account.name)
                                            .foregroundColor(Theme.text)
                                        Text("余额: ¥\(account.formattedBalance)")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }

                                    Spacer()

                                    if selectedAccountId == account.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.bambooGreen)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("选择证券账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
