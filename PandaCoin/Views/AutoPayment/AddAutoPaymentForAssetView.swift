//
//  AddAutoPaymentForAssetView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/25.
//

import SwiftUI
import Combine

/// 从资产详情页快速设置自动还款的简化视图
struct AddAutoPaymentForAssetView: View {
    @Environment(\.dismiss) private var dismiss
    let asset: Asset
    
    @StateObject private var assetService = AssetService.shared
    
    // 基本设置
    @State private var dayOfMonth: Int = 10
    @State private var reminderDaysBefore = 2
    @State private var insufficientFundsPolicy: InsufficientFundsPolicy = .tryNextSource
    
    // 月供金额（如果资产没有设置，则需要手动输入）
    @State private var monthlyPayment: String = ""
    
    // 贷款进度
    @State private var totalPeriods: String = ""
    @State private var completedPeriods: String = "0"
    
    // 来源账户
    @State private var selectedSourceAccounts: [AddAutoPaymentView.SourceAccountSelection] = []
    @State private var showingSourceAccountPicker = false
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Form {
            // 贷款信息展示
            Section(header: Text("贷款信息")) {
                HStack {
                    Text("贷款名称")
                    Spacer()
                    Text(asset.name)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack {
                    Text("贷款余额")
                    Spacer()
                    Text("¥\(String(format: "%.2f", abs(NSDecimalNumber(decimal: asset.balance).doubleValue)))")
                        .foregroundColor(Theme.expense)
                }
                
                if let rate = asset.interestRate {
                    HStack {
                        Text("年利率")
                        Spacer()
                        Text("\(String(format: "%.2f", rate))%")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            // 还款设置
            Section(header: Text("还款设置")) {
                HStack {
                    Text("月供金额")
                    Spacer()
                    HStack {
                        Text("¥")
                        TextField("请输入", text: $monthlyPayment)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Stepper("每月 \(dayOfMonth) 号还款", value: $dayOfMonth, in: 1...28)
                
                Stepper("提前 \(reminderDaysBefore) 天提醒", value: $reminderDaysBefore, in: 0...7)
            }
            
            // 还款进度
            Section(header: Text("还款进度")) {
                HStack {
                    Text("总期数")
                    Spacer()
                    TextField("期", text: $totalPeriods)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("期")
                }
                
                HStack {
                    Text("已还期数")
                    Spacer()
                    TextField("期", text: $completedPeriods)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("期")
                }
                
                if let total = Int(totalPeriods), let completed = Int(completedPeriods), total > 0 {
                    let remaining = total - completed
                    let percentage = Double(completed) / Double(total) * 100
                    
                    VStack(spacing: 8) {
                        ProgressView(value: Double(completed), total: Double(total))
                            .progressViewStyle(LinearProgressViewStyle(tint: Theme.bambooGreen))
                        
                        HStack {
                            Text("已还 \(String(format: "%.1f", percentage))%")
                            Spacer()
                            Text("剩余 \(remaining) 期")
                        }
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            // 扣款账户
            Section(header: Text("扣款账户（按优先级）")) {
                if selectedSourceAccounts.isEmpty {
                    Button(action: { showingSourceAccountPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("添加扣款账户")
                        }
                    }
                    
                    Text("设置扣款账户后，系统将在还款日自动从账户扣款")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                } else {
                    ForEach(selectedSourceAccounts) { account in
                        HStack {
                            Text("\(account.priority)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(account.priority == 1 ? Theme.bambooGreen : Color.blue)
                                .cornerRadius(12)
                            
                            Text(account.name)
                            
                            Spacer()
                            
                            Button(action: { removeSourceAccount(account) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        selectedSourceAccounts.move(fromOffsets: indices, toOffset: newOffset)
                        updatePriorities()
                    }
                    
                    Button(action: { showingSourceAccountPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("添加更多账户")
                        }
                    }
                    
                    Text("如果第一个账户余额不足，将自动尝试下一个")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 余额不足处理
            Section(header: Text("余额不足时")) {
                Picker("处理策略", selection: $insufficientFundsPolicy) {
                    ForEach(InsufficientFundsPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                
                Text(insufficientFundsPolicy.description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 错误提示
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("设置自动还款")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { dismiss() }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveAutoPayment()
                }
                .disabled(!isValid || isSubmitting)
            }
        }
        .sheet(isPresented: $showingSourceAccountPicker) {
            SourceAccountPickerSheet(
                selectedAccounts: $selectedSourceAccounts,
                availableAccounts: netAssetAccounts
            )
        }
        .onAppear {
            initializeFromAsset()
        }
    }
    
    // MARK: - 计算属性
    
    private var netAssetAccounts: [Asset] {
        assetService.accounts.filter {
            [AssetType.bank, AssetType.cash, AssetType.digitalWallet, AssetType.savings].contains($0.type)
        }
    }
    
    private var isValid: Bool {
        guard let payment = Double(monthlyPayment), payment > 0 else { return false }
        return true
    }
    
    private var paymentType: PaymentType {
        asset.type == .mortgage ? .mortgage : .loan
    }
    
    // MARK: - 方法
    
    private func initializeFromAsset() {
        // 从资产中获取已设置的值
        if let payment = asset.monthlyPayment {
            monthlyPayment = String(format: "%.2f", payment)
        }
        
        if let day = asset.repaymentDay {
            dayOfMonth = day
        }
        
        if let months = asset.loanTermMonths {
            totalPeriods = "\(months)"
        }
        
        // 加载账户列表
        assetService.fetchAccounts()
    }
    
    private func removeSourceAccount(_ account: AddAutoPaymentView.SourceAccountSelection) {
        selectedSourceAccounts.removeAll { $0.id == account.id }
        updatePriorities()
    }
    
    private func updatePriorities() {
        for (index, _) in selectedSourceAccounts.enumerated() {
            selectedSourceAccounts[index].priority = index + 1
        }
    }
    
    private func saveAutoPayment() {
        isSubmitting = true
        errorMessage = nil
        
        let request = CreateAutoPaymentRequest(
            name: "\(asset.name)还款",
            paymentType: paymentType,
            creditCardId: nil,
            liabilityAccountId: asset.id,
            sourceAccounts: selectedSourceAccounts.map {
                SourceAccountRequest(accountId: $0.id, priority: $0.priority)
            },
            fixedAmount: Double(monthlyPayment),
            dayOfMonth: dayOfMonth,
            executeTime: "08:00",
            reminderDaysBefore: reminderDaysBefore,
            insufficientFundsPolicy: insufficientFundsPolicy,
            totalPeriods: Int(totalPeriods),
            completedPeriods: Int(completedPeriods),
            startDate: nil,
            isEnabled: true
        )
        
        AutoPaymentService.shared.createAutoPayment(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSubmitting = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    dismiss()
                }
            )
            .store(in: &cancellables)
    }
}

// Preview 需要 Asset mock 数据
// #Preview {
//     NavigationView {
//         AddAutoPaymentForAssetView(asset: /* mock Asset */)
//     }
// }

