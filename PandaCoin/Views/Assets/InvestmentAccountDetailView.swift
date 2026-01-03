//
//  InvestmentAccountDetailView.swift
//  PandaCoin
//
//  证券账户详情视图 - 显示持仓列表和市值
//

import SwiftUI
import Combine

struct InvestmentAccountDetailView: View {
    let asset: Asset
    @StateObject private var holdingService = HoldingService.shared
    @State private var holdings: [Holding] = []
    @State private var summary: HoldingsSummaryData?
    @State private var isLoading = true
    @State private var showAddHolding = false
    @State private var cancellables = Set<AnyCancellable>()
    
    // 编辑/删除相关状态
    @State private var holdingToEdit: Holding?
    @State private var showDeleteConfirm = false
    @State private var holdingToDelete: Holding?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 账户概览卡片
                accountOverviewCard
                    .padding(.horizontal)
                    .padding(.top)

                // 持仓列表
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                } else if holdings.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    holdingsList
                }
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddHolding = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.bambooGreen)
                }
            }
        }
        .sheet(isPresented: $showAddHolding) {
            AddHoldingView(accountId: asset.id)
                .onDisappear {
                    fetchHoldings()
                }
        }
        .sheet(item: $holdingToEdit) { holding in
            EditHoldingView(holding: holding)
                .onDisappear {
                    fetchHoldings()
                }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {
                holdingToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let holding = holdingToDelete {
                    deleteHolding(holding)
                }
            }
        } message: {
            if let holding = holdingToDelete {
                Text("确定要删除「\(holding.displayName ?? holding.name)」吗？\n删除后不会影响账户余额。")
            }
        }
        .onAppear {
            fetchHoldings()
        }
    }
    
    // MARK: - 删除持仓
    private func deleteHolding(_ holding: Holding) {
        holdingService.deleteHolding(id: holding.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("删除失败: \(error.localizedDescription)")
                }
                holdingToDelete = nil
            } receiveValue: { _ in
                // 从本地列表中移除
                holdings.removeAll { $0.id == holding.id }
            }
            .store(in: &cancellables)
    }

    // MARK: - 账户概览卡片
    private var accountOverviewCard: some View {
        VStack(spacing: 16) {
            // 上半部分：账户信息
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

                    HStack(spacing: 8) {
                        Text(asset.type.displayName)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        if !holdings.isEmpty {
                            Text("·")
                                .foregroundColor(Theme.textSecondary)
                            Text("\(holdings.count) 只持仓")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()
            }

            Divider()

            // 下半部分：资产统计（水平布局）
            HStack(spacing: 0) {

                // 持仓市值（暂显示为待计算，后期添加实时行情）
                VStack(spacing: 6) {
                    Text("持仓市值")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if holdings.isEmpty {
                        Text("--")
                            .font(AppFont.monoNumber(size: 18, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Text("待获取")
                            .font(AppFont.body(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // 总资产
                VStack(spacing: 6) {
                    Text("总资产")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(formattedTotalValue)
                        .font(AppFont.monoNumber(size: 18, weight: .bold))
                        .foregroundColor(Theme.text)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }

    private func assetStatItem(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Text("¥\(formattedNumber(amount))")
                .font(AppFont.monoNumber(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }

    // MARK: - 持仓列表
    private var holdingsList: some View {
        List {
            ForEach(holdings) { holding in
                ZStack {
                    // 隐藏的NavigationLink，去掉箭头
                    NavigationLink(destination: HoldingDetailView(holding: holding)) {
                        EmptyView()
                    }
                    .opacity(0)

                    HoldingCard(holding: holding)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // 删除按钮
                    Button(role: .destructive) {
                        holdingToDelete = holding
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }

                    // 编辑按钮
                    Button {
                        holdingToEdit = holding
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.5))

            Text("暂无持仓")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            Text("点击右上角 + 添加持仓")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.7))

            Button(action: { showAddHolding = true }) {
                Label("添加持仓", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.bambooGreen)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 计算属性
    private var totalValue: Double {
        // 暂时只显示现金余额，后期添加实时行情后再计算持仓市值
        Double(truncating: asset.balance as NSDecimalNumber)
    }

    private var formattedTotalValue: String {
        "¥\(formattedNumber(totalValue))"
    }

    private var assetColor: Color {
        switch asset.type {
        case .investment: return .orange
        case .crypto: return .yellow
        default: return Theme.bambooGreen
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    // MARK: - 数据获取
    private func fetchHoldings() {
        isLoading = true

        holdingService.fetchAccountHoldings(accountId: asset.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("获取持仓失败: \(error)")
                    }
                },
                receiveValue: { response in
                    self.holdings = response.holdings
                    self.summary = response.summary
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 持仓卡片
struct HoldingCard: View {
    let holding: Holding

    var body: some View {
        VStack(spacing: 12) {
            // 上半部分：图标 + 名称/代码 + 市值
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: holding.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(typeColor)
                }

                // 名称和代码
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(holding.displayName ?? holding.name)
                            .font(AppFont.body(size: 15, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)

                        
                    }
                    if let code = holding.tickerCode {
                        Text(code)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.textSecondary.opacity(0.1))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 6) {
                        Text("\(formattedQuantity)\(unitName)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Text("·")
                            .foregroundColor(Theme.textSecondary)

                        Text(holding.market.displayName)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                // 市值
                VStack(alignment: .trailing, spacing: 4) {
                    Text("¥\(holding.formattedMarketValue)")
                        .font(AppFont.monoNumber(size: 16, weight: .bold))
                        .foregroundColor(Theme.text)

                    // 盈亏金额和百分比
                    HStack(spacing: 4) {
                        Text(holding.formattedPnL)
                            .font(AppFont.monoNumber(size: 12, weight: .medium))
                            .foregroundColor(pnlColor)

                        Text(holding.formattedPnLPercent)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(pnlColor)
                            .cornerRadius(4)
                    }
                }
            }

            // 分割线
            Divider()

            // 下半部分：最新价 | 成本价
            HStack(spacing: 0) {
                // 最新价
                VStack(spacing: 2) {
                    Text("最新价")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("¥\(formattedPrice(holding.currentPrice ?? holding.avgCostPrice))")
                        .font(AppFont.monoNumber(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 28)

                // 成本价
                VStack(spacing: 2) {
                    Text("成本价")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("¥\(formattedPrice(holding.avgCostPrice))")
                        .font(AppFont.monoNumber(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: Theme.cfoShadow, radius: 8, x: 0, y: 4)
    }

    private var unitName: String {
        holding.type == .crypto ? "个" : "股"
    }

    private var pnlColor: Color {
        holding.isProfitable ? Theme.income : Theme.expense
    }

    private var typeColor: Color {
        switch holding.type {
        case .stock: return .blue
        case .etf: return .purple
        case .fund: return .green
        case .bond: return .orange
        case .crypto: return .yellow
        case .option: return .red
        case .other: return .gray
        }
    }

    private var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = holding.type == .crypto ? 8 : 0
        return formatter.string(from: NSNumber(value: holding.quantity)) ?? "0"
    }

    private func formattedPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - 持仓详情视图
struct HoldingDetailView: View {
    let initialHolding: Holding
    @StateObject private var holdingService = HoldingService.shared
    @State private var holding: Holding?  // 可变的持仓数据
    @State private var transactions: [HoldingTransaction] = []
    @State private var isLoading = true
    @State private var showBuySheet = false
    @State private var showSellSheet = false
    @State private var cancellables = Set<AnyCancellable>()
    
    // 使用当前持仓数据或初始数据
    private var currentHolding: Holding {
        holding ?? initialHolding
    }

    init(holding: Holding) {
        self.initialHolding = holding
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 持仓概览
                    holdingOverviewCard

                    // 操作按钮
                    actionButtons

                    // 交易记录
                    if !transactions.isEmpty {
                        transactionSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle(currentHolding.displayName ?? currentHolding.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBuySheet) {
            BuySellHoldingView(holding: currentHolding, action: .buy)
                .onDisappear {
                    refreshHolding()
                }
        }
        .sheet(isPresented: $showSellSheet) {
            BuySellHoldingView(holding: currentHolding, action: .sell)
                .onDisappear {
                    refreshHolding()
                }
        }
        .onAppear {
            refreshHolding()
            fetchTransactions()
        }
    }
    
    // MARK: - 刷新持仓数据
    private func refreshHolding() {
        holdingService.fetchHolding(id: initialHolding.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { updatedHolding in
                    self.holding = updatedHolding
                }
            )
            .store(in: &cancellables)
    }

    private var holdingOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(currentHolding.displayName ?? currentHolding.name)
                            .font(AppFont.body(size: 20, weight: .bold))
                            .foregroundColor(Theme.text)

                        if let code = currentHolding.tickerCode {
                            Text(code)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.bambooGreen)
                                .cornerRadius(6)
                        }
                    }

                    HStack(spacing: 12) {
                        Label(currentHolding.type.displayName, systemImage: currentHolding.type.icon)
                        Label(currentHolding.market.displayName, systemImage: "globe")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            Divider()

            // 持仓信息
            HStack(spacing: 0) {
                infoItem(title: "持仓数量", value: formattedQuantity)
                Spacer()
                infoItem(title: "成本价", value: "¥\(formattedNumber(currentHolding.avgCostPrice))")
                Spacer()
                infoItem(title: "现价", value: "¥\(formattedNumber(currentHolding.currentPrice ?? currentHolding.avgCostPrice))")
            }

            Divider()

            // 市值和盈亏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("市值")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text("¥\(currentHolding.formattedMarketValue)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("浮动盈亏")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    HStack(spacing: 8) {
                        Text(currentHolding.formattedPnL)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(currentHolding.isProfitable ? Theme.income : Theme.expense)

                        Text(currentHolding.formattedPnLPercent)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(currentHolding.isProfitable ? Theme.income : Theme.expense)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }

    private func infoItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(AppFont.monoNumber(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: { showBuySheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("买入")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.income)
                .cornerRadius(12)
            }

            Button(action: { showSellSheet = true }) {
                HStack {
                    Image(systemName: "minus.circle.fill")
                    Text("卖出")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.expense)
                .cornerRadius(12)
            }
            .disabled(currentHolding.quantity <= 0)
            .opacity(currentHolding.quantity <= 0 ? 0.5 : 1)
        }
    }

    private var transactionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易记录")
                .font(.headline)
                .foregroundColor(Theme.text)

            ForEach(transactions) { tx in
                HoldingTransactionRow(transaction: tx)
            }
        }
    }

    private var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currentHolding.type == .crypto ? 8 : 0
        return formatter.string(from: NSNumber(value: currentHolding.quantity)) ?? "0"
    }

    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    private func fetchTransactions() {
        holdingService.fetchTransactions(holdingId: initialHolding.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    isLoading = false
                },
                receiveValue: { txs in
                    self.transactions = txs
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 交易记录行
struct HoldingTransactionRow: View {
    let transaction: HoldingTransaction

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(typeColor)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type.displayName)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)

                Text("\(formattedQuantity) x ¥\(formattedPrice)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // 金额和日期
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(AppFont.monoNumber(size: 15, weight: .bold))
                    .foregroundColor(typeColor)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private var typeColor: Color {
        switch transaction.type {
        case .buy, .transferIn: return Theme.expense
        case .sell, .dividend, .transferOut: return Theme.income
        }
    }

    private var typeIcon: String {
        switch transaction.type {
        case .buy: return "arrow.down.circle.fill"
        case .sell: return "arrow.up.circle.fill"
        case .dividend: return "gift.fill"
        case .transferIn: return "arrow.right.circle.fill"
        case .transferOut: return "arrow.left.circle.fill"
        }
    }

    private var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: transaction.quantity)) ?? "0"
    }

    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: transaction.price)) ?? "0.00"
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amount = formatter.string(from: NSNumber(value: transaction.amount)) ?? "0.00"
        let prefix = (transaction.type == .buy || transaction.type == .transferIn) ? "-" : "+"
        return "\(prefix)¥\(amount)"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: transaction.date)
    }
}

// MARK: - 添加持仓视图 (占位)
struct AddHoldingView: View {
    let accountId: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Text("添加持仓")
                .navigationTitle("添加持仓")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - 买入/卖出视图
struct BuySellHoldingView: View {
    let holding: Holding
    let action: Action
    @Environment(\.dismiss) var dismiss
    @StateObject private var holdingService = HoldingService.shared

    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var fee: String = ""
    @State private var note: String = ""
    @State private var transactionDate = Date()
    @State private var showDatePicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    enum Action {
        case buy, sell

        var title: String {
            switch self {
            case .buy: return "买入"
            case .sell: return "卖出"
            }
        }

        var buttonColor: Color {
            switch self {
            case .buy: return Theme.income
            case .sell: return Theme.expense
            }
        }

        var icon: String {
            switch self {
            case .buy: return "plus.circle.fill"
            case .sell: return "minus.circle.fill"
            }
        }
    }

    // 计算交易金额
    private var transactionAmount: Double {
        let qty = Double(quantity) ?? 0
        let prc = Double(price) ?? 0
        let feeAmount = Double(fee) ?? 0
        return qty * prc + (action == .buy ? feeAmount : -feeAmount)
    }

    // 验证输入
    private var isValidInput: Bool {
        guard let qty = Double(quantity), qty > 0,
              let prc = Double(price), prc > 0 else {
            return false
        }
        // 卖出时检查数量不能超过持仓
        if action == .sell && qty > holding.quantity {
            return false
        }
        return true
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 持仓信息卡片
                        holdingInfoCard

                        // 交易表单
                        transactionForm

                        // 交易预览
                        if isValidInput {
                            transactionPreview
                        }

                        // 错误信息
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        // 提交按钮
                        submitButton
                    }
                    .padding()
                }
            }
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - 持仓信息卡片
    private var holdingInfoCard: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(action.buttonColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: action.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(action.buttonColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(holding.displayName ?? holding.name)
                    .font(AppFont.body(size: 17, weight: .bold))
                    .foregroundColor(Theme.text)

                HStack(spacing: 8) {
                    if let code = holding.tickerCode {
                        Text(code)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Text("持有 \(formattedHoldingQuantity)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("现价")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text("¥\(formattedCurrentPrice)")
                    .font(AppFont.monoNumber(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - 交易表单
    private var transactionForm: some View {
        VStack(spacing: 0) {
            // 数量输入
            formRow(title: "数量", placeholder: action == .sell ? "最多 \(formattedHoldingQuantity)" : "输入数量") {
                TextField("0", text: $quantity)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(Theme.text)
                    .font(AppFont.monoNumber(size: 16, weight: .medium))
            }

            Divider().padding(.leading, 16)

            // 价格输入
            formRow(title: "价格", placeholder: "输入价格") {
                HStack(spacing: 4) {
                    Text("¥")
                        .foregroundColor(Theme.textSecondary)
                    TextField("0.00", text: $price)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Theme.text)
                        .font(AppFont.monoNumber(size: 16, weight: .medium))
                }
            }

            Divider().padding(.leading, 16)

            // 手续费输入（可选）
            formRow(title: "手续费", placeholder: "可选") {
                HStack(spacing: 4) {
                    Text("¥")
                        .foregroundColor(Theme.textSecondary)
                    TextField("0.00", text: $fee)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Theme.text)
                        .font(AppFont.monoNumber(size: 16, weight: .medium))
                }
            }

            Divider().padding(.leading, 16)

            // 日期选择
            formRow(title: "日期", placeholder: "") {
                Button {
                    showDatePicker.toggle()
                } label: {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(Theme.text)
                }
            }

            if showDatePicker {
                DatePicker("", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
            }

            Divider().padding(.leading, 16)

            // 备注输入（可选）
            formRow(title: "备注", placeholder: "可选") {
                TextField("添加备注...", text: $note)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(Theme.text)
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private func formRow<Content: View>(title: String, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 交易预览
    private var transactionPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("交易金额")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("¥\(formattedTransactionAmount)")
                    .font(AppFont.monoNumber(size: 20, weight: .bold))
                    .foregroundColor(action.buttonColor)
            }

            if action == .sell, let qty = Double(quantity) {
                let remainingQty = holding.quantity - qty
                HStack {
                    Text("卖出后剩余")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(formatQuantity(remainingQty)) \(unitName)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(action.buttonColor.opacity(0.1))
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - 提交按钮
    private var submitButton: some View {
        Button {
            submitTransaction()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: action.icon)
                    Text("确认\(action.title)")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isValidInput && !isSubmitting ? action.buttonColor : Color.gray)
            .cornerRadius(CornerRadius.medium)
        }
        .disabled(!isValidInput || isSubmitting)
    }

    // MARK: - 提交交易
    private func submitTransaction() {
        guard let qty = Double(quantity), let prc = Double(price) else { return }

        isSubmitting = true
        errorMessage = nil

        let feeAmount = Double(fee)
        let noteText = note.isEmpty ? nil : note

        let publisher: AnyPublisher<BuyHoldingResponse, APIError>

        switch action {
        case .buy:
            publisher = holdingService.buy(
                holdingId: holding.id,
                quantity: qty,
                price: prc,
                fee: feeAmount,
                date: transactionDate,
                note: noteText
            )
        case .sell:
            publisher = holdingService.sell(
                holdingId: holding.id,
                quantity: qty,
                price: prc,
                fee: feeAmount,
                date: transactionDate,
                note: noteText
            )
        }

        publisher
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isSubmitting = false
                if case .failure(let error) = completion {
                    errorMessage = "\(action.title)失败: \(error.localizedDescription)"
                }
            } receiveValue: { _ in
                dismiss()
            }
            .store(in: &cancellables)
    }

    // MARK: - 格式化方法
    private var formattedHoldingQuantity: String {
        formatQuantity(holding.quantity)
    }

    private var formattedCurrentPrice: String {
        let price = holding.currentPrice ?? holding.avgCostPrice
        return formatPrice(price)
    }

    private var formattedTransactionAmount: String {
        formatPrice(transactionAmount)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: transactionDate)
    }

    private var unitName: String {
        holding.type == .crypto ? "个" : "股"
    }

    private func formatQuantity(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = holding.type == .crypto ? 8 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - 编辑持仓视图
struct EditHoldingView: View {
    let holding: Holding
    @Environment(\.dismiss) var dismiss
    @StateObject private var holdingService = HoldingService.shared
    
    @State private var name: String = ""
    @State private var displayName: String = ""
    @State private var tickerCode: String = ""
    @State private var quantity: String = ""
    @State private var avgCostPrice: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Form {
                    Section(header: Text("基本信息")) {
                        HStack {
                            Text("名称")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            TextField("资产名称", text: $name)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.text)
                        }
                        
                        HStack {
                            Text("显示名称")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            TextField("可选", text: $displayName)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.text)
                        }
                        
                        HStack {
                            Text("代码")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            TextField("如 AAPL", text: $tickerCode)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.text)
                                .autocapitalization(.allCharacters)
                        }
                    }
                    
                    Section(header: Text("持仓信息")) {
                        HStack {
                            Text("数量")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            TextField("0", text: $quantity)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .foregroundColor(Theme.text)
                        }
                        
                        HStack {
                            Text("成本价")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            TextField("0.00", text: $avgCostPrice)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .foregroundColor(Theme.text)
                        }
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("编辑持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveChanges() }
                        .foregroundColor(Theme.bambooGreen)
                        .disabled(isSaving || name.isEmpty)
                }
            }
            .onAppear {
                // 初始化表单数据
                name = holding.name
                displayName = holding.displayName ?? ""
                tickerCode = holding.tickerCode ?? ""
                quantity = String(format: holding.type == .crypto ? "%.8f" : "%.0f", holding.quantity)
                avgCostPrice = String(format: "%.2f", holding.avgCostPrice)
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        errorMessage = nil
        
        let request = UpdateHoldingRequest(
            name: name != holding.name ? name : nil,
            displayName: displayName.isEmpty ? nil : (displayName != holding.displayName ? displayName : nil),
            tickerCode: tickerCode.isEmpty ? nil : (tickerCode != holding.tickerCode ? tickerCode : nil),
            codeVerified: tickerCode.isEmpty ? nil : true,
            quantity: Double(quantity),
            avgCostPrice: Double(avgCostPrice),
            currentPrice: nil,
            market: nil
        )
        
        holdingService.updateHolding(id: holding.id, request: request)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isSaving = false
                if case .failure(let error) = completion {
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
            } receiveValue: { _ in
                dismiss()
            }
            .store(in: &cancellables)
    }
}
