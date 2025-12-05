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
    @StateObject private var recordService = RecordService()
    @State private var selectedPeriod: Period = .month
    
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
        NavigationView {
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
                    .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("图表功能需要 iOS 16.0 或更高版本")
                        .foregroundColor(.gray)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.white)
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
        .background(Color.white)
        .cornerRadius(CornerRadius.large)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.gray)
                .padding(.top)
        }
        .frame(height: 200)
    }
    
    private func loadStatistics() {
        recordService.fetchStatistics(period: selectedPeriod == .month ? "month" : "year")
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.medium)
        .background(Color.white)
        .cornerRadius(CornerRadius.medium)
    }
    
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - 分类排行行
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
            // 排名
            Text("\(rank)")
                .font(.headline)
                .foregroundColor(rankColor)
                .frame(width: 30)
            
            // 分类信息
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.body)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Theme.expense)
                            .frame(width: geometry.size.width * (percentage / 100), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
            }
            
            // 金额和占比
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(.headline)
                
                Text("\(String(format: "%.1f", percentage))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(Spacing.medium)
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

#Preview {
    StatisticsView()
}
