import SwiftUI

struct BudgetView: View {
    @StateObject private var viewModel: BudgetViewModel
    @State private var showingAddBudget = false
    @State private var showingEditBudget = false
    @State private var selectedBudget: BudgetProgress?
    
    init(viewModel: BudgetViewModel = BudgetViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 月份选择器
                monthSelector
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if let summary = viewModel.summary {
                    // 总体进度卡片
                    overallProgressCard(summary: summary)
                    
                    // 分类预算列表
                    categoryBudgetsList(budgets: summary.categoryBudgets)
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("预算管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddBudget = true }) {
                        Label("添加预算", systemImage: "plus")
                    }
                    Button(action: copyFromPrevious) {
                        Label("复制上月预算", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddBudget) {
            AddBudgetSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditBudget) {
            if let budget = selectedBudget {
                EditBudgetSheet(viewModel: viewModel, budget: budget)
            }
        }
        .onAppear {
            viewModel.fetchCurrentProgress()
        }
    }
    
    // MARK: - 月份选择器
    private var monthSelector: some View {
        HStack {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            
            Spacer()
            
            Text(viewModel.displayMonth)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 总体进度卡片 (CFO 风格升级)
    private func overallProgressCard(summary: MonthlyBudgetSummary) -> some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本月预算水位")
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    
                    Text("¥\(String(format: "%.0f", summary.totalBudget))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                
                Spacer()
                
                // 水位百分比球 (模拟)
                ZStack {
                    Circle()
                        .fill(progressColor(percent: summary.overallUsagePercent).opacity(0.1))
                        .frame(width: 64, height: 64)
                    
                    Text("\(Int(summary.overallUsagePercent))%")
                        .font(AppFont.monoNumber(size: 16, weight: .bold))
                        .foregroundColor(progressColor(percent: summary.overallUsagePercent))
                }
            }
            
            // 高级进度条
            VStack(spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 12)
                        
                        LinearGradient(
                            colors: [progressColor(percent: summary.overallUsagePercent), progressColor(percent: summary.overallUsagePercent).opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: min(CGFloat(summary.overallUsagePercent / 100) * geometry.size.width, geometry.size.width), height: 12)
                        .clipShape(Capsule())
                    }
                }
                .frame(height: 12)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已消耗")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Text("¥\(String(format: "%.0f", summary.totalSpent))")
                            .font(AppFont.monoNumber(size: 16, weight: .semibold))
                            .foregroundColor(progressColor(percent: summary.overallUsagePercent))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("剩余额度")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Text("¥\(String(format: "%.0f", summary.totalRemaining))")
                            .font(AppFont.monoNumber(size: 16, weight: .semibold))
                            .foregroundColor(summary.totalRemaining >= 0 ? Theme.bambooGreen : .red)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(summary.overallUsagePercent >= 100 ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - 分类预算列表
    private func categoryBudgetsList(budgets: [BudgetProgress]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类预算")
                .font(.headline)
                .padding(.horizontal)
            
            if budgets.isEmpty {
                Text("暂无分类预算")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(budgets) { budget in
                    BudgetProgressRow(budget: budget)
                        .onTapGesture {
                            selectedBudget = budget
                            showingEditBudget = true
                        }
                }
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无预算")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角添加本月预算")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { showingAddBudget = true }) {
                Text("添加预算")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(height: 300)
    }
    
    // MARK: - 辅助方法
    private func progressColor(percent: Double) -> Color {
        if percent >= 100 {
            return .red
        } else if percent >= 80 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func copyFromPrevious() {
        viewModel.copyFromPreviousMonth { count in
            // 可以添加提示
        }
    }
}

// MARK: - 预算进度行 (CFO 风格升级)
struct BudgetProgressRow: View {
    let budget: BudgetProgress
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(budget.displayCategory)
                    .font(AppFont.body(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("¥\(String(format: "%.0f", budget.spentAmount))")
                        .foregroundColor(Theme.text)
                    Text("/ ¥\(String(format: "%.0f", budget.budgetAmount))")
                        .foregroundColor(Theme.textSecondary)
                }
                .font(AppFont.monoNumber(size: 13))
            }
            
            // 细进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(progressColor)
                        .frame(width: min(CGFloat(budget.usagePercent / 100) * geometry.size.width, geometry.size.width), height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                if budget.isOverBudget {
                    Label("超支 ¥\(String(format: "%.0f", -budget.remainingAmount))", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                } else {
                    Text("剩余 ¥\(String(format: "%.0f", budget.remainingAmount))")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.bambooGreen)
                }
                
                Spacer()
                
                Text("\(Int(budget.usagePercent))%")
                    .font(AppFont.monoNumber(size: 11, weight: .bold))
                    .foregroundColor(progressColor)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
    
    private var progressColor: Color {
        if budget.usagePercent >= 100 {
            return .red
        } else if budget.usagePercent >= 80 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - 添加预算 Sheet
struct AddBudgetSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var category = ""
    @State private var amount = ""
    @State private var isTotal = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("设为总预算", isOn: $isTotal)
                    
                    if !isTotal {
                        TextField("分类名称", text: $category)
                    }
                    
                    TextField("预算金额", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Text("月份: \(viewModel.displayMonth)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveBudget() }
                        .disabled(amount.isEmpty || (!isTotal && category.isEmpty))
                }
            }
        }
    }
    
    private func saveBudget() {
        guard let amountValue = Double(amount) else { return }
        viewModel.createBudget(
            category: isTotal ? nil : category,
            amount: amountValue
        ) { success in
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - 编辑预算 Sheet
struct EditBudgetSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let budget: BudgetProgress
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("分类")
                        Spacer()
                        Text(budget.displayCategory)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("预算金额", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(role: .destructive) {
                        deleteBudget()
                    } label: {
                        Text("删除预算")
                    }
                }
            }
            .navigationTitle("编辑预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { updateBudget() }
                        .disabled(amount.isEmpty)
                }
            }
            .onAppear {
                amount = String(format: "%.0f", budget.budgetAmount)
            }
        }
    }
    
    private func updateBudget() {
        guard let amountValue = Double(amount) else { return }
        viewModel.updateBudget(id: budget.id, amount: amountValue) { success in
            if success {
                dismiss()
            }
        }
    }
    
    private func deleteBudget() {
        viewModel.deleteBudget(id: budget.id) { success in
            if success {
                dismiss()
            }
        }
    }
}

#Preview("预算管理 - CFO 风格") {
    let viewModel = BudgetViewModel()
    viewModel.summary = MonthlyBudgetSummary(
        month: "2025-12",
        totalBudget: 10000,
        totalSpent: 6500,
        totalRemaining: 3500,
        overallUsagePercent: 65.0,
        categoryBudgets: [
            BudgetProgress(id: "1", month: "2025-12", category: "餐饮", budgetAmount: 3000, spentAmount: 2800, remainingAmount: 200, usagePercent: 93.3, isOverBudget: false),
            BudgetProgress(id: "2", month: "2025-12", category: "交通", budgetAmount: 1000, spentAmount: 1200, remainingAmount: -200, usagePercent: 120.0, isOverBudget: true),
            BudgetProgress(id: "3", month: "2025-12", category: "购物", budgetAmount: 2000, spentAmount: 800, remainingAmount: 1200, usagePercent: 40.0, isOverBudget: false)
        ]
    )
    
    return NavigationView {
        BudgetView(viewModel: viewModel)
    }
}
