//
//  AutoPaymentListView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/25.
//

import SwiftUI
import Combine

struct AutoPaymentListView: View {
    @StateObject private var service = AutoPaymentService.shared
    @State private var showingAddSheet = false
    @State private var selectedPayment: AutoPayment?
    @State private var showingDetail = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if service.isLoading && service.autoPayments.isEmpty {
                ProgressView("加载中...")
            } else if service.autoPayments.isEmpty {
                emptyStateView
            } else {
                paymentListView
            }
        }
        .navigationTitle("自动扣款")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.bambooGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddAutoPaymentView()
            }
            .onDisappear {
                refreshData()
            }
        }
        .sheet(item: $selectedPayment) { payment in
            NavigationView {
                AutoPaymentDetailView(payment: payment)
            }
            .onDisappear {
                refreshData()
            }
        }
        .onAppear {
            refreshData()
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            
            Text("暂无自动扣款")
                .font(.title2)
                .foregroundColor(Theme.text)
            
            Text("设置自动扣款，系统将在每月指定日期\n自动从您的账户扣款还贷")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加自动扣款")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.bambooGreen)
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - 列表视图
    
    private var paymentListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(service.autoPayments) { payment in
                    AutoPaymentCard(payment: payment) {
                        selectedPayment = payment
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deletePayment(payment)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            togglePayment(payment)
                        } label: {
                            Label(payment.isEnabled ? "禁用" : "启用",
                                  systemImage: payment.isEnabled ? "pause.circle" : "play.circle")
                        }
                        .tint(payment.isEnabled ? .orange : .green)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await refreshDataAsync()
        }
    }
    
    // MARK: - 刷新数据
    
    private func refreshData() {
        service.fetchAutoPayments()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func refreshDataAsync() async {
        await withCheckedContinuation { continuation in
            service.fetchAutoPayments()
                .sink(
                    receiveCompletion: { _ in continuation.resume() },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
    }
    
    private func deletePayment(_ payment: AutoPayment) {
        service.deleteAutoPayment(id: payment.id)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func togglePayment(_ payment: AutoPayment) {
        service.toggleAutoPayment(id: payment.id)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}

// MARK: - 自动扣款卡片

struct AutoPaymentCard: View {
    let payment: AutoPayment
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 头部：图标、名称、状态
                HStack {
                    // 类型图标
                    Image(systemName: payment.paymentType.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(paymentTypeColor)
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.name)
                            .font(.headline)
                            .foregroundColor(Theme.text)
                        
                        Text(payment.paymentType.displayName)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // 状态指示
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(payment.isEnabled ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(payment.isEnabled ? "已启用" : "已禁用")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        if let nextDate = payment.formattedNextExecuteDate {
                            Text("下次: \(nextDate)")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                
                Divider()
                
                // 金额和来源账户
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("扣款金额")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        if let amount = payment.formattedAmount {
                            Text(amount)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.text)
                        } else {
                            Text("按账单金额")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("扣款账户")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(payment.sourcesDescription)
                            .font(.subheadline)
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                    }
                }
                
                // 进度条（贷款类）
                if let total = payment.totalPeriods, total > 0 {
                    VStack(spacing: 6) {
                        HStack {
                            Text("还款进度")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            Spacer()
                            
                            Text(payment.progressDescription ?? "")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        ProgressView(value: payment.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: Theme.bambooGreen))
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var paymentTypeColor: Color {
        switch payment.paymentType {
        case .creditCardFull, .creditCardMin:
            return .blue
        case .loan:
            return .orange
        case .mortgage:
            return .green
        case .subscription:
            return .purple
        }
    }
}

#Preview {
    NavigationView {
        AutoPaymentListView()
    }
}

