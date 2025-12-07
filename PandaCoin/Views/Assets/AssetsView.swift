//
//  AccountsView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine

struct AssetsView: View {
    @StateObject private var accountService = AssetService()
    @State private var showAddAccount = false
    
    var totalAssets: Decimal {
        accountService.accounts.reduce(0) { $0 + $1.balance }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        // 总资产卡片
                        totalAssetsCard
                        
                        // 账户列表
                        accountsList
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
    
    // MARK: - 总资产卡片
    private var totalAssetsCard: some View {
        VStack(spacing: Spacing.medium) {
            Text("总资产")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("¥\(totalAssets as NSDecimalNumber, formatter: currencyFormatter)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.extraLarge)
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
    
    // MARK: - 账户列表
    private var accountsList: some View {
        VStack(spacing: Spacing.medium) {
            ForEach(accountService.accounts) { account in
                AccountCard(account: account, accountService: accountService)
            }
            
            if accountService.accounts.isEmpty {
                emptyState
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
