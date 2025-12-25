//
//  CreditCardListView.swift
//  PandaCoin
//
//  信用卡管理列表视图
//

import SwiftUI

struct CreditCardListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var creditCardService = CreditCardService.shared
    @State private var showAddCard = false
    @State private var selectedCard: CreditCard?
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if creditCardService.isLoading && creditCardService.creditCards.isEmpty {
                ProgressView("加载中...")
            } else if creditCardService.creditCards.isEmpty {
                emptyStateView
            } else {
                cardListView
            }
        }
        .navigationTitle("信用卡管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("关闭") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddCard = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddCard) {
            NavigationView {
                AddCreditCardView()
            }
        }
        .sheet(item: $selectedCard) { card in
            NavigationView {
                EditCreditCardView(card: card)
            }
        }
        .onAppear {
            creditCardService.fetchCreditCards()
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Spacing.large) {
            Text("💳")
                .font(.system(size: 60))
            
            Text("暂无信用卡")
                .font(AppFont.body(size: 18, weight: .medium))
                .foregroundColor(Theme.text)
            
            Text("点击右上角 + 添加您的第一张信用卡")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showAddCard = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加信用卡")
                }
                .font(AppFont.body(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.bambooGreen)
                .cornerRadius(CornerRadius.medium)
            }
        }
        .padding()
    }
    
    // MARK: - 卡片列表
    private var cardListView: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.medium) {
                ForEach(creditCardService.creditCards) { card in
                    NavigationLink {
                        CreditCardTransactionsView(creditCard: card)
                    } label: {
                        CreditCardRow(card: card)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            selectedCard = card
                        } label: {
                            Label("编辑卡片", systemImage: "pencil")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 信用卡行视图 (拟物化 CFO 升级)
struct CreditCardRow: View {
    let card: CreditCard
    @ObservedObject var authService = AuthService.shared
    
    /// 是否为默认支出账户
    private var isDefaultCard: Bool {
        authService.isDefaultExpenseAccount(accountId: card.id, type: .creditCard)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 顶部：卡名和银行
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(card.institutionName)
                            .font(AppFont.body(size: 18, weight: .bold))
                        
                        // 默认支出标签
                        if isDefaultCard {
                            Text("默认")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.bambooGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(4)
                        }
                    }
                    Text(card.name)
                        .font(AppFont.body(size: 12))
                        .opacity(0.8)
                }
                
                Spacer()
                
                // 尾号胶囊
                Text("尾号 \(card.cardIdentifier)")
                    .font(AppFont.monoNumber(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }
            
            Spacer(minLength: 10)
            
            // 中间：还款信息
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本期应还")
                        .font(AppFont.body(size: 11, weight: .medium))
                        .opacity(0.7)
                    Text(formatCurrency(card.currentBalance, currency: card.currency))
                        .font(AppFont.monoNumber(size: 28, weight: .bold))
                }
                
                Spacer()
                
                // 还款日提醒
                if let dueDate = card.repaymentDueDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("还款日")
                            .font(AppFont.body(size: 10, weight: .medium))
                            .opacity(0.7)
                        Text("\(dueDate)号")
                            .font(AppFont.body(size: 18, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.1))
                    )
                }
            }
            
            // 底部：额度进度
            VStack(spacing: 8) {
                // 自定义进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: geo.size.width * min(card.usageRate, 1.0))
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("可用额度: \(formatCurrency(card.availableCredit, currency: card.currency))")
                    Spacer()
                    Text("已用 \(Int(card.usageRate * 100))%")
                }
                .font(AppFont.body(size: 10, weight: .medium))
                .opacity(0.8)
            }
        }
        .padding(24)
        .foregroundColor(.white)
        .background(
            ZStack {
                Theme.cardGradient(for: card.institutionName)
                
                // 装饰：卡片芯片感
                VStack {
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 30)
                            .padding(.top, 40)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.leading, 24)
            }
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
    }
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let symbol = currencySymbol(currency)
        return "\(symbol)\(formatter.string(from: NSNumber(value: amount)) ?? "0.00")"
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
    
    private func usageColor(_ rate: Double) -> Color {
        if rate < 0.3 { return .green }
        if rate < 0.7 { return .orange }
        return .red
    }
}

// MARK: - Preview
#Preview("信用卡管理 - CFO 风格") {
    let service = CreditCardService.shared
    service.creditCards = [
        CreditCard(
            id: "1",
            name: "个人生活卡",
            institutionName: "招商银行",
            cardIdentifier: "2323",
            creditLimit: 84000,
            currentBalance: 12500,
            repaymentDueDate: "10",
            currency: "CNY",
            createdAt: Date(),
            updatedAt: Date()
        ),
        CreditCard(
            id: "2",
            name: "商务差旅卡",
            institutionName: "工商银行",
            cardIdentifier: "8888",
            creditLimit: 150000,
            currentBalance: 45000,
            repaymentDueDate: "25",
            currency: "CNY",
            createdAt: Date(),
            updatedAt: Date()
        ),
        CreditCard(
            id: "3",
            name: "备用卡",
            institutionName: "汇丰银行",
            cardIdentifier: "4567",
            creditLimit: 50000,
            currentBalance: 500,
            repaymentDueDate: "05",
            currency: "CNY",
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
    
    return NavigationView {
        CreditCardListView()
    }
}
