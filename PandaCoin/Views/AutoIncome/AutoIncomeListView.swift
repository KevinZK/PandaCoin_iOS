//
//  AutoIncomeListView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/28.
//

import SwiftUI
import Combine

struct AutoIncomeListView: View {
    @StateObject private var service = AutoIncomeService.shared
    @State private var showAddSheet = false
    @State private var selectedIncomeForEdit: AutoIncome?
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if service.isLoading && service.autoIncomes.isEmpty {
                ProgressView("加载中...")
            } else if service.autoIncomes.isEmpty {
                emptyStateView
            } else {
                incomeListView
            }
        }
        .navigationTitle("自动入账")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.bambooGreen)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAutoIncomeView()
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary.opacity(0.5))

            Text("暂无自动入账")
                .font(AppFont.body(size: 18, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text("添加固定收入，系统将自动记录")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary.opacity(0.7))

            Button(action: { showAddSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加自动入账")
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

    // MARK: - 入账列表

    private var incomeListView: some View {
        List {
            ForEach(service.autoIncomes) { income in
                ZStack {
                    // 隐藏的 NavigationLink（无箭头）
                    NavigationLink(destination: AutoIncomeDetailView(income: income)) {
                        EmptyView()
                    }
                    .opacity(0)

                    // 可见的卡片内容
                    AutoIncomeCard(income: income)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        selectedIncomeForEdit = income
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(Theme.bambooGreen)

                    Button(role: .destructive) {
                        deleteIncome(income)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Theme.background)
        .refreshable {
            await refreshData()
        }
        .sheet(item: $selectedIncomeForEdit) { income in
            NavigationView {
                AutoIncomeDetailView(income: income)
            }
        }
    }

    // MARK: - 数据加载

    private func loadData() {
        service.fetchAutoIncomes()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    private func refreshData() async {
        await withCheckedContinuation { continuation in
            service.fetchAutoIncomes()
                .sink(
                    receiveCompletion: { _ in continuation.resume() },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
    }

    private func deleteIncome(_ income: AutoIncome) {
        service.deleteAutoIncome(id: income.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    private func toggleIncome(_ income: AutoIncome) {
        service.toggleAutoIncome(id: income.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 自动入账卡片

struct AutoIncomeCard: View {
    let income: AutoIncome

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：图标、名称、状态
            HStack {
                Image(systemName: income.incomeType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.income)
                    .frame(width: 36, height: 36)
                    .background(Theme.income.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(income.name)
                        .font(AppFont.body(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)

                    Text(income.incomeType.displayName)
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // 状态标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(income.isEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(income.isEnabled ? "已启用" : "已禁用")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(income.isEnabled ? .green : .gray)
                }
            }

            Divider()

            // 金额和入账日
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("入账金额")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text(income.formattedAmount)
                        .font(AppFont.monoNumber(size: 18, weight: .bold))
                        .foregroundColor(Theme.income)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("入账日")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text(income.dayDescription)
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.text)
                }
            }

            // 目标账户和下次入账
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text(income.targetAccountDescription)
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let nextDate = income.formattedNextExecuteDate {
                    Text("下次入账: \(nextDate)")
                        .font(AppFont.body(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    NavigationView {
        AutoIncomeListView()
    }
}
