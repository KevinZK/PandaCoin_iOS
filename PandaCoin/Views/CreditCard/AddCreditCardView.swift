//
//  AddCreditCardView.swift
//  PandaCoin
//
//  添加信用卡视图
//

import SwiftUI
import Combine

struct AddCreditCardView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var creditCardService = CreditCardService.shared
    
    @State private var name = ""
    @State private var institutionName = ""
    @State private var cardIdentifier = ""
    @State private var creditLimit = ""
    @State private var repaymentDueDate = ""
    @State private var currency = "CNY"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private var isFormValid: Bool {
        !name.isEmpty && !institutionName.isEmpty && !cardIdentifier.isEmpty && !creditLimit.isEmpty
    }
    
    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("卡片名称", text: $name)
                    .placeholder(when: name.isEmpty) {
                        Text("如：招商VISA卡").foregroundColor(.gray.opacity(0.5))
                    }
                
                TextField("发卡银行", text: $institutionName)
                    .placeholder(when: institutionName.isEmpty) {
                        Text("如：招商银行").foregroundColor(.gray.opacity(0.5))
                    }
                
                TextField("卡片标识（尾号）", text: $cardIdentifier)
                    .keyboardType(.numberPad)
                    .placeholder(when: cardIdentifier.isEmpty) {
                        Text("如：1234").foregroundColor(.gray.opacity(0.5))
                    }
            }
            
            Section(header: Text("额度信息")) {
                HStack {
                    Text(currencySymbol)
                        .foregroundColor(Theme.textSecondary)
                    TextField("信用额度", text: $creditLimit)
                        .keyboardType(.decimalPad)
                }
                
                Picker("币种", selection: $currency) {
                    Text("人民币 (CNY)").tag("CNY")
                    Text("美元 (USD)").tag("USD")
                    Text("港币 (HKD)").tag("HKD")
                    Text("欧元 (EUR)").tag("EUR")
                }
            }
            
            Section(header: Text("还款信息")) {
                TextField("还款日（每月几号）", text: $repaymentDueDate)
                    .keyboardType(.numberPad)
                    .placeholder(when: repaymentDueDate.isEmpty) {
                        Text("如：15").foregroundColor(.gray.opacity(0.5))
                    }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(AppFont.body(size: 14))
                }
            }
        }
        .navigationTitle("添加信用卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveCard()
                }
                .disabled(!isFormValid || isSubmitting)
            }
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
    
    private var currencySymbol: String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "HKD": return "HK$"
        default: return "¥"
        }
    }
    
    private func saveCard() {
        guard let limit = Double(creditLimit) else {
            errorMessage = "请输入有效的额度金额"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        creditCardService.createCreditCard(
            name: name,
            institutionName: institutionName,
            cardIdentifier: cardIdentifier,
            creditLimit: limit,
            repaymentDueDate: repaymentDueDate.isEmpty ? nil : repaymentDueDate,
            currency: currency
        )
        .receive(on: DispatchQueue.main)
        .sink { completion in
            isSubmitting = false
            if case .failure(let error) = completion {
                errorMessage = "保存失败：\(error.localizedDescription)"
            }
        } receiveValue: { _ in
            dismiss()
        }
        .store(in: &creditCardService.cancellables)
    }
}

// MARK: - 编辑信用卡视图
struct EditCreditCardView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var creditCardService = CreditCardService.shared
    @ObservedObject private var authService = AuthService.shared
    
    let card: CreditCard
    
    @State private var name: String
    @State private var institutionName: String
    @State private var cardIdentifier: String
    @State private var creditLimit: String
    @State private var currentBalance: String
    @State private var repaymentDueDate: String
    @State private var currency: String
    @State private var isSubmitting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var shouldBeDefault: Bool  // 本地状态，保存时才提交
    
    init(card: CreditCard) {
        self.card = card
        _name = State(initialValue: card.name)
        _institutionName = State(initialValue: card.institutionName)
        _cardIdentifier = State(initialValue: card.cardIdentifier)
        _creditLimit = State(initialValue: String(format: "%.2f", card.creditLimit))
        _currentBalance = State(initialValue: String(format: "%.2f", card.currentBalance))
        _repaymentDueDate = State(initialValue: card.repaymentDueDate ?? "")
        _currency = State(initialValue: card.currency)
        // 初始化时从当前默认状态设置
        _shouldBeDefault = State(initialValue: AuthService.shared.isDefaultExpenseAccount(accountId: card.id, type: .creditCard))
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !institutionName.isEmpty && !cardIdentifier.isEmpty && !creditLimit.isEmpty
    }
    
    private var isCurrentlyDefault: Bool {
        authService.isDefaultExpenseAccount(accountId: card.id, type: .creditCard)
    }
    
    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("卡片名称", text: $name)
                TextField("发卡银行", text: $institutionName)
                TextField("卡片标识（尾号）", text: $cardIdentifier)
                    .keyboardType(.numberPad)
            }
            
            Section(header: Text("额度信息")) {
                HStack {
                    Text(currencySymbol)
                        .foregroundColor(Theme.textSecondary)
                    TextField("信用额度", text: $creditLimit)
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    Text(currencySymbol)
                        .foregroundColor(Theme.textSecondary)
                    TextField("当前待还", text: $currentBalance)
                        .keyboardType(.decimalPad)
                }
                
                Picker("币种", selection: $currency) {
                    Text("人民币 (CNY)").tag("CNY")
                    Text("美元 (USD)").tag("USD")
                    Text("港币 (HKD)").tag("HKD")
                    Text("欧元 (EUR)").tag("EUR")
                }
            }
            
            Section(header: Text("还款信息")) {
                TextField("还款日（每月几号）", text: $repaymentDueDate)
                    .keyboardType(.numberPad)
            }
            
            // 默认支出账户设置
            Section {
                Button(action: { shouldBeDefault.toggle() }) {
                    HStack {
                        Image(systemName: shouldBeDefault ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(shouldBeDefault ? Theme.bambooGreen : Theme.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("设为默认支出账户")
                                .foregroundColor(Theme.text)
                            
                            if shouldBeDefault {
                                Text("消费时将自动使用此信用卡")
                                    .font(.caption)
                                    .foregroundColor(Theme.bambooGreen)
                            } else {
                                Text("未设置默认账户时需手动选择")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        if shouldBeDefault {
                            Text(isCurrentlyDefault ? "默认" : "待保存")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isCurrentlyDefault ? Theme.bambooGreen : Theme.warning)
                                .cornerRadius(8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("删除此信用卡")
                        Spacer()
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(AppFont.body(size: 14))
                }
            }
        }
        .navigationTitle("编辑信用卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveCard()
                }
                .disabled(!isFormValid || isSubmitting)
            }
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteCard()
            }
        } message: {
            Text("确定要删除「\(card.name)」吗？此操作不可撤销。")
        }
    }
    
    private var currencySymbol: String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "HKD": return "HK$"
        default: return "¥"
        }
    }
    
    private func saveCard() {
        guard let limit = Double(creditLimit),
              let balance = Double(currentBalance) else {
            errorMessage = "请输入有效的金额"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        // 同时处理信用卡更新和默认账户设置
        creditCardService.updateCreditCard(
            id: card.id,
            name: name,
            institutionName: institutionName,
            cardIdentifier: cardIdentifier,
            creditLimit: limit,
            currentBalance: balance,
            repaymentDueDate: repaymentDueDate.isEmpty ? nil : repaymentDueDate,
            currency: currency
        )
        .receive(on: DispatchQueue.main)
        .flatMap { [self] _ -> AnyPublisher<Void, APIError> in
            // 处理默认账户的更改
            if shouldBeDefault && !isCurrentlyDefault {
                // 需要设为默认
                return authService.setDefaultExpenseAccount(accountId: card.id, accountType: .creditCard)
                    .map { _ in () }
                    .eraseToAnyPublisher()
            } else if !shouldBeDefault && isCurrentlyDefault {
                // 需要取消默认
                return authService.clearDefaultExpenseAccount()
                    .map { _ in () }
                    .eraseToAnyPublisher()
            } else {
                // 无需更改
                return Just(()).setFailureType(to: APIError.self).eraseToAnyPublisher()
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { completion in
            isSubmitting = false
            if case .failure(let error) = completion {
                errorMessage = "保存失败：\(error.localizedDescription)"
            }
        } receiveValue: { _ in
            dismiss()
        }
        .store(in: &creditCardService.cancellables)
    }
    
    private func deleteCard() {
        isSubmitting = true
        
        creditCardService.deleteCreditCard(id: card.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isSubmitting = false
                if case .failure(let error) = completion {
                    errorMessage = "删除失败：\(error.localizedDescription)"
                }
            } receiveValue: { _ in
                dismiss()
            }
            .store(in: &creditCardService.cancellables)
    }
}

// MARK: - Placeholder 扩展
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview
#Preview("添加信用卡") {
    NavigationView {
        AddCreditCardView()
    }
}

#Preview("编辑信用卡") {
    NavigationView {
        EditCreditCardView(card: CreditCard(
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
    }
}
