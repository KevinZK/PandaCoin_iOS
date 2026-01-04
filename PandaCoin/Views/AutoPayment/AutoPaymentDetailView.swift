//
//  AutoPaymentDetailView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/25.
//

import SwiftUI
import Combine

struct AutoPaymentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let payment: AutoPayment

    @State private var logs: [AutoPaymentLog] = []
    @State private var isLoadingLogs = false
    @State private var showingEditSheet = false
    @State private var showingExecuteConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var isExecuting = false
    @State private var isToggling = false
    @State private var isDeleting = false
    @State private var currentIsEnabled: Bool
    @State private var executionResult: AutoPaymentExecutionResult?
    @State private var cancellables = Set<AnyCancellable>()

    init(payment: AutoPayment) {
        self.payment = payment
        self._currentIsEnabled = State(initialValue: payment.isEnabled)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 头部信息卡片
                headerCard
                
                // 详细信息
                detailsCard
                
                // 来源账户优先级
                sourcesCard
                
                // 还款进度（贷款类）
                if payment.totalPeriods != nil {
                    progressCard
                }
                
                // 执行日志
                logsCard
                
                // 手动执行按钮
                if currentIsEnabled {
                    manualExecuteButton
                }

                // 删除按钮
                deleteButton
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(payment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                EditAutoPaymentView(payment: payment)
            }
        }
        .alert("确认执行", isPresented: $showingExecuteConfirm) {
            Button("取消", role: .cancel) { }
            Button("执行") {
                executeNow()
            }
        } message: {
            Text("确定要立即执行此自动还款吗？将从您的账户扣款。")
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deletePayment()
            }
        } message: {
            Text("确定要删除「\(payment.name)」吗？此操作不可恢复。")
        }
        .alert("执行结果", isPresented: .constant(executionResult != nil)) {
            Button("确定") {
                executionResult = nil
            }
        } message: {
            if let result = executionResult {
                if result.success {
                    Text("扣款成功，金额: ¥\(String(format: "%.2f", result.amount ?? 0))")
                } else {
                    Text(result.message ?? "扣款失败")
                }
            }
        }
        .onAppear {
            loadLogs()
        }
    }
    
    // MARK: - 头部卡片
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            // 图标和名称
            HStack {
                Image(systemName: payment.paymentType.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(paymentTypeColor)
                    .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(payment.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.text)
                    
                    Text(payment.paymentType.displayName)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()

                // 状态开关
                VStack(alignment: .trailing) {
                    if isToggling {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Toggle("", isOn: $currentIsEnabled)
                            .labelsHidden()
                            .onChange(of: currentIsEnabled) { newValue in
                                if newValue != payment.isEnabled {
                                    toggleEnabled()
                                }
                            }
                    }

                    Text(currentIsEnabled ? "已启用" : "已禁用")
                        .font(.caption)
                        .foregroundColor(currentIsEnabled ? Theme.bambooGreen : Theme.textSecondary)
                }
            }
            
            Divider()
            
            // 金额和下次执行
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("扣款金额")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    if let amount = payment.formattedAmount {
                        Text(amount)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.text)
                    } else {
                        Text("按账单金额")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("下次执行")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(payment.formattedNextExecuteDate ?? "-")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.bambooGreen)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 详情卡片
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还款设置")
                .font(.headline)
                .foregroundColor(Theme.text)
            
            DetailRow(title: "还款日", value: "每月 \(payment.dayOfMonth) 号")
            DetailRow(title: "执行时间", value: payment.executeTime)
            DetailRow(title: "提前提醒", value: "\(payment.reminderDaysBefore) 天")
            DetailRow(title: "余额不足时", value: payment.insufficientFundsPolicy.displayName)
            
            if let card = payment.creditCard {
                Divider()
                DetailRow(title: "信用卡", value: "\(card.name) (\(card.cardIdentifier ?? ""))")
            }
            
            if let liability = payment.liabilityAccount {
                Divider()
                DetailRow(title: "贷款账户", value: liability.name)
                if let rate = liability.interestRate {
                    DetailRow(title: "年利率", value: "\(String(format: "%.2f", rate))%")
                }
                if let months = liability.loanTermMonths {
                    DetailRow(title: "贷款期限", value: "\(months)个月")
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - 来源账户卡片
    
    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("扣款账户优先级")
                    .font(.headline)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text("\(payment.sources.count) 个账户")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            if payment.sources.isEmpty {
                Text("未设置扣款账户")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(payment.sources) { source in
                    HStack(spacing: 12) {
                        Text("\(source.priority)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(priorityColor(source.priority))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.account.name)
                                .font(.subheadline)
                                .foregroundColor(Theme.text)
                            
                            Text("余额: ¥\(String(format: "%.2f", source.account.balance))")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if source.priority == 1 {
                            Text("优先")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.bambooGreen.opacity(0.2))
                                .foregroundColor(Theme.bambooGreen)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - 进度卡片
    
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还款进度")
                .font(.headline)
                .foregroundColor(Theme.text)
            
            VStack(spacing: 8) {
                HStack {
                    Text("已还期数")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(payment.completedPeriods) 期")
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                }
                
                if let total = payment.totalPeriods {
                    HStack {
                        Text("剩余期数")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(payment.remainingPeriods ?? (total - payment.completedPeriods)) 期")
                            .fontWeight(.medium)
                            .foregroundColor(Theme.text)
                    }
                    
                    ProgressView(value: payment.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.bambooGreen))
                        .padding(.top, 4)
                    
                    HStack {
                        Text("\(String(format: "%.1f", payment.progressPercentage * 100))%")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Spacer()
                        
                        if payment.progressPercentage >= 1 {
                            Label("已还清", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - 执行日志卡片
    
    private var logsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行记录")
                    .font(.headline)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                if isLoadingLogs {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if logs.isEmpty && !isLoadingLogs {
                Text("暂无执行记录")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(logs.prefix(5)) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.statusIcon)
                            .foregroundColor(statusColor(log.statusColor))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.statusDescription)
                                .font(.subheadline)
                                .foregroundColor(Theme.text)
                            
                            Text(formatDate(log.executedAt))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text("¥\(String(format: "%.2f", log.amount))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.text)
                    }
                    .padding(.vertical, 4)
                    
                    if log.id != logs.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - 手动执行按钮

    private var manualExecuteButton: some View {
        Button(action: { showingExecuteConfirm = true }) {
            HStack {
                if isExecuting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                }
                Text("立即执行")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.bambooGreen)
            .cornerRadius(12)
        }
        .disabled(isExecuting)
    }

    // MARK: - 删除按钮

    private var deleteButton: some View {
        Button(action: { showingDeleteConfirm = true }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.red)
                } else {
                    Image(systemName: "trash")
                }
                Text("删除自动还款")
            }
            .font(.headline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }
    
    // MARK: - 辅助方法
    
    private var paymentTypeColor: Color {
        switch payment.paymentType {
        case .creditCardFull, .creditCardMin: return .blue
        case .loan: return .orange
        case .mortgage: return .green
        case .subscription: return .purple
        }
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return Theme.bambooGreen
        case 2: return .blue
        case 3: return .green
        default: return .gray
        }
    }
    
    private func statusColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func loadLogs() {
        isLoadingLogs = true
        
        AutoPaymentService.shared.fetchLogs(paymentId: payment.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    isLoadingLogs = false
                },
                receiveValue: { logs in
                    self.logs = logs
                }
            )
            .store(in: &cancellables)
    }
    
    private func executeNow() {
        isExecuting = true

        AutoPaymentService.shared.executeAutoPayment(id: payment.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isExecuting = false
                    if case .failure(let error) = completion {
                        executionResult = AutoPaymentExecutionResult(
                            success: false,
                            amount: nil,
                            recordId: nil,
                            message: error.localizedDescription
                        )
                    }
                },
                receiveValue: { result in
                    executionResult = result
                    loadLogs() // 刷新日志
                }
            )
            .store(in: &cancellables)
    }

    private func toggleEnabled() {
        isToggling = true

        AutoPaymentService.shared.toggleAutoPayment(id: payment.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isToggling = false
                    if case .failure = completion {
                        // 恢复原状态
                        currentIsEnabled = payment.isEnabled
                    }
                },
                receiveValue: { updatedPayment in
                    currentIsEnabled = updatedPayment.isEnabled
                }
            )
            .store(in: &cancellables)
    }

    private func deletePayment() {
        isDeleting = true

        AutoPaymentService.shared.deleteAutoPayment(id: payment.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isDeleting = false
                    if case .finished = completion {
                        dismiss()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 详情行

private struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.text)
        }
        .font(.subheadline)
    }
}

// MARK: - 编辑页面

struct EditAutoPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    let payment: AutoPayment
    
    @StateObject private var assetService = AssetService.shared
    
    @State private var name: String = ""
    @State private var dayOfMonth: Int = 10
    @State private var reminderDaysBefore: Int = 2
    @State private var insufficientFundsPolicy: InsufficientFundsPolicy = .tryNextSource
    @State private var fixedAmount: String = ""
    @State private var completedPeriods: String = ""
    @State private var selectedSourceAccounts: [AddAutoPaymentView.SourceAccountSelection] = []
    @State private var showingSourceAccountPicker = false
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("还款名称", text: $name)
                
                Stepper("每月 \(dayOfMonth) 号", value: $dayOfMonth, in: 1...28)
                
                Stepper("提前 \(reminderDaysBefore) 天提醒", value: $reminderDaysBefore, in: 0...7)
            }
            
            Section(header: Text("还款金额")) {
                HStack {
                    Text("¥")
                    TextField("金额", text: $fixedAmount)
                        .keyboardType(.decimalPad)
                }
            }
            
            if payment.totalPeriods != nil {
                Section(header: Text("还款进度")) {
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
            
            Section(header: Text("扣款账户")) {
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
                        Text("添加账户")
                    }
                }
            }
            
            Section(header: Text("余额不足时")) {
                Picker("处理策略", selection: $insufficientFundsPolicy) {
                    ForEach(InsufficientFundsPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error).foregroundColor(.red)
                }
            }
        }
        .navigationTitle("编辑自动还款")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { dismiss() }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveChanges()
                }
                .disabled(isSubmitting)
            }
        }
        .sheet(isPresented: $showingSourceAccountPicker) {
            SourceAccountPickerSheet(
                selectedAccounts: $selectedSourceAccounts,
                availableAccounts: netAssetAccounts
            )
        }
        .onAppear {
            initializeFromPayment()
        }
    }
    
    private var netAssetAccounts: [Asset] {
        assetService.accounts.filter {
            [AssetType.bank, AssetType.cash, AssetType.digitalWallet, AssetType.savings].contains($0.type)
        }
    }
    
    private func initializeFromPayment() {
        name = payment.name
        dayOfMonth = payment.dayOfMonth
        reminderDaysBefore = payment.reminderDaysBefore
        insufficientFundsPolicy = payment.insufficientFundsPolicy
        
        if let amount = payment.fixedAmount {
            fixedAmount = String(format: "%.2f", amount)
        }
        
        completedPeriods = "\(payment.completedPeriods)"
        
        // 加载来源账户
        selectedSourceAccounts = payment.sources.map {
            AddAutoPaymentView.SourceAccountSelection(
                id: $0.account.id,
                name: $0.account.name,
                priority: $0.priority
            )
        }
        
        // 加载账户数据
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
    
    private func saveChanges() {
        isSubmitting = true
        errorMessage = nil
        
        let request = UpdateAutoPaymentRequest(
            name: name,
            paymentType: nil,
            creditCardId: nil,
            liabilityAccountId: nil,
            sourceAccounts: selectedSourceAccounts.map {
                SourceAccountRequest(accountId: $0.id, priority: $0.priority)
            },
            fixedAmount: Double(fixedAmount),
            dayOfMonth: dayOfMonth,
            executeTime: nil,
            reminderDaysBefore: reminderDaysBefore,
            insufficientFundsPolicy: insufficientFundsPolicy,
            totalPeriods: nil,
            completedPeriods: Int(completedPeriods),
            startDate: nil,
            isEnabled: nil
        )
        
        AutoPaymentService.shared.updateAutoPayment(id: payment.id, request: request)
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

#Preview {
    NavigationView {
        AutoPaymentDetailView(
            payment: AutoPayment(
                id: "1",
                name: "房贷还款",
                paymentType: .mortgage,
                creditCardId: nil,
                liabilityAccountId: "loan1",
                fixedAmount: 8500,
                dayOfMonth: 25,
                executeTime: "08:00",
                reminderDaysBefore: 2,
                insufficientFundsPolicy: .tryNextSource,
                isEnabled: true,
                lastExecutedAt: Date().addingTimeInterval(-86400 * 30),
                nextExecuteAt: Date().addingTimeInterval(86400 * 5),
                totalPeriods: 360,
                completedPeriods: 24,
                startDate: Date().addingTimeInterval(-86400 * 365 * 2),
                remainingPeriods: 336,
                createdAt: Date(),
                updatedAt: Date(),
                creditCard: nil,
                liabilityAccount: AutoPayment.LiabilityAccountInfo(
                    id: "loan1",
                    name: "房贷",
                    type: "MORTGAGE",
                    balance: -980000,
                    interestRate: 2.8,
                    loanTermMonths: 360,
                    monthlyPayment: 8500
                ),
                sources: [
                    SourceAccountConfig(
                        id: "s1",
                        accountId: "a1",
                        priority: 1,
                        account: SourceAccountConfig.AccountInfo(
                            id: "a1",
                            name: "工商银行储蓄",
                            type: "BANK",
                            balance: 50000
                        )
                    ),
                    SourceAccountConfig(
                        id: "s2",
                        accountId: "a2",
                        priority: 2,
                        account: SourceAccountConfig.AccountInfo(
                            id: "a2",
                            name: "招商银行储蓄",
                            type: "BANK",
                            balance: 30000
                        )
                    )
                ]
            )
        )
    }
}

