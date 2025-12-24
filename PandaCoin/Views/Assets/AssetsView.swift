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
        List {
            // 净值概览卡片
            Section {
                netWorthCard
            } header: {
                // 留出空间给 large title
                Color.clear.frame(height: 0)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            // 净资产区块
            if !netAssets.isEmpty {
                Section {
                    ForEach(netAssets) { account in
                        AccountCard(account: account, accountService: accountService)
                    }
                } header: {
                    Text("净资产")
                        .font(.headline)
                        .foregroundColor(Theme.bambooGreen)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
            
            // 负债区块 - 债务类
            if !debtLiabilities.isEmpty {
                Section {
                    ForEach(debtLiabilities) { account in
                        AccountCard(account: account, accountService: accountService)
                    }
                } header: {
                    Text("负债 - 债务")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
            
            // 负债区块 - 贷款类
            if !loanLiabilities.isEmpty {
                Section {
                    ForEach(loanLiabilities) { account in
                        AccountCard(account: account, accountService: accountService)
                    }
                } header: {
                    Text("负债 - 贷款")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
            
            // 空状态
            if accountService.accounts.isEmpty {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .modifier(ListBackgroundModifier())
        .navigationTitle("资产管理")
        .navigationBarTitleDisplayMode(.large)
        .background(Theme.background)
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
                        .foregroundColor(Theme.textSecondary)
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
                        .foregroundColor(Theme.textSecondary)
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
                .foregroundColor(Theme.textSecondary)
            Text("点击右上角 + 添加资产")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
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

// MARK: - 账户卡片 (CFO 风格升级 + 左滑编辑)
struct AccountCard: View {
    let account: Asset
    @ObservedObject var accountService: AssetService
    @State private var showEditSheet = false
    @State private var navigateToDetail = false
    
    var body: some View {
        ZStack {
            // 隐藏的 NavigationLink
            NavigationLink(destination: AssetDetailView(asset: account), isActive: $navigateToDetail) {
                EmptyView()
            }
            .opacity(0)
            
            // 可见的卡片内容
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
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .shadow(color: Theme.cfoShadow, radius: 8, x: 0, y: 4)
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToDetail = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showEditSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(Theme.bambooGreen)
            
            Button(role: .destructive) {
                deleteAccount()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditAccountView(account: account, accountService: accountService)
        }
    }
    
    private func deleteAccount() {
        accountService.deleteAccount(id: account.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    accountService.fetchAccounts()
                }
            )
            .store(in: &accountService.cancellables)
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

// MARK: - 资产详情视图
struct AssetDetailView: View {
    let asset: Asset
    @StateObject private var recordService = RecordService.shared
    @State private var records: [Record] = []
    @State private var isLoading = true
    @State private var selectedMonth: Date = Date()
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 资产概览卡片
                assetOverviewCard
                    .padding(.horizontal)
                    .padding(.top)
                
                // 月份选择器
                monthSelector
                    .padding(.top, Spacing.medium)
                
                // 记录列表
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                } else if records.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    recordsList
                }
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchRecords()
        }
        .onChange(of: selectedMonth) { _ in
            fetchRecords()
        }
    }
    
    // MARK: - 资产概览卡片
    private var assetOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                // 图标
                ZStack {
                    Circle()
                        .fill(assetColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: asset.type.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(assetColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.name)
                        .font(AppFont.body(size: 18, weight: .bold))
                        .foregroundColor(Theme.text)
                    
                    Text(asset.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // 当前余额
                VStack(alignment: .trailing, spacing: 4) {
                    Text(asset.type.isLiability ? "待还金额" : "当前余额")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text("¥\(asset.balance as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(asset.type.isLiability ? Theme.expense : Theme.income)
                }
            }
            
            // 本月统计
            HStack(spacing: 20) {
                monthStatItem(title: "本月收入", amount: monthlyIncome, color: Theme.income)
                
                Divider()
                    .frame(height: 30)
                
                monthStatItem(title: "本月支出", amount: monthlyExpense, color: Theme.expense)
                
                Divider()
                    .frame(height: 30)
                
                monthStatItem(title: "本月还款", amount: monthlyPayment, color: Theme.warning)
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }
    
    private func monthStatItem(title: String, amount: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                .font(AppFont.monoNumber(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }
    
    // MARK: - 月份选择器
    private var monthSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.bambooGreen)
                    .padding(8)
            }
            
            Spacer()
            
            Text(monthFormatter.string(from: selectedMonth))
                .font(AppFont.body(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.bambooGreen)
                    .padding(8)
            }
            .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            .opacity(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 记录列表
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        ForEach(groupedRecords[date] ?? []) { record in
                            AssetRecordRow(record: record)
                        }
                    } header: {
                        HStack {
                            Text(dateSectionFormatter.string(from: date))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            
            Text("本月暂无记录")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            
            Text("该资产在本月没有收支记录")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
    }
    
    // MARK: - 数据计算
    private var monthlyIncome: Decimal {
        records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    private var monthlyExpense: Decimal {
        records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    private var monthlyPayment: Decimal {
        records.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
    }
    
    private var groupedRecords: [Date: [Record]] {
        let calendar = Calendar.current
        return Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
    }
    
    // MARK: - 格式化器
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }
    
    private var dateSectionFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    private var assetColor: Color {
        switch asset.type {
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
    
    // MARK: - 方法
    private func fetchRecords() {
        isLoading = true
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let startDateStr = ISO8601DateFormatter().string(from: startOfMonth)
        let endDateStr = ISO8601DateFormatter().string(from: endOfMonth)
        
        recordService.fetchRecords(accountId: asset.id, startDate: startDateStr, endDate: endDateStr)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("获取记录失败: \(error)")
                    }
                },
                receiveValue: { fetchedRecords in
                    self.records = fetchedRecords
                }
            )
            .store(in: &recordService.cancellables)
    }
    
    private func previousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

// MARK: - 资产详情记录行
struct AssetRecordRow: View {
    let record: Record
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(CategoryMapper.icon(for: record.category))
                    .font(.system(size: 18))
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(CategoryMapper.displayName(for: record.category))
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)
                
                if let description = record.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 金额和时间
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(AppFont.monoNumber(size: 16, weight: .bold))
                    .foregroundColor(typeColor)
                
                Text(timeFormatter.string(from: record.date))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Theme.cfoShadow, radius: 4, x: 0, y: 2)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountStr = formatter.string(from: record.amount as NSDecimalNumber) ?? "0.00"
        
        switch record.type {
        case .expense, .payment:
            return "-¥\(amountStr)"
        case .income:
            return "+¥\(amountStr)"
        case .transfer:
            return "¥\(amountStr)"
        }
    }
    
    private var typeColor: Color {
        switch record.type {
        case .expense: return Theme.expense
        case .income: return Theme.income
        case .transfer: return Theme.textSecondary
        case .payment: return Theme.warning
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
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
    @ObservedObject var authService = AuthService.shared
    
    @State private var name: String
    @State private var balance: String
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    private var cancellables = Set<AnyCancellable>()
    
    init(account: Asset, accountService: AssetService) {
        self.account = account
        self.accountService = accountService
        _name = State(initialValue: account.name)
        _balance = State(initialValue: "\(account.balance)")
    }
    
    private var isDefaultAccount: Bool {
        authService.isDefaultExpenseAccount(accountId: account.id, type: .account)
    }
    
    /// 是否可以设为默认支出账户（只有净资产类型才可以）
    private var canBeDefaultAccount: Bool {
        switch account.type {
        case .bank, .cash, .digitalWallet, .savings:
            return true
        default:
            return false
        }
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
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    Section("当前余额") {
                        TextField("余额", text: $balance)
                            .keyboardType(.decimalPad)
                    }
                    
                    // 默认支出账户设置（只有净资产类型才显示）
                    if canBeDefaultAccount {
                        Section {
                            Button(action: toggleDefaultAccount) {
                                HStack {
                                    Image(systemName: isDefaultAccount ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isDefaultAccount ? Theme.bambooGreen : Theme.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("设为默认支出账户")
                                            .foregroundColor(Theme.text)
                                        
                                        if isDefaultAccount {
                                            Text("消费时将自动从此账户扣款")
                                                .font(.caption)
                                                .foregroundColor(Theme.bambooGreen)
                                        } else {
                                            Text("未设置默认账户时需手动选择")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if isDefaultAccount {
                                        Text("默认")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Theme.bambooGreen)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
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
    
    private func toggleDefaultAccount() {
        if isDefaultAccount {
            // 取消默认
            authService.clearDefaultExpenseAccount()
                .sink(receiveCompletion: { _ in }, receiveValue: { })
                .store(in: &accountService.cancellables)
        } else {
            // 设为默认
            authService.setDefaultExpenseAccount(accountId: account.id, accountType: .account)
                .sink(receiveCompletion: { _ in }, receiveValue: { })
                .store(in: &accountService.cancellables)
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

// MARK: - List 背景修饰符（兼容 iOS 15+）
struct ListBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
                .background(Theme.background)
        } else {
            content
                .background(Theme.background)
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
        }
    }
}

// MARK: - 导航栏背景修饰符
