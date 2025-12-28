//
//  AddAutoIncomeView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/28.
//

import SwiftUI
import Combine

struct AddAutoIncomeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var accountService = AssetService.shared
    @StateObject private var incomeService = AutoIncomeService.shared

    // 表单状态
    @State private var name: String = ""
    @State private var incomeType: IncomeType = .salary
    @State private var amount: String = ""
    @State private var selectedAccountId: String = ""
    @State private var dayOfMonth: Int = 15
    @State private var executeTime: String = "09:00"
    @State private var reminderDaysBefore: Int = 1

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    // 编辑模式
    var editingIncome: AutoIncome?
    var isEditing: Bool { editingIncome != nil }

    // 预填充数据（从 ChatView 传入）
    var prefillName: String?
    var prefillAmount: Double?
    var prefillDay: Int?
    var prefillIncomeType: IncomeType?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 基本信息
                        basicInfoSection

                        // 入账金额
                        amountSection

                        // 入账账户
                        accountSection

                        // 入账日期
                        scheduleSection

                        // 提醒设置
                        reminderSection
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "编辑自动入账" : "添加自动入账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
                        saveIncome()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                loadAccounts()
                applyPrefillData()
                if isEditing, let income = editingIncome {
                    loadEditingData(income)
                }
            }
            .alert("错误", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 基本信息

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 16) {
                // 入账类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("入账类型")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(IncomeType.allCases, id: \.self) { type in
                                incomeTypeButton(type)
                            }
                        }
                    }
                }

                // 名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("名称")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)

                    TextField("例如：公司工资", text: $name)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(CornerRadius.small)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    private func incomeTypeButton(_ type: IncomeType) -> some View {
        Button(action: {
            incomeType = type
            if name.isEmpty {
                name = type.displayName
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                Text(type.displayName)
                    .font(AppFont.body(size: 12))
            }
            .frame(width: 70, height: 60)
            .foregroundColor(incomeType == type ? .white : Theme.text)
            .background(incomeType == type ? Theme.income : Theme.cardBackground)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(incomeType == type ? Theme.income : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 入账金额

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入账金额")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            HStack {
                Text("¥")
                    .font(AppFont.monoNumber(size: 24, weight: .bold))
                    .foregroundColor(Theme.income)

                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(AppFont.monoNumber(size: 24, weight: .bold))
                    .foregroundColor(Theme.income)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - 入账账户

    private var accountSection: some View {
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
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(account.name)
                                    .font(AppFont.body(size: 14))
                                    .foregroundColor(Theme.text)
                                Text("余额: \(account.formattedBalance)")
                                    .font(AppFont.body(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }

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
                        Divider().padding(.leading, 50)
                    }
                }

                if availableAccounts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("暂无可用账户")
                            .font(AppFont.body(size: 14))
                            .foregroundColor(Theme.textSecondary)
                        Text("请先添加储蓄账户")
                            .font(AppFont.body(size: 12))
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                    }
                    .padding()
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - 入账日期

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入账日期")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 16) {
                // 入账日
                HStack {
                    Text("每月")
                        .foregroundColor(Theme.text)

                    Picker("", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(Theme.bambooGreen)

                    Text("号")
                        .foregroundColor(Theme.text)

                    Spacer()
                }

                Divider()

                // 执行时间
                HStack {
                    Text("入账时间")
                        .foregroundColor(Theme.text)

                    Spacer()

                    Picker("", selection: $executeTime) {
                        Text("09:00").tag("09:00")
                        Text("10:00").tag("10:00")
                        Text("12:00").tag("12:00")
                        Text("18:00").tag("18:00")
                    }
                    .pickerStyle(.menu)
                    .accentColor(Theme.bambooGreen)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    // MARK: - 提醒设置

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提醒设置")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            HStack {
                Text("提前提醒")
                    .foregroundColor(Theme.text)

                Spacer()

                Picker("", selection: $reminderDaysBefore) {
                    Text("不提醒").tag(0)
                    Text("1天前").tag(1)
                    Text("2天前").tag(2)
                    Text("3天前").tag(3)
                }
                .pickerStyle(.menu)
                .accentColor(Theme.bambooGreen)
            }
            .padding()
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
        if let prefillName = prefillName {
            name = prefillName
        }
        if let prefillAmount = prefillAmount {
            amount = String(format: "%.2f", prefillAmount)
        }
        if let prefillDay = prefillDay {
            dayOfMonth = prefillDay
        }
        if let prefillIncomeType = prefillIncomeType {
            incomeType = prefillIncomeType
        }
    }

    private func loadEditingData(_ income: AutoIncome) {
        name = income.name
        incomeType = income.incomeType
        amount = String(format: "%.2f", income.amount)
        selectedAccountId = income.targetAccountId
        dayOfMonth = income.dayOfMonth
        executeTime = income.executeTime
        reminderDaysBefore = income.reminderDaysBefore
    }

    private func saveIncome() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "请输入有效金额"
            return
        }

        isLoading = true

        if isEditing, let income = editingIncome {
            // 更新
            let request = UpdateAutoIncomeRequest(
                name: name,
                incomeType: incomeType.rawValue,
                amount: amountValue,
                targetAccountId: selectedAccountId,
                category: incomeType.defaultCategory,
                dayOfMonth: dayOfMonth,
                executeTime: executeTime,
                reminderDaysBefore: reminderDaysBefore,
                isEnabled: nil
            )

            incomeService.updateAutoIncome(id: income.id, request: request)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
                        if case .failure(let error) = completion {
                            errorMessage = error.localizedDescription
                        }
                    },
                    receiveValue: { _ in
                        dismiss()
                    }
                )
                .store(in: &cancellables)
        } else {
            // 创建
            let request = CreateAutoIncomeRequest(
                name: name,
                incomeType: incomeType.rawValue,
                amount: amountValue,
                targetAccountId: selectedAccountId,
                category: incomeType.defaultCategory,
                dayOfMonth: dayOfMonth,
                executeTime: executeTime,
                reminderDaysBefore: reminderDaysBefore,
                isEnabled: true
            )

            incomeService.createAutoIncome(request)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
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
}

#Preview {
    AddAutoIncomeView()
}
