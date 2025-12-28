//
//  AutoIncomeDetailView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/28.
//

import SwiftUI
import Combine

struct AutoIncomeDetailView: View {
    let income: AutoIncome

    @Environment(\.dismiss) var dismiss
    @StateObject private var service = AutoIncomeService.shared

    @State private var currentIncome: AutoIncome
    @State private var logs: [AutoIncomeLog] = []
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var isExecuting = false
    @State private var executionMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    init(income: AutoIncome) {
        self.income = income
        _currentIncome = State(initialValue: income)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 头部卡片
                    headerCard

                    // 详情卡片
                    detailsCard

                    // 执行日志
                    logsCard

                    // 操作按钮
                    actionButtons
                }
                .padding()
            }
        }
        .navigationTitle("自动入账详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showEditSheet = true }) {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(action: { toggleEnabled() }) {
                        Label(currentIncome.isEnabled ? "禁用" : "启用",
                              systemImage: currentIncome.isEnabled ? "pause.circle" : "play.circle")
                    }
                    Divider()
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.bambooGreen)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddAutoIncomeView(editingIncome: currentIncome)
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteIncome() }
        } message: {
            Text("删除后将停止自动入账，此操作不可恢复")
        }
        .alert("执行结果", isPresented: .constant(executionMessage != nil)) {
            Button("确定") { executionMessage = nil }
        } message: {
            Text(executionMessage ?? "")
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - 头部卡片

    private var headerCard: some View {
        VStack(spacing: 16) {
            // 图标和名称
            HStack {
                Image(systemName: currentIncome.incomeType.icon)
                    .font(.system(size: 28))
                    .foregroundColor(Theme.income)
                    .frame(width: 50, height: 50)
                    .background(Theme.income.opacity(0.1))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentIncome.name)
                        .font(AppFont.body(size: 20, weight: .bold))
                        .foregroundColor(Theme.text)

                    Text(currentIncome.incomeType.displayName)
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // 状态
                Toggle("", isOn: Binding(
                    get: { currentIncome.isEnabled },
                    set: { _ in toggleEnabled() }
                ))
                .labelsHidden()
                .tint(Theme.bambooGreen)
            }

            Divider()

            // 金额
            HStack {
                Text("入账金额")
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(currentIncome.formattedAmount)
                    .font(AppFont.monoNumber(size: 24, weight: .bold))
                    .foregroundColor(Theme.income)
            }

            // 下次入账
            if let nextDate = currentIncome.formattedNextExecuteDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(Theme.textSecondary)
                    Text("下次入账")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(nextDate)
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.text)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - 详情卡片

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("入账设置")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 12) {
                detailRow(icon: "calendar", title: "入账日", value: currentIncome.dayDescription)
                Divider()
                detailRow(icon: "clock", title: "入账时间", value: currentIncome.executeTime)
                Divider()
                detailRow(icon: "building.columns", title: "入账账户", value: currentIncome.targetAccountDescription)
                Divider()
                detailRow(icon: "tag", title: "分类", value: currentIncome.category)
                Divider()
                detailRow(icon: "bell", title: "提前提醒", value: currentIncome.reminderDaysBefore > 0 ? "\(currentIncome.reminderDaysBefore)天前" : "不提醒")
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.bambooGreen)
                .frame(width: 24)
            Text(title)
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundColor(Theme.text)
        }
    }

    // MARK: - 执行日志

    private var logsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行记录")
                    .font(AppFont.body(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if !logs.isEmpty {
                    Text("最近\(logs.count)条")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                }
            }

            if logs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    Text("暂无执行记录")
                        .font(AppFont.body(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Theme.cardBackground)
                .cornerRadius(CornerRadius.medium)
            } else {
                VStack(spacing: 0) {
                    ForEach(logs) { log in
                        logRow(log)
                        if log.id != logs.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .background(Theme.cardBackground)
                .cornerRadius(CornerRadius.medium)
            }
        }
    }

    private func logRow(_ log: AutoIncomeLog) -> some View {
        HStack {
            Image(systemName: log.statusIcon)
                .foregroundColor(log.isSuccess ? .green : .orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.formattedDate)
                    .font(AppFont.body(size: 14))
                    .foregroundColor(Theme.text)
                if let message = log.message {
                    Text(message)
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("+¥\(String(format: "%.2f", log.amount))")
                .font(AppFont.monoNumber(size: 14, weight: .medium))
                .foregroundColor(log.isSuccess ? Theme.income : Theme.textSecondary)
        }
        .padding()
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        Button(action: { executeNow() }) {
            HStack {
                if isExecuting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "play.circle.fill")
                }
                Text("立即执行")
            }
            .font(AppFont.body(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.income)
            .cornerRadius(CornerRadius.medium)
        }
        .disabled(isExecuting || !currentIncome.isEnabled)
        .opacity(currentIncome.isEnabled ? 1 : 0.5)
    }

    // MARK: - 数据加载

    private func loadData() {
        // 加载最新数据
        service.fetchAutoIncome(id: income.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { income in
                    currentIncome = income
                }
            )
            .store(in: &cancellables)

        // 加载日志
        service.fetchLogs(incomeId: income.id, limit: 10)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { logs in
                    self.logs = logs
                }
            )
            .store(in: &cancellables)
    }

    private func toggleEnabled() {
        service.toggleAutoIncome(id: income.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { income in
                    currentIncome = income
                }
            )
            .store(in: &cancellables)
    }

    private func deleteIncome() {
        service.deleteAutoIncome(id: income.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    dismiss()
                }
            )
            .store(in: &cancellables)
    }

    private func executeNow() {
        isExecuting = true

        service.executeAutoIncome(id: income.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isExecuting = false
                    if case .failure(let error) = completion {
                        executionMessage = "执行失败: \(error.localizedDescription)"
                    }
                },
                receiveValue: { result in
                    executionMessage = result.message
                    loadData() // 刷新数据
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    NavigationView {
        AutoIncomeDetailView(income: AutoIncome(
            id: "1",
            name: "工资",
            incomeType: .salary,
            amount: 8000,
            targetAccountId: "acc1",
            category: "工资",
            dayOfMonth: 15,
            executeTime: "09:00",
            reminderDaysBefore: 1,
            isEnabled: true,
            lastExecutedAt: nil,
            nextExecuteAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            targetAccount: TargetAccountInfo(id: "acc1", name: "招商银行", type: "BANK", balance: 10000)
        ))
    }
}
