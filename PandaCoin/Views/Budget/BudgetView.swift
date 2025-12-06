import SwiftUI

struct BudgetView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showingAddBudget = false
    @State private var showingEditBudget = false
    @State private var selectedBudget: BudgetProgress?
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("预算管理")
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
    
    // MARK: - 总体进度卡片
    private func overallProgressCard(summary: MonthlyBudgetSummary) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("本月预算")
                    .font(.headline)
                Spacer()
                Text("¥\(String(format: "%.0f", summary.totalBudget))")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 24)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor(percent: summary.overallUsagePercent))
                        .frame(
                            width: min(CGFloat(summary.overallUsagePercent / 100) * geometry.size.width, geometry.size.width),
                            height: 24
                        )
                    
                    Text("\(String(format: "%.1f", summary.overallUsagePercent))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                }
            }
            .frame(height: 24)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("已支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(String(format: "%.0f", summary.totalSpent))")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("剩余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(String(format: "%.0f", summary.totalRemaining))")
                        .font(.headline)
                        .foregroundColor(summary.totalRemaining >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
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

// MARK: - 预算进度行
struct BudgetProgressRow: View {
    let budget: BudgetProgress
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(budget.displayCategory)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("¥\(String(format: "%.0f", budget.spentAmount)) / ¥\(String(format: "%.0f", budget.budgetAmount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(
                            width: min(CGFloat(budget.usagePercent / 100) * geometry.size.width, geometry.size.width),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            
            HStack {
                if budget.isOverBudget {
                    Text("超支 ¥\(String(format: "%.0f", -budget.remainingAmount))")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("剩余 ¥\(String(format: "%.0f", budget.remainingAmount))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Text("\(String(format: "%.1f", budget.usagePercent))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5)
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

#Preview {
    BudgetView()
}
