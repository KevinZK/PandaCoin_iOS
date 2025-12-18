//
//  AccountsView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine

struct AssetsView: View {
    @ObservedObject private var accountService = AssetService.shared
    @State private var showAddAccount = false
    
    // MARK: - 资产分类计算属性
    
    /// 净资产列表（非负债）
    private var netAssets: [Asset] {
        accountService.accounts.filter { !$0.type.isLiability }
    }
    
    /// 负债列表
    private var liabilities: [Asset] {
        accountService.accounts.filter { $0.type.isLiability }
    }
    
    /// 债务类负债（CREDIT_CARD, OTHER_LIABILITY）
    private var debtLiabilities: [Asset] {
        liabilities.filter { $0.type.liabilityCategory == .debt }
    }
    
    /// 贷款类负债（LOAN, MORTGAGE）
    private var loanLiabilities: [Asset] {
        liabilities.filter { $0.type.liabilityCategory == .loan }
    }
    
    /// 净资产总额
    private var totalNetAssets: Decimal {
        netAssets.reduce(0) { $0 + $1.balance }
    }
    
    /// 负债总额（取绝对值）
    private var totalLiabilities: Decimal {
        liabilities.reduce(0) { $0 + abs($1.balance) }
    }
    
    /// 真实净值 = 资产 - 负债
    private var netWorth: Decimal {
        totalNetAssets - totalLiabilities
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        // 净值概览卡片
                        netWorthCard
                        
                        // 净资产区块
                        if !netAssets.isEmpty {
                            sectionView(title: "净资产", assets: netAssets, titleColor: Theme.bambooGreen)
                        }
                        
                        // 负债区块
                        if !liabilities.isEmpty {
                            liabilitySectionView
                        }
                        
                        // 空状态
                        if accountService.accounts.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, Spacing.medium)
                }
            }
            .navigationTitle("资产管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddAccount = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.bambooGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(accountService: accountService)
            }
            .onAppear {
                accountService.fetchAccounts()
            }
        }
    }
    
    // MARK: - 净值概览卡片
    private var netWorthCard: some View {
        VStack(spacing: Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总资产")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("¥\(totalNetAssets as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("总负债")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("-¥\(totalLiabilities as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.headline)
                        .foregroundColor(.red.opacity(0.9))
                }
            }
            
            Divider().background(Color.white.opacity(0.3))
            
            VStack(spacing: 4) {
                Text("净值")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Text("¥\(netWorth as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(Spacing.large)
        .background(
            LinearGradient(
                colors: [Theme.bambooGreen, Theme.bambooGreen.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(CornerRadius.large)
        .shadow(color: Theme.bambooGreen.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - 通用区块视图
    private func sectionView(title: String, assets: [Asset], titleColor: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(title)
                .font(.headline)
                .foregroundColor(titleColor)
            
            ForEach(assets) { account in
                AccountCard(account: account, accountService: accountService)
            }
        }
    }
    
    // MARK: - 负债区块视图（含子分类）
    private var liabilitySectionView: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("负债")
                .font(.headline)
                .foregroundColor(.red)
            
            // 债务类（DEBT）
            if !debtLiabilities.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("债务 (DEBT)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                    
                    ForEach(debtLiabilities) { account in
                        AccountCard(account: account, accountService: accountService)
                    }
                }
            }
            
            // 贷款类（LOAN）
            if !loanLiabilities.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("贷款 (LOAN)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                    
                    ForEach(loanLiabilities) { account in
                        AccountCard(account: account, accountService: accountService)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: Spacing.medium) {
            Text("💳")
                .font(.system(size: 60))
            Text("还没有资产")
                .font(.headline)
                .foregroundColor(.gray)
            Text("点击右上角 + 添加资产")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(height: 200)
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - 账户卡片
struct AccountCard: View {
    let account: Asset
    @ObservedObject var accountService: AssetService
    @State private var showEditSheet = false
    
    var body: some View {
        Button(action: { showEditSheet = true }) {
            HStack(spacing: Spacing.medium) {
                // 图标
                Image(systemName: account.type.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(accountColor)
                    .clipShape(Circle())
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(Theme.text)
                    
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 余额
                Text("¥\(account.balance as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(.headline)
                    .foregroundColor(Theme.text)
            }
            .padding(Spacing.medium)
            .background(Color.white)
            .cornerRadius(CornerRadius.medium)
        }
        .sheet(isPresented: $showEditSheet) {
            EditAccountView(account: account, accountService: accountService)
        }
    }
    
    private var accountColor: Color {
        switch account.type {
        case .bank: return Theme.bambooGreen
        case .investment: return .orange
        case .cash: return .purple
        case .creditCard: return .blue
        case .digitalWallet: return .green
        case .loan: return .red
        case .mortgage: return .brown
        case .savings: return .teal
        case .retirement: return .indigo
        case .crypto: return .yellow
        case .property: return .gray
        case .vehicle: return .mint
        case .otherAsset: return .cyan
        case .otherLiability: return .pink
        }
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - 添加账户
struct AddAccountView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var accountService: AssetService
    
    @State private var name = ""
    @State private var type: AssetType = .bank
    @State private var balance = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Form {
                    Section("资产名称") {
                        TextField("例如:招商银行", text: $name)
                    }
                    
                    Section("资产类型") {
                        Picker("类型", selection: $type) {
                            ForEach(AssetType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                    }
                    
                    Section("初始余额") {
                        TextField("0.00", text: $balance)
                            .keyboardType(.decimalPad)
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("添加资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        createAccount()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func createAccount() {
        guard let balanceValue = Decimal(string: balance.isEmpty ? "0" : balance) else {
            errorMessage = "请输入有效的金额"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        accountService.createAccount(name: name, type: type, balance: balanceValue)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    accountService.fetchAccounts()
                    dismiss()
                }
            )
            .store(in: &accountService.cancellables)
    }
}

// MARK: - 编辑账户
struct EditAccountView: View {
    @Environment(\.dismiss) var dismiss
    let account: Asset
    @ObservedObject var accountService: AssetService
    
    @State private var name: String
    @State private var balance: String
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    
    init(account: Asset, accountService: AssetService) {
        self.account = account
        self.accountService = accountService
        _name = State(initialValue: account.name)
        _balance = State(initialValue: "\(account.balance)")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Form {
                    Section("资产名称") {
                        TextField("资产名称", text: $name)
                    }
                    
                    Section("资产类型") {
                        HStack {
                            Text("类型")
                            Spacer()
                            Label(account.type.displayName, systemImage: account.type.icon)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Section("当前余额") {
                        TextField("余额", text: $balance)
                            .keyboardType(.decimalPad)
                    }
                    
                    Section {
                        Button(role: .destructive, action: { showDeleteAlert = true }) {
                            HStack {
                                Spacer()
                                Label("删除资产", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("编辑资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        updateAccount()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .alert("删除资产", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("确定要删除这个资产吗？相关的记账记录也将被删除。")
            }
        }
    }
    
    private func updateAccount() {
        guard let balanceValue = Decimal(string: balance) else { return }
        
        isLoading = true
        
        accountService.updateAsset(id: account.id, name: name, balance: balanceValue)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    isLoading = false
                },
                receiveValue: { _ in
                    accountService.fetchAccounts()
                    dismiss()
                }
            )
            .store(in: &accountService.cancellables)
    }
    
    private func deleteAccount() {
        accountService.deleteAccount(id: account.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    accountService.fetchAccounts()
                    dismiss()
                }
            )
            .store(in: &accountService.cancellables)
    }
}

#Preview {
    AssetsView()
}
