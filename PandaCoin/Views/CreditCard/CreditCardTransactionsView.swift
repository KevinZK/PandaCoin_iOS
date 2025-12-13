//
//  CreditCardTransactionsView.swift
//  PandaCoin
//
//  信用卡消费记录页面
//

import SwiftUI
import Combine

struct CreditCardTransactionsView: View {
    let creditCard: CreditCard
    
    @State private var selectedMonth: String = ""
    @State private var transactions: [CreditCardTransaction] = []
    @State private var summary: TransactionSummary?
    @State private var isLoading = false
    @State private var error: String?
    
    private let creditCardService = CreditCardService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 月份选择器
            monthPicker
            
            // 汇总卡片
            if let summary = summary {
                summaryCard(summary)
            }
            
            // 消费记录列表
            if isLoading {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else if transactions.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                transactionList
            }
        }
        .navigationTitle("消费记录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeMonth()
            loadTransactions()
        }
        .alert("错误", isPresented: .constant(error != nil)) {
            Button("确定") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }
    
    // MARK: - 月份选择器
    private var monthPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recentMonths, id: \.self) { month in
                    Button {
                        selectedMonth = month
                        loadTransactions()
                    } label: {
                        Text(formatMonthDisplay(month))
                            .font(.subheadline)
                            .fontWeight(selectedMonth == month ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedMonth == month ? Color.blue : Color.gray.opacity(0.1))
                            .foregroundColor(selectedMonth == month ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 汇总卡片
    private func summaryCard(_ summary: TransactionSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("本月消费")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("¥\(String(format: "%.2f", summary.totalExpense))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("本月还款")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("¥\(String(format: "%.2f", summary.totalPayment))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - 消费记录列表
    private var transactionList: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("暂无消费记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("本月还没有使用这张卡消费")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - 辅助方法
    private var recentMonths: [String] {
        let calendar = Calendar.current
        let now = Date()
        var months: [String] = []
        
        for i in 0..<12 {
            if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                months.append(formatter.string(from: date))
            }
        }
        
        return months
    }
    
    private func initializeMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        selectedMonth = formatter.string(from: Date())
    }
    
    private func formatMonthDisplay(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let monthNum = Int(parts[1]) else { return month }
        return "\(monthNum)月"
    }
    
    private func loadTransactions() {
        isLoading = true
        error = nil
        
        creditCardService.getTransactions(creditCardId: creditCard.id, month: selectedMonth)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    isLoading = false
                    switch completion {
                    case .failure(let err):
                        error = err.localizedDescription
                    case .finished:
                        break
                    }
                },
                receiveValue: { response in
                    transactions = response.transactions
                    summary = response.summary
                }
            )
            .store(in: &creditCardService.cancellables)
    }
}

// MARK: - 消费记录行
struct TransactionRow: View {
    let transaction: CreditCardTransaction
    
    var body: some View {
        HStack {
            // 分类图标
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(transaction.isExpense ? .red : .green)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(categoryName)
                    .font(.headline)
                if let description = transaction.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                    .foregroundColor(transaction.isExpense ? .red : .green)
                Text(formatDate(transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var categoryIcon: String {
        switch transaction.category.uppercased() {
        case "FOOD": return "fork.knife"
        case "TRANSPORT": return "car.fill"
        case "SHOPPING": return "bag.fill"
        case "ENTERTAINMENT": return "gamecontroller.fill"
        case "HOUSING": return "house.fill"
        default: return "creditcard.fill"
        }
    }
    
    private var categoryName: String {
        switch transaction.category.uppercased() {
        case "FOOD": return "餐饮"
        case "TRANSPORT": return "交通"
        case "SHOPPING": return "购物"
        case "ENTERTAINMENT": return "娱乐"
        case "HOUSING": return "住房"
        case "LOAN_REPAYMENT": return "还款"
        default: return transaction.category
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        CreditCardTransactionsView(
            creditCard: CreditCard(
                id: "1",
                name: "招商VISA卡",
                institutionName: "招商银行",
                cardIdentifier: "1234",
                creditLimit: 50000,
                currentBalance: 3500,
                repaymentDueDate: "10",
                currency: "CNY",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
