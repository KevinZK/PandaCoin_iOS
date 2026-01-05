//
//  AddAutoPaymentView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/25.
//

import SwiftUI
import Combine

struct AddAutoPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var assetService = AssetService.shared
    @StateObject private var creditCardService = CreditCardService.shared
    
    // 基本信息
    @State private var name = ""
    @State private var paymentType: PaymentType = .loan
    @State private var dayOfMonth = 10
    @State private var executeTime = "08:00"
    
    // 目标选择
    @State private var selectedCreditCardId: String?
    @State private var selectedLiabilityAccountId: String?
    
    // 金额
    @State private var useFixedAmount = true
    @State private var fixedAmount = ""
    
    // 来源账户（多选+优先级）
    @State private var selectedSourceAccounts: [SourceAccountSelection] = []
    @State private var showingSourceAccountPicker = false
    
    // 贷款信息
    @State private var loanPrincipal = ""
    @State private var annualRate = ""
    @State private var loanTermMonths = ""
    @State private var completedPeriods = "0"
    
    // 策略
    @State private var insufficientFundsPolicy: InsufficientFundsPolicy = .tryNextSource
    @State private var reminderDaysBefore = 2
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    struct SourceAccountSelection: Identifiable, Equatable {
        let id: String
        let name: String
        var priority: Int
    }
    
    var body: some View {
        Form {
            // 基本信息
            Section(header: Text("基本信息")) {
                TextField("还款名称", text: $name)
                    .textContentType(.name)
                
                Picker("还款类型", selection: $paymentType) {
                    ForEach(PaymentType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                
                Stepper("每月 \(dayOfMonth) 号", value: $dayOfMonth, in: 1...28)
                
                Stepper("提前 \(reminderDaysBefore) 天提醒", value: $reminderDaysBefore, in: 0...7)
            }
            
            // 目标选择
            Section(header: Text("还款目标")) {
                if paymentType == .creditCardFull || paymentType == .creditCardMin {
                    Picker("选择信用卡", selection: $selectedCreditCardId) {
                        Text("请选择").tag(nil as String?)
                        ForEach(creditCardService.creditCards) { card in
                            Text("\(card.name) (\(card.cardIdentifier ?? ""))")
                                .tag(card.id as String?)
                        }
                    }
                } else {
                    Picker("选择贷款账户", selection: $selectedLiabilityAccountId) {
                        Text("请选择").tag(nil as String?)
                        ForEach(loanAccounts) { account in
                            Text(account.name)
                                .tag(account.id as String?)
                        }
                    }
                }
            }
            
            // 金额设置
            Section(header: Text("还款金额")) {
                if paymentType == .creditCardFull || paymentType == .creditCardMin {
                    Toggle("使用固定金额", isOn: $useFixedAmount)
                    
                    if useFixedAmount {
                        HStack {
                            Text("¥")
                            TextField("金额", text: $fixedAmount)
                                .keyboardType(.decimalPad)
                        }
                    } else {
                        Text(paymentType == .creditCardFull ? "将自动获取当期账单全额" : "将自动计算最低还款额")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    // 贷款类需要设置月供
                    HStack {
                        Text("¥")
                        TextField("月供金额", text: $fixedAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    // 月供计算器
                    DisclosureGroup("月供计算器") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("贷款本金")
                                Spacer()
                                TextField("¥", text: $loanPrincipal)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 120)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            HStack {
                                Text("年利率 (%)")
                                Spacer()
                                TextField("%", text: $annualRate)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 120)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            HStack {
                                Text("贷款期限 (月)")
                                Spacer()
                                TextField("月", text: $loanTermMonths)
                                    .keyboardType(.numberPad)
                                    .frame(width: 120)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            if let calculation = calculateMonthlyPayment() {
                                Divider()
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("月供")
                                        Spacer()
                                        Text("¥\(String(format: "%.2f", calculation.monthlyPayment))")
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("总还款额")
                                        Spacer()
                                        Text("¥\(String(format: "%.2f", calculation.totalPayment))")
                                    }
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    
                                    HStack {
                                        Text("总利息")
                                        Spacer()
                                        Text("¥\(String(format: "%.2f", calculation.totalInterest))")
                                    }
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                }
                                
                                Button("应用此月供") {
                                    fixedAmount = String(format: "%.2f", calculation.monthlyPayment)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            // 贷款进度
            if paymentType == .loan || paymentType == .mortgage {
                Section(header: Text("还款进度")) {
                    HStack {
                        Text("总期数")
                        Spacer()
                        TextField("期", text: $loanTermMonths)
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
                }
            }
            
            // 扣款账户（多选）
            Section(header: Text("扣款账户")) {
                if selectedSourceAccounts.isEmpty {
                    Button(action: { showingSourceAccountPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("添加扣款账户")
                        }
                    }
                } else {
                    ForEach(selectedSourceAccounts) { account in
                        HStack {
                            Text("\(account.priority)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.bambooGreen)
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
                }
                
                Text("拖动调整优先级，系统将按顺序尝试扣款")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 策略设置
            Section(header: Text("余额不足时")) {
                Picker("处理策略", selection: $insufficientFundsPolicy) {
                    ForEach(InsufficientFundsPolicy.allCases, id: \.self) { policy in
                        VStack(alignment: .leading) {
                            Text(policy.displayName)
                        }
                        .tag(policy)
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
        .navigationTitle("添加自动扣款")
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
            loadData()
        }
    }
    
    // MARK: - 计算属性
    
    private var loanAccounts: [Asset] {
        assetService.accounts.filter { $0.type == .loan || $0.type == .mortgage }
    }
    
    private var netAssetAccounts: [Asset] {
        assetService.accounts.filter {
            [AssetType.bank, AssetType.cash, AssetType.digitalWallet, AssetType.savings].contains($0.type)
        }
    }
    
    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        
        if paymentType == .creditCardFull || paymentType == .creditCardMin {
            guard selectedCreditCardId != nil else { return false }
        } else {
            // 贷款类需要金额
            if useFixedAmount {
                guard let amount = Double(fixedAmount), amount > 0 else { return false }
            }
        }
        
        return true
    }
    
    // MARK: - 方法
    
    private func loadData() {
        // 加载账户数据
        assetService.fetchAccounts()
        creditCardService.fetchCreditCards()
    }
    
    private func calculateMonthlyPayment() -> MonthlyPaymentCalculation? {
        guard let principal = Double(loanPrincipal), principal > 0,
              let rate = Double(annualRate),
              let months = Int(loanTermMonths), months > 0 else {
            return nil
        }
        
        return AutoPaymentService.calculateMonthlyPaymentLocally(
            principal: principal,
            annualRate: rate,
            termMonths: months
        )
    }
    
    private func removeSourceAccount(_ account: SourceAccountSelection) {
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
            name: name,
            paymentType: paymentType,
            creditCardId: (paymentType == .creditCardFull || paymentType == .creditCardMin) ? selectedCreditCardId : nil,
            liabilityAccountId: (paymentType == .loan || paymentType == .mortgage) ? selectedLiabilityAccountId : nil,
            sourceAccounts: selectedSourceAccounts.map {
                SourceAccountRequest(accountId: $0.id, priority: $0.priority)
            },
            fixedAmount: useFixedAmount ? Double(fixedAmount) : nil,
            dayOfMonth: dayOfMonth,
            executeTime: executeTime,
            reminderDaysBefore: reminderDaysBefore,
            insufficientFundsPolicy: insufficientFundsPolicy,
            totalPeriods: Int(loanTermMonths),
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

// MARK: - 来源账户选择器

struct SourceAccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccounts: [AddAutoPaymentView.SourceAccountSelection]
    let availableAccounts: [Asset]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableAccounts) { account in
                    let isSelected = selectedAccounts.contains { $0.id == account.id }
                    
                    Button(action: { toggleAccount(account) }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(account.name)
                                    .foregroundColor(Theme.text)
                                Text("余额: ¥\(String(format: "%.2f", NSDecimalNumber(decimal: account.balance).doubleValue))")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.bambooGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择扣款账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private func toggleAccount(_ account: Asset) {
        if let index = selectedAccounts.firstIndex(where: { $0.id == account.id }) {
            selectedAccounts.remove(at: index)
        } else {
            let newPriority = selectedAccounts.count + 1
            selectedAccounts.append(
                AddAutoPaymentView.SourceAccountSelection(
                    id: account.id,
                    name: account.name,
                    priority: newPriority
                )
            )
        }
    }
}

#Preview {
    NavigationView {
        AddAutoPaymentView()
    }
}

