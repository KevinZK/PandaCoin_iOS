//
//  RecordsListView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine

struct RecordsListView: View {
    @StateObject private var recordService: RecordService
    @StateObject private var accountService = AssetService()
    @State private var showAddRecord = false
    @State private var selectedType: RecordType? = nil
    @State private var searchText = ""
    
    init(recordService: RecordService = RecordService()) {
        _recordService = StateObject(wrappedValue: recordService)
    }
    
    var filteredRecords: [Record] {
        var filtered = recordService.records
        
        if let type = selectedType {
            filtered = filtered.filter { $0.type == type }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { record in
                record.category.localizedCaseInsensitiveContains(searchText) ||
                (record.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 筛选栏
                filterBar
                
                // 记录列表
                if filteredRecords.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
        }
        .navigationTitle("记账记录")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddRecord = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.bambooGreen)
                }
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddRecordView(accountService: accountService, recordService: recordService)
                .onAppear {
                    // 只有打开添加记账页面时才加载账户列表
                    accountService.fetchAccounts()
                }
        }
        .onAppear {
            // CFO 风格优化：如果已经有数据（如预览数据），不再重复抓取
            if recordService.records.isEmpty {
                recordService.fetchRecords()
            }
        }
    }
    
    // MARK: - 筛选栏
    private var filterBar: some View {
        VStack(spacing: Spacing.small) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)
                
                TextField("搜索分类或备注", text: $searchText)
                    .foregroundColor(Theme.text)
            }
            .padding(Spacing.medium)
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .padding(.horizontal)
            
            // 类型筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.small) {
                    FilterChip(
                        title: "全部",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )
                    
                    FilterChip(
                        title: "支出",
                        isSelected: selectedType == .expense,
                        action: { selectedType = .expense }
                    )
                    
                    FilterChip(
                        title: "收入",
                        isSelected: selectedType == .income,
                        action: { selectedType = .income }
                    )
                    
                    FilterChip(
                        title: "转账",
                        isSelected: selectedType == .transfer,
                        action: { selectedType = .transfer }
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, Spacing.small)
        .background(Theme.background)
    }
    
    // MARK: - 记录列表
    private var recordsList: some View {
        List {
            ForEach(groupedRecords, id: \.0) { date, records in
                Section {
                    ForEach(records) { record in
                        RecordRowView(record: record)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: record.id == records.first?.id ? CornerRadius.medium : 0)
                                    .fill(Theme.cardBackground)
                                    .clipShape(
                                        RecordRowShape(
                                            isFirst: record.id == records.first?.id,
                                            isLast: record.id == records.last?.id,
                                            cornerRadius: CornerRadius.medium
                                        )
                                    )
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteRecord(record)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(formatDateHeader(date))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .background(Theme.background)
    }
}

// MARK: - 圆角裁剪 Shape
struct RecordRowShape: Shape {
    let isFirst: Bool
    let isLast: Bool
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var corners: UIRectCorner = []
        if isFirst {
            corners.insert(.topLeft)
            corners.insert(.topRight)
        }
        if isLast {
            corners.insert(.bottomLeft)
            corners.insert(.bottomRight)
        }
        
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - RecordsListView 续
extension RecordsListView {
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            Text("📊")
                .font(.system(size: 60))
            Text("还没有记账记录")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            Text("点击右上角 + 开始记账")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
    }
    
    // MARK: - 辅助方法
    private var groupedRecords: [(String, [Record])] {
        let grouped = Dictionary(grouping: filteredRecords) { record in
            Calendar.current.startOfDay(for: record.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { ($0.key.ISO8601Format(), $0.value) }
    }
    
    private func formatDateHeader(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else { return dateString }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        }
    }
    
    private func deleteRecord(_ record: Record) {
        recordService.deleteRecord(id: record.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [self] _ in
                    recordService.fetchRecords()
                }
            )
            .store(in: &recordService.cancellables)
    }
}

// MARK: - 记录行视图 (CFO 风格升级)
struct RecordRowView: View {
    let record: Record
    
    var body: some View {
        HStack(spacing: 0) {
            // 时间线连接器
            VStack(spacing: 0) {
                Circle()
                    .fill(categoryColor.opacity(0.8))
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(Theme.separator.opacity(0.5))
                    .frame(width: 2)
            }
            .padding(.trailing, 16)
            
            // 主卡片内容
            HStack(spacing: Spacing.medium) {
                // 分类图标
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(CategoryMapper.icon(for: record.category))
                        .font(.system(size: 22))
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(CategoryMapper.displayName(for: record.category))
                        .font(AppFont.body(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    
                    if let description = record.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 金额
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatAmount(record.amount, type: record.type))
                        .font(AppFont.monoNumber(size: 17, weight: .bold))
                        .foregroundColor(amountColor)
                    
                    if let accountName = record.rawText, !accountName.isEmpty {
                        Text(accountName)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary.opacity(0.8))
                    }
                }
            }
            .padding(Spacing.medium)
            .background(Theme.cardBackground)
            .cornerRadius(CornerRadius.medium)
            .shadow(color: Theme.cfoShadow, radius: 5, x: 0, y: 2)
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        record.type == .expense ? Theme.expense : Theme.income
    }
    
    private var amountColor: Color {
        switch record.type {
        case .expense: return Theme.expense
        case .income: return Theme.income
        case .transfer: return Theme.textSecondary
        }
    }
    
    private func formatAmount(_ amount: Decimal, type: RecordType) -> String {
        let prefix = type == .expense ? "-" : (type == .income ? "+" : "")
        return "\(prefix)¥\(amount)"
    }
}

// MARK: - 筛选chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .background(isSelected ? Theme.bambooGreen : Theme.cardBackground)
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .cornerRadius(CornerRadius.medium)
        }
    }
}

// MARK: - 添加记账视图
struct AddRecordView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var accountService: AssetService
    @ObservedObject var recordService: RecordService
    
    @State private var amount: String = ""
    @State private var type: RecordType = .expense
    @State private var category: String = "餐饮"
    @State private var selectedAccount: Asset?
    @State private var description: String = ""
    @State private var date = Date()
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Form {
                    Section("类型") {
                        Picker("记账类型", selection: $type) {
                            Text("支出").tag(RecordType.expense)
                            Text("收入").tag(RecordType.income)
                            Text("转账").tag(RecordType.transfer)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section("金额") {
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title)
                    }
                    
                    Section("分类") {
                        let categories = type == .expense ? 
                            DefaultCategories.expenseCategories : 
                            DefaultCategories.incomeCategories
                        
                        Picker("选择分类", selection: $category) {
                            ForEach(categories, id: \.0) { cat in
                                Text("\(cat.1) \(cat.0)").tag(cat.0)
                            }
                        }
                    }
                    
                    Section("账户") {
                        Picker("选择账户", selection: $selectedAccount) {
                            ForEach(accountService.accounts) { account in
                                Text(account.name).tag(account as Asset?)
                            }
                        }
                    }
                    
                    Section("备注") {
                        TextField("添加备注(可选)", text: $description)
                    }
                    
                    Section("日期") {
                        DatePicker("记账日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("手动记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(amount.isEmpty || selectedAccount == nil || isLoading)
                }
            }
            .onAppear {
                selectedAccount = accountService.accounts.first
            }
        }
    }
    
    private func saveRecord() {
        guard let amountValue = Decimal(string: amount),
              let account = selectedAccount else { return }
        
        isLoading = true
        
        recordService.createRecord(
            amount: amountValue,
            type: type,
            category: category,
            accountId: account.id,
            description: description.isEmpty ? nil : description,
            date: date
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .finished = completion {
                    recordService.fetchRecords()
                    dismiss()
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &recordService.cancellables)
    }
}

#Preview("记账记录 - CFO 风格") {
    let service = RecordService()
    let now = Date()
    service.records = [
        Record(id: "1", amount: 35.5, type: .expense, category: "FOOD", description: "午餐吃了个汉堡", date: now, accountId: "acc1", accountName: "支付宝", isConfirmed: true),
        Record(id: "2", amount: 15.0, type: .expense, category: "TRANSPORT", description: "打车去公司", date: now, accountId: "acc1", accountName: "支付宝", isConfirmed: true),
        Record(id: "3", amount: 8000.0, type: .income, category: "INCOME_SALARY", description: "12月工资", date: Calendar.current.date(byAdding: .day, value: -1, to: now)!, accountId: "acc2", accountName: "招商银行", isConfirmed: true),
        Record(id: "4", amount: 200.0, type: .expense, category: "SHOPPING", description: "超市采购", date: Calendar.current.date(byAdding: .day, value: -1, to: now)!, accountId: "acc3", accountName: "招商信用卡", isConfirmed: true),
        Record(id: "5", amount: 500.0, type: .transfer, category: "OTHER", description: "转账给备用金", date: Calendar.current.date(byAdding: .day, value: -2, to: now)!, accountId: "acc1", accountName: "支付宝", isConfirmed: true)
    ]
    
    return NavigationView {
        RecordsListView(recordService: service)
    }
}
