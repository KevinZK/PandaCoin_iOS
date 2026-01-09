import SwiftUI
import Combine

struct BudgetView: View {
    @StateObject private var viewModel: BudgetViewModel
    @State private var showingAddBudget = false
    @State private var showingEditBudget = false
    @State private var selectedBudget: BudgetProgress?
    @State private var budgetToDelete: BudgetProgress?
    @State private var showingDeleteAlert = false
    @State private var showingExpenseDetail = false
    @State private var selectedBudgetForDetail: BudgetProgress?

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
            .sheet(isPresented: $showingExpenseDetail) {
                if let budget = selectedBudgetForDetail {
                    BudgetExpenseDetailSheet(
                        budget: budget,
                        month: viewModel.currentMonth
                    )
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
                            .fill(Theme.separator)
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
        .background(Theme.cardBackground)
        .cornerRadius(24)
        .shadow(color: Theme.cfoShadow, radius: 15, x: 0, y: 10)
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
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // 使用 List 以支持 swipeActions
                List {
                    ForEach(budgets) { budget in
                        BudgetProgressRow(budget: budget)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                // 分类预算点击查看消费明细，总预算点击编辑
                                if budget.isTotalBudget {
                                    selectedBudget = budget
                                    showingEditBudget = true
                                } else {
                                    selectedBudgetForDetail = budget
                                    showingExpenseDetail = true
                                }
                            }
                            // 左滑操作
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    selectedBudget = budget
                                    showingEditBudget = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(Theme.bambooGreen)

                                Button(role: .destructive) {
                                    if budget.isRecurring {
                                        budgetToDelete = budget
                                        showingDeleteAlert = true
                                    } else {
                                        deleteBudget(budget, cancelRecurring: false)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .background(Color.clear)
                .frame(minHeight: CGFloat(budgets.count) * 120)
                .modifier(HideListBackgroundModifier())
            }
        }
        .alert("删除循环预算", isPresented: $showingDeleteAlert, presenting: budgetToDelete) { budget in
            Button("只删除本月", role: .destructive) {
                deleteBudget(budget, cancelRecurring: false)
            }
            Button("取消所有循环", role: .destructive) {
                deleteBudget(budget, cancelRecurring: true)
            }
            Button("取消", role: .cancel) {}
        } message: { budget in
            Text("「\(budget.displayCategory)」是循环预算，请选择删除方式")
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            
            Text("暂无预算")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            
            Text("点击右上角添加本月预算")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            Button(action: { showingAddBudget = true }) {
                Text("添加预算")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.bambooGreen)
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
    
    private func deleteBudget(_ budget: BudgetProgress, cancelRecurring: Bool) {
        if cancelRecurring {
            viewModel.cancelRecurringBudget(id: budget.id) { _ in }
        } else {
            viewModel.deleteBudget(id: budget.id) { _ in }
        }
    }
}

// MARK: - 隐藏列表背景修饰器
struct HideListBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

// MARK: - 预算进度行 (CFO 风格升级)
struct BudgetProgressRow: View {
    let budget: BudgetProgress

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    // 分类图标
                    Text(budget.categoryIcon)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(budget.displayCategory)
                                .font(AppFont.body(size: 15, weight: .semibold))
                                .foregroundColor(Theme.text)

                            // 循环标记
                            if budget.isRecurring {
                                HStack(spacing: 2) {
                                    Image(systemName: "repeat.circle.fill")
                                        .font(.system(size: 10))
                                    Text("每月")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(Theme.bambooGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.bambooGreen.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }

                        // 如果有消费记录，显示点击查看提示
                        if budget.spentAmount > 0 && !budget.isTotalBudget {
                            Text("点击查看消费明细")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("¥\(String(format: "%.0f", budget.spentAmount))")
                        .foregroundColor(Theme.text)
                    Text("/ ¥\(String(format: "%.0f", budget.budgetAmount))")
                        .foregroundColor(Theme.textSecondary)
                }
                .font(AppFont.monoNumber(size: 13))

                // 箭头指示可点击
                if !budget.isTotalBudget {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 细进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.separator)
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
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.cfoShadow, radius: 8, x: 0, y: 4)
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

// MARK: - 支出分类列表（用于预算，与AI解析输出保持一致）
enum BudgetCategory: String, CaseIterable {
    case food = "FOOD"
    case transport = "TRANSPORT"
    case shopping = "SHOPPING"
    case housing = "HOUSING"
    case entertainment = "ENTERTAINMENT"
    case health = "HEALTH"
    case education = "EDUCATION"
    case communication = "COMMUNICATION"
    case sports = "SPORTS"
    case beauty = "BEAUTY"
    case travel = "TRAVEL"
    case pets = "PETS"
    case subscription = "SUBSCRIPTION"
    case feesAndTaxes = "FEES_AND_TAXES"
    case loanRepayment = "LOAN_REPAYMENT"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .food: return "餐饮"
        case .transport: return "交通"
        case .shopping: return "购物"
        case .housing: return "住房"
        case .entertainment: return "娱乐"
        case .health: return "医疗"
        case .education: return "教育"
        case .communication: return "通讯"
        case .sports: return "运动"
        case .beauty: return "美容"
        case .travel: return "旅行"
        case .pets: return "宠物"
        case .subscription: return "订阅"
        case .feesAndTaxes: return "税费"
        case .loanRepayment: return "还贷"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .food: return "🍜"
        case .transport: return "🚗"
        case .shopping: return "🛍️"
        case .housing: return "🏠"
        case .entertainment: return "🎬"
        case .health: return "💊"
        case .education: return "📚"
        case .communication: return "📱"
        case .sports: return "⚽"
        case .beauty: return "💄"
        case .travel: return "✈️"
        case .pets: return "🐾"
        case .subscription: return "📺"
        case .feesAndTaxes: return "🏛️"
        case .loanRepayment: return "💳"
        case .other: return "📦"
        }
    }
}

// MARK: - 添加预算 Sheet
struct AddBudgetSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: BudgetCategory = .food
    @State private var amount = ""
    @State private var isTotal = false
    @State private var isRecurring = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("设为总预算", isOn: $isTotal)

                    if !isTotal {
                        Picker("选择分类", selection: $selectedCategory) {
                            ForEach(BudgetCategory.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.displayName)
                                }
                                .tag(category)
                            }
                        }
                    }

                    HStack {
                        Text("¥")
                            .foregroundColor(Theme.textSecondary)
                        TextField("预算金额", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Toggle(isOn: $isRecurring) {
                        HStack {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundColor(isRecurring ? Theme.bambooGreen : Theme.textSecondary)
                            Text("每月自动应用")
                        }
                    }
                    .tint(Theme.bambooGreen)

                    if isRecurring {
                        Text("预算将在每个月自动创建")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Section {
                    Text("月份: \(viewModel.displayMonth)")
                        .foregroundColor(Theme.textSecondary)
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
                        .disabled(amount.isEmpty)
                }
            }
        }
    }

    private func saveBudget() {
        guard let amountValue = Double(amount) else { return }
        viewModel.createBudget(
            category: isTotal ? nil : selectedCategory.rawValue,
            amount: amountValue,
            isRecurring: isRecurring
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
                            .foregroundColor(Theme.textSecondary)
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

// MARK: - 预算消费明细 Sheet
struct BudgetExpenseDetailSheet: View {
    let budget: BudgetProgress
    let month: String
    @Environment(\.dismiss) private var dismiss
    @State private var records: [Record] = []
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()

    private let networkManager = NetworkManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 预算摘要卡片
                budgetSummaryCard
                    .padding()

                Divider()

                // 消费记录列表
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if records.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary)
                        Text("暂无消费记录")
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                } else {
                    List(records) { record in
                        ExpenseRecordRow(record: record)
                            .listRowBackground(Theme.cardBackground)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.background)
            .navigationTitle("\(budget.displayCategory)消费明细")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                fetchRecords()
            }
        }
    }

    private var budgetSummaryCard: some View {
        HStack(spacing: 16) {
            // 图标
            Text(budget.categoryIcon)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                Text(budget.displayCategory)
                    .font(AppFont.body(size: 18, weight: .semibold))
                    .foregroundColor(Theme.text)

                Text(month)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(String(format: "%.0f", budget.spentAmount))")
                    .font(AppFont.monoNumber(size: 20, weight: .bold))
                    .foregroundColor(budget.isOverBudget ? .red : Theme.text)

                Text("预算 ¥\(String(format: "%.0f", budget.budgetAmount))")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private func fetchRecords() {
        guard let category = budget.category else {
            isLoading = false
            return
        }

        // 计算月份的起止日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        guard let startDate = dateFormatter.date(from: month) else {
            isLoading = false
            return
        }

        var components = Calendar.current.dateComponents([.year, .month], from: startDate)
        components.month! += 1
        guard let endDate = Calendar.current.date(from: components) else {
            isLoading = false
            return
        }

        // 构建请求参数
        var params: [String: String] = [
            "type": "EXPENSE",
            "category": category
        ]

        let isoFormatter = ISO8601DateFormatter()
        params["startDate"] = isoFormatter.string(from: startDate)
        params["endDate"] = isoFormatter.string(from: endDate)

        let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let endpoint = "/records?\(queryString)"

        print("📡 Fetching records: \(endpoint)")

        // 直接使用 NetworkManager 发起请求
        networkManager.request(endpoint: endpoint, method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to fetch records: \(error)")
                        records = []
                    }
                },
                receiveValue: { (fetchedRecords: [Record]) in
                    print("✅ Fetched \(fetchedRecords.count) records")
                    records = fetchedRecords.sorted { $0.date > $1.date }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 消费记录行
struct ExpenseRecordRow: View {
    let record: Record

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.description ?? "消费")
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)

                Text(formatDate(record.date))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text("-¥\(String(format: "%.2f", NSDecimalNumber(decimal: record.amount).doubleValue))")
                .font(AppFont.monoNumber(size: 15, weight: .semibold))
                .foregroundColor(.red)
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: date)
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
            BudgetProgress(id: "1", month: "2025-12", category: "餐饮", name: "每月餐饮预算", budgetAmount: 3000, spentAmount: 2800, remainingAmount: 200, usagePercent: 93.3, isOverBudget: false, isRecurring: true),
            BudgetProgress(id: "2", month: "2025-12", category: "交通", name: nil, budgetAmount: 1000, spentAmount: 1200, remainingAmount: -200, usagePercent: 120.0, isOverBudget: true, isRecurring: true),
            BudgetProgress(id: "3", month: "2025-12", category: "购物", name: nil, budgetAmount: 2000, spentAmount: 800, remainingAmount: 1200, usagePercent: 40.0, isOverBudget: false, isRecurring: false)
        ]
    )
    
    return NavigationView {
        BudgetView(viewModel: viewModel)
    }
}
