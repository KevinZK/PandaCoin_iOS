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
    
    // MARK: - 净值概览卡片 (CFO 风格升级)
    private var netWorthCard: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("资产净值")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("¥\(netWorth as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // 财务官徽章图标
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            // 财务健康比例条 (资产 vs 负债)
            VStack(spacing: 8) {
                let total = totalNetAssets + totalLiabilities
                let assetRatio = total > 0 ? Double(truncating: totalNetAssets as NSDecimalNumber) / Double(truncating: total as NSDecimalNumber) : 1.0
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white)
                            .frame(width: geo.size.width * max(0, min(1, assetRatio)))
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("资产占比 \(Int(assetRatio * 100))%")
                    Spacer()
                    Text("负债率 \(Int((1 - assetRatio) * 100))%")
                }
                .font(AppFont.body(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            }
            
            HStack(spacing: 20) {
                summaryMiniItem(title: "总资产", amount: totalNetAssets, color: .white)
                Divider().background(Color.white.opacity(0.3)).frame(height: 30)
                summaryMiniItem(title: "总负债", amount: totalLiabilities, color: .red.opacity(0.8))
            }
        }
        .padding(24)
        .background(
            ZStack {
                Theme.cardGradient
                
                // 装饰性装饰
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 150, height: 150)
                            .offset(x: 50, y: -50)
                    }
                    Spacer()
                }
            }
        )
        .cornerRadius(28)
        .shadow(color: Theme.bambooGreen.opacity(0.3), radius: 15, x: 0, y: 10)
    }
    
    private func summaryMiniItem(title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                .font(AppFont.body(size: 16, weight: .bold))
                .foregroundColor(color)
        }
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

// MARK: - 账户卡片 (CFO 风格升级)
struct AccountCard: View {
    let account: Asset
    @ObservedObject var accountService: AssetService
    @State private var showEditSheet = false
    
    var body: some View {
        Button(action: { showEditSheet = true }) {
            HStack(spacing: Spacing.medium) {
                // 图标
                ZStack {
                    Circle()
                        .fill(accountColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: account.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accountColor)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(AppFont.body(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // 余额
                VStack(alignment: .trailing, spacing: 4) {
                    Text("¥\(account.balance as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(AppFont.monoNumber(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    
                    if account.type.isLiability {
                        Text("待还金额")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
            .padding(Spacing.medium)
            .background(Color.white)
            .cornerRadius(CornerRadius.medium)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
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

#Preview("资产管理 - 私人财务官风格") {
    let service = AssetService.shared
    service.accounts = [
        Asset.mock(name: "招商银行储蓄卡", type: .bank, balance: 50000),
        Asset.mock(name: "支付宝余额", type: .digitalWallet, balance: 12000),
        Asset.mock(name: "现金", type: .cash, balance: 2500),
        Asset.mock(name: "车贷", type: .loan, balance: -180000),
        Asset.mock(name: "招商信用卡", type: .creditCard, balance: -8500)
    ]
    
    return NavigationView {
        AssetsView()
    }
}

// MARK: - Mock 扩展 (仅用于预览)
extension Asset {
    static func mock(name: String, type: AssetType, balance: Decimal) -> Asset {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "name": "\(name)",
            "type": "\(type.rawValue)",
            "balance": \(balance),
            "currency": "CNY",
            "userId": "user123",
            "createdAt": "\(ISO8601DateFormatter().string(from: Date()))",
            "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(Asset.self, from: json)
    }
}
