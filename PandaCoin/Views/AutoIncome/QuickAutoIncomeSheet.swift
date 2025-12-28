//
//  QuickAutoIncomeSheet.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/28.
//

import SwiftUI
import Combine

/// 快速设置自动入账 Sheet（从 ChatView 记录固定收入后弹出）
struct QuickAutoIncomeSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var accountService = AssetService.shared
    @StateObject private var incomeService = AutoIncomeService.shared

    // 预填充数据
    let prefillName: String
    let prefillAmount: Double
    let prefillDay: Int
    let prefillIncomeType: IncomeType

    // 表单状态
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var dayOfMonth: Int = 15
    @State private var selectedAccountId: String = ""
    @State private var isLoading = false
    @State private var cancellables = Set<AnyCancellable>()

    // 完成回调
    var onComplete: ((Bool) -> Void)?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 提示信息
                        tipCard

                        // 入账信息
                        incomeInfoCard

                        // 入账日期
                        dayPickerCard

                        // 入账账户
                        accountPickerCard
                    }
                    .padding()
                }
            }
            .navigationTitle("设置自动入账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后设置") {
                        onComplete?(false)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认添加") {
                        createAutoIncome()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                loadAccounts()
                applyPrefillData()
            }
        }
    }

    // MARK: - 提示卡片

    private var tipCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("检测到固定收入")
                    .font(AppFont.body(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Text("设置自动入账后，系统将在每月固定日期自动记录这笔收入")
                    .font(AppFont.body(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - 入账信息

    private var incomeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入账信息")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 16) {
                // 类型和名称
                HStack {
                    Image(systemName: prefillIncomeType.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Theme.income)
                        .frame(width: 36, height: 36)
                        .background(Theme.income.opacity(0.1))
                        .cornerRadius(8)

                    TextField("入账名称", text: $name)
                        .font(AppFont.body(size: 16))
                        .foregroundColor(Theme.text)
                }

                Divider()

                // 金额
                HStack {
                    Text("金额")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("¥")
                            .font(AppFont.monoNumber(size: 20, weight: .bold))
                            .foregroundColor(Theme.income)

                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(AppFont.monoNumber(size: 20, weight: .bold))
                            .foregroundColor(Theme.income)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - 入账日期

    private var dayPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入账日期")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            HStack {
                Text("每月")
                    .foregroundColor(Theme.text)

                Picker("", selection: $dayOfMonth) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day)号").tag(day)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(Theme.bambooGreen)

                Text("自动入账")
                    .foregroundColor(Theme.text)

                Spacer()
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - 入账账户

    private var accountPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入账账户")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 0) {
                ForEach(availableAccounts, id: \.id) { account in
                    Button(action: { selectedAccountId = account.id }) {
                        HStack {
                            Image(systemName: account.type.icon)
                                .foregroundColor(Theme.bambooGreen)
                                .frame(width: 24)

                            Text(account.name)
                                .font(AppFont.body(size: 14))
                                .foregroundColor(Theme.text)

                            Spacer()

                            if selectedAccountId == account.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.bambooGreen)
                            }
                        }
                        .padding()
                        .background(selectedAccountId == account.id ? Theme.bambooGreen.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if account.id != availableAccounts.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - 辅助方法

    private var availableAccounts: [Asset] {
        accountService.accounts.filter { account in
            switch account.type {
            case .bank, .cash, .digitalWallet, .savings:
                return true
            default:
                return false
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !amount.isEmpty &&
        (Double(amount) ?? 0) > 0 &&
        !selectedAccountId.isEmpty
    }

    private func loadAccounts() {
        accountService.fetchAccounts()
        // 延迟检查账户列表并选择默认账户
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if selectedAccountId.isEmpty, let first = availableAccounts.first {
                selectedAccountId = first.id
            }
        }
    }

    private func applyPrefillData() {
        name = prefillName
        amount = String(format: "%.2f", prefillAmount)
        dayOfMonth = prefillDay > 0 && prefillDay <= 28 ? prefillDay : 15
    }

    private func createAutoIncome() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }

        isLoading = true

        let request = CreateAutoIncomeRequest(
            name: name,
            incomeType: prefillIncomeType.rawValue,
            amount: amountValue,
            targetAccountId: selectedAccountId,
            category: prefillIncomeType.defaultCategory,
            dayOfMonth: dayOfMonth,
            executeTime: "09:00",
            reminderDaysBefore: 1,
            isEnabled: true
        )

        incomeService.createAutoIncome(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure = completion {
                        onComplete?(false)
                        dismiss()
                    }
                },
                receiveValue: { _ in
                    onComplete?(true)
                    dismiss()
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    QuickAutoIncomeSheet(
        prefillName: "工资",
        prefillAmount: 8000,
        prefillDay: 15,
        prefillIncomeType: .salary
    )
}
