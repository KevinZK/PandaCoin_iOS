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
                    CreditCardRow(card: card)
                        .onTapGesture {
                            selectedCard = card
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - 信用卡行视图
struct CreditCardRow: View {
    let card: CreditCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 顶部：卡名和银行
            HStack {
                HStack(spacing: 8) {
                    Text("💳")
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .font(AppFont.body(size: 16, weight: .semibold))
                            .foregroundColor(Theme.text)
                        
                        HStack(spacing: 8) {
                            Text(card.institutionName)
                                .font(AppFont.body(size: 12))
                                .foregroundColor(Theme.textSecondary)
                            
                            if !card.cardIdentifier.isEmpty {
                                Text("尾号 \(card.cardIdentifier)")
                                    .font(AppFont.body(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 还款日
                if let dueDate = card.formattedDueDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("还款日")
                            .font(AppFont.body(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Text(dueDate)
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundColor(Theme.expense)
                    }
                }
            }
            
            Divider()
            
            // 底部：额度信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("待还金额")
                        .font(AppFont.body(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Text(formatCurrency(card.currentBalance, currency: card.currency))
                        .font(AppFont.monoNumber(size: 18, weight: .bold))
                        .foregroundColor(Theme.expense)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("可用额度")
                        .font(AppFont.body(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Text(formatCurrency(card.availableCredit, currency: card.currency))
                        .font(AppFont.monoNumber(size: 16, weight: .medium))
                        .foregroundColor(Theme.income)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("总额度")
                        .font(AppFont.body(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Text(formatCurrency(card.creditLimit, currency: card.currency))
                        .font(AppFont.monoNumber(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            // 使用率进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(usageColor(card.usageRate))
                        .frame(width: geometry.size.width * min(card.usageRate, 1.0), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("使用率 \(Int(card.usageRate * 100))%")
                    .font(AppFont.body(size: 10))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
        }
        .padding(Spacing.medium)
        .background(Color.white)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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
#Preview("信用卡列表 - 有数据") {
    NavigationView {
        CreditCardListView()
    }
}

#Preview("信用卡行") {
    CreditCardRow(card: CreditCard(
        id: "1",
        name: "招商信用卡",
        institutionName: "招商银行",
        cardIdentifier: "1234",
        creditLimit: 50000,
        currentBalance: 8500,
        repaymentDueDate: "15",
        currency: "CNY",
        createdAt: Date(),
        updatedAt: Date()
    ))
    .padding()
    .background(Theme.background)
}
