//
//  StatisticsView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @StateObject private var recordService: RecordService
    @State private var selectedPeriod: Period = .month
    
    init(recordService: RecordService = RecordService()) {
        _recordService = StateObject(wrappedValue: recordService)
    }
    
    enum Period: String, CaseIterable {
        case month = "本月"
        case year = "本年"
    }
    
    var categoryData: [(String, Double)] {
        guard let stats = recordService.statistics else { return [] }
        return stats.categoryStats.map { (key: $0.key, value: NSDecimalNumber(decimal: $0.value).doubleValue) }
            .sorted { $0.value > $1.value }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.large) {
                    // 周期选择
                    periodPicker
                    
                    // 总览卡片
                    if let stats = recordService.statistics {
                        overviewCards(stats: stats)
                        
                        // 分类占比图表
                        categoryChart
                        
                        // 分类排行
                        categoryRanking
                    } else {
                        loadingView
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.medium)
            }
        }
        .navigationTitle("统计报表")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadStatistics()
        }
    }
    
    // MARK: - 周期选择
    private var periodPicker: some View {
        Picker("周期", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { _ in
            loadStatistics()
        }
    }
    
    // MARK: - 总览卡片
    private func overviewCards(stats: RecordStatistics) -> some View {
        VStack(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                StatCard(
                    title: "总收入",
                    amount: stats.totalIncome,
                    color: Theme.income,
                    icon: "arrow.down.circle.fill"
                )
                
                StatCard(
                    title: "总支出",
                    amount: stats.totalExpense,
                    color: Theme.expense,
                    icon: "arrow.up.circle.fill"
                )
            }
            
            StatCard(
                title: "净收入",
                amount: stats.balance,
                color: stats.balance >= 0 ? Theme.income : Theme.expense,
                icon: "equal.circle.fill"
            )
        }
    }
    
    // MARK: - 分类图表
    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("支出分布")
                .font(.headline)
                .padding(.horizontal)
            
            if categoryData.isEmpty {
                Text("暂无数据")
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                if #available(iOS 17.0, *) {
                    Chart(categoryData, id: \.0) { item in
                        SectorMark(
                            angle: .value("金额", item.1),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("分类", item.0))
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                    .padding()
                } else if #available(iOS 16.0, *) {
                    // iOS 16 不支持 SectorMark
                    Text("饼图功能需要 iOS 17.0 或更高版本")
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("图表功能需要 iOS 16.0 或更高版本")
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }
    
    // MARK: - 分类排行
    private var categoryRanking: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("支出排行")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(Array(categoryData.enumerated()), id: \.element.0) { index, item in
                    CategoryRankRow(
                        rank: index + 1,
                        category: item.0,
                        amount: Decimal(item.1),
                        total: recordService.statistics?.totalExpense ?? 0
                    )
                    
                    if index < categoryData.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中...")
                .foregroundColor(Theme.textSecondary)
                .padding(.top)
        }
        .frame(height: 200)
    }
    
    private func loadStatistics() {
        recordService.fetchStatistics(period: selectedPeriod == .month ? "month" : "year")
    }
}

// MARK: - 统计卡片 (CFO 风格升级)
struct StatCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
                
                // 模拟趋势小图标 (财务官洞察)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                
                Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(AppFont.monoNumber(size: 20, weight: .bold))
                    .foregroundColor(Theme.text)
            }
        }
        .padding(Spacing.medium)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - 分类排行行 (CFO 风格升级)
struct CategoryRankRow: View {
    let rank: Int
    let category: String
    let amount: Decimal
    let total: Decimal
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: amount / total * 100).doubleValue
    }
    
    var body: some View {
        HStack(spacing: Spacing.medium) {
            // 排名和图标
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Text(CategoryMapper.icon(for: category))
                    .font(.system(size: 18))
            }
            
            // 分类信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(CategoryMapper.displayName(for: category))
                        .font(AppFont.body(size: 15, weight: .medium))
                    Spacer()
                    Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(AppFont.monoNumber(size: 15, weight: .bold))
                }
                
                // 渐变进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.separator)
                            .frame(height: 6)
                        
                        LinearGradient(
                            colors: [Theme.expense, Theme.expense.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                        .clipShape(Capsule())
                    }
                }
                .frame(height: 6)
            }
            
            // 占比
            Text("\(String(format: "%.1f", percentage))%")
                .font(AppFont.monoNumber(size: 12, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, Spacing.medium)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .gray
        }
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

#Preview("统计报表 - CFO 风格") {
    let service = RecordService()
    service.statistics = RecordStatistics(
        period: "month",
        totalIncome: 12000,
        totalExpense: 4500,
        balance: 7500,
        categoryStats: [
            "FOOD": 1500,
            "TRANSPORT": 800,
            "SHOPPING": 1200,
            "ENTERTAINMENT": 500,
            "OTHER": 500
        ],
        recordCount: 25
    )
    
    return NavigationView {
        StatisticsView(recordService: service)
    }
}
