//
//  StatisticsView.swift
//  PandaCoin
//
//  统计报表视图 - 增强版
//

import SwiftUI
import Combine
#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedTab: StatisticsTab = .overview

    enum StatisticsTab: String, CaseIterable {
        case overview = "总览"
        case trend = "趋势"
        case income = "收入"
        case health = "健康度"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部标签切换
                tabPicker

                // 内容区域
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .trend:
                            trendContent
                        case .income:
                            incomeContent
                        case .health:
                            healthContent
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, Spacing.medium)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("统计报表")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadAllData()
        }
    }

    // MARK: - 标签选择器
    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                ForEach(StatisticsTab.allCases, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: selectedTab == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.small)
        }
        .background(Theme.background)
    }

    // MARK: - 总览内容
    private var overviewContent: some View {
        VStack(spacing: Spacing.large) {
            // 周期选择
            periodPicker

            if viewModel.isLoading {
                loadingView
            } else if let stats = viewModel.statistics {
                // 总览卡片（带环比）
                overviewCards(stats: stats)

                // 支出分布图
                expenseCategoryChart

                // 分类排行
                categoryRanking
            } else {
                emptyView
            }
        }
    }

    // MARK: - 趋势内容
    private var trendContent: some View {
        VStack(spacing: Spacing.large) {
            // 趋势周期选择
            trendPeriodPicker

            if viewModel.isLoadingTrend {
                loadingView
            } else if let trend = viewModel.trendStatistics {
                // 趋势图表
                if #available(iOS 16.0, *) {
                    trendChart(data: trend)
                } else {
                    Text("趋势图表需要 iOS 16.0+")
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 250)
                }

                // 趋势汇总
                trendSummary(summary: trend.summary)
            } else {
                emptyView
            }
        }
    }

    // MARK: - 收入内容
    private var incomeContent: some View {
        VStack(spacing: Spacing.large) {
            if viewModel.isLoadingIncome {
                loadingView
            } else if let income = viewModel.incomeAnalysis {
                // 收入总览
                incomeOverview(income: income)

                // 收入构成
                incomeComposition(income: income)

                // 收入趋势
                if #available(iOS 16.0, *) {
                    incomeTrendChart(data: income.trend)
                } else {
                    Text("收入趋势图需要 iOS 16.0+")
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 200)
                }
            } else {
                emptyView
            }
        }
    }

    // MARK: - 健康度内容
    private var healthContent: some View {
        VStack(spacing: Spacing.large) {
            if viewModel.isLoadingHealth {
                loadingView
            } else if let health = viewModel.financialHealth {
                // 综合评分
                healthScoreCard(health: health)

                // 各项指标
                healthMetrics(health: health)

                // 改进建议
                if !health.suggestions.isEmpty {
                    healthSuggestions(suggestions: health.suggestions)
                }
            } else {
                emptyView
            }
        }
    }

    // MARK: - 周期选择器
    private var periodPicker: some View {
        Picker("周期", selection: $viewModel.selectedPeriod) {
            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedPeriod) { _ in
            viewModel.loadStatistics()
        }
    }

    // MARK: - 趋势周期选择器
    private var trendPeriodPicker: some View {
        Picker("周期", selection: $viewModel.selectedTrendPeriod) {
            ForEach(TrendPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedTrendPeriod) { _ in
            viewModel.loadTrendStatistics()
        }
    }

    // MARK: - 总览卡片
    private func overviewCards(stats: RecordStatistics) -> some View {
        VStack(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                EnhancedStatCard(
                    title: "总收入",
                    amount: stats.totalIncome,
                    change: viewModel.comparison?.changes.incomeChangePercent,
                    color: Theme.income,
                    icon: "arrow.down.circle.fill"
                )

                EnhancedStatCard(
                    title: "总支出",
                    amount: stats.totalExpense,
                    change: viewModel.comparison?.changes.expenseChangePercent,
                    color: Theme.expense,
                    icon: "arrow.up.circle.fill"
                )
            }

            HStack(spacing: Spacing.medium) {
                EnhancedStatCard(
                    title: "净收入",
                    amount: stats.balance,
                    change: nil,
                    color: stats.balance >= 0 ? Theme.income : Theme.expense,
                    icon: "equal.circle.fill"
                )

                // 储蓄率卡片
                SavingsRateCard(rate: stats.savingsRate)
            }
        }
    }

    // MARK: - 支出分类图表
    private var expenseCategoryChart: some View {
        let categoryData = viewModel.expenseCategoryData

        return VStack(alignment: .leading, spacing: Spacing.medium) {
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
                        .foregroundStyle(by: .value("分类", CategoryMapper.displayName(for: item.0)))
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                    .padding()
                } else {
                    Text("饼图需要 iOS 17.0+")
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 分类排行
    private var categoryRanking: some View {
        let categoryData = viewModel.expenseCategoryData

        return VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("支出排行")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(categoryData.prefix(5).enumerated()), id: \.element.0) { index, item in
                    CategoryRankRow(
                        rank: index + 1,
                        category: item.0,
                        amount: Decimal(item.1),
                        total: viewModel.statistics?.totalExpense ?? 0
                    )

                    if index < min(categoryData.count, 5) - 1 {
                        Divider()
                    }
                }
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 趋势图表
    @available(iOS 16.0, *)
    private func trendChart(data: TrendStatistics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("收支趋势")
                .font(.headline)
                .padding(.horizontal)

            if data.data.isEmpty {
                Text("暂无数据")
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(data.data) { point in
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("收入", point.income)
                        )
                        .foregroundStyle(Theme.income)
                        .symbol(Circle())

                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("支出", point.expense)
                        )
                        .foregroundStyle(Theme.expense)
                        .symbol(Circle())
                    }
                }
                .chartLegend(position: .top)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
                .padding()
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 趋势汇总
    private func trendSummary(summary: TrendStatistics.TrendSummary) -> some View {
        VStack(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                SummaryItem(title: "总收入", value: "¥\(formatAmount(summary.totalIncome))", color: Theme.income)
                SummaryItem(title: "总支出", value: "¥\(formatAmount(summary.totalExpense))", color: Theme.expense)
            }

            HStack(spacing: Spacing.medium) {
                SummaryItem(title: "日均支出", value: "¥\(formatAmount(summary.avgDailyExpense))", color: Theme.textSecondary)
                SummaryItem(title: "最高消费日", value: summary.maxExpenseDay, color: Theme.warning)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 收入总览
    private func incomeOverview(income: IncomeAnalysis) -> some View {
        VStack(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                IncomeCard(title: "总收入", amount: income.totalIncome, icon: "arrow.down.circle.fill", color: Theme.income)
                IncomeCard(title: "固定收入", amount: income.fixedIncome, icon: "lock.fill", color: Theme.bambooGreen)
            }

            HStack(spacing: Spacing.medium) {
                IncomeCard(title: "浮动收入", amount: income.variableIncome, icon: "arrow.triangle.2.circlepath", color: Theme.warning)

                // 固定收入占比
                VStack(alignment: .leading, spacing: 8) {
                    Text("固定收入占比")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text("\(String(format: "%.1f", income.fixedIncomeRatio))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(income.fixedIncomeRatio >= 70 ? Theme.income : Theme.warning)

                    Text(income.fixedIncomeRatio >= 70 ? "收入稳定" : "收入波动较大")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(CornerRadius.medium)
            }
        }
    }

    // MARK: - 收入构成
    private func incomeComposition(income: IncomeAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("收入构成")
                .font(.headline)
                .padding(.horizontal)

            ForEach(income.categories) { item in
                IncomeItemRow(item: item)
            }
        }
        .padding(.vertical)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 收入趋势图
    @available(iOS 16.0, *)
    private func incomeTrendChart(data: [TrendDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("收入趋势（近6月）")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                Text("暂无数据")
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("月份", point.date),
                        y: .value("收入", point.income)
                    )
                    .foregroundStyle(Theme.income.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .padding()
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 健康度评分卡片
    private func healthScoreCard(health: FinancialHealth) -> some View {
        VStack(spacing: Spacing.medium) {
            // 评分圆环
            ZStack {
                Circle()
                    .stroke(Theme.separator, lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(health.overallScore) / 100)
                    .stroke(
                        gradeColor(health.grade),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(health.overallScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(gradeColor(health.grade))

                    Text(health.grade.displayName)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Text("财务健康度")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.large)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 健康度指标
    private func healthMetrics(health: FinancialHealth) -> some View {
        VStack(spacing: Spacing.small) {
            HealthMetricRow(
                title: "储蓄率",
                value: "\(String(format: "%.1f", health.metrics.savingsRate.value))%",
                score: health.metrics.savingsRate.score,
                status: health.metrics.savingsRate.status,
                suggestion: health.metrics.savingsRate.suggestion
            )

            HealthMetricRow(
                title: "必要支出比",
                value: "\(String(format: "%.1f", health.metrics.essentialExpenseRatio.value))%",
                score: health.metrics.essentialExpenseRatio.score,
                status: health.metrics.essentialExpenseRatio.status,
                suggestion: health.metrics.essentialExpenseRatio.suggestion
            )

            HealthMetricRow(
                title: "负债率",
                value: "\(String(format: "%.1f", health.metrics.debtRatio.value))%",
                score: health.metrics.debtRatio.score,
                status: health.metrics.debtRatio.status,
                suggestion: health.metrics.debtRatio.suggestion
            )

            HealthMetricRow(
                title: "流动性",
                value: "\(String(format: "%.1f", health.metrics.liquidityRatio.value))x",
                score: health.metrics.liquidityRatio.score,
                status: health.metrics.liquidityRatio.status,
                suggestion: health.metrics.liquidityRatio.suggestion
            )

            HealthMetricRow(
                title: "预算执行",
                value: "\(String(format: "%.1f", health.metrics.budgetAdherence.value))%",
                score: health.metrics.budgetAdherence.score,
                status: health.metrics.budgetAdherence.status,
                suggestion: health.metrics.budgetAdherence.suggestion
            )
        }
    }

    // MARK: - 改进建议
    private func healthSuggestions(suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("改进建议")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(Theme.warning)
                            .font(.caption)

                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundColor(Theme.text)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, Spacing.small)
        }
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    // MARK: - 辅助视图
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中...")
                .foregroundColor(Theme.textSecondary)
                .padding(.top)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            Text("暂无数据")
                .foregroundColor(Theme.textSecondary)
                .padding(.top)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 辅助方法
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    private func gradeColor(_ grade: HealthGrade) -> Color {
        switch grade {
        case .A: return .green
        case .B: return .blue
        case .C: return .orange
        case .D, .F: return .red
        }
    }
}

// MARK: - ViewModel
class StatisticsViewModel: ObservableObject {
    @Published var statistics: RecordStatistics?
    @Published var comparison: ComparisonStatistics?
    @Published var trendStatistics: TrendStatistics?
    @Published var incomeAnalysis: IncomeAnalysis?
    @Published var financialHealth: FinancialHealth?

    @Published var selectedPeriod: StatisticsPeriod = .month
    @Published var selectedTrendPeriod: TrendPeriod = .daily

    @Published var isLoading = false
    @Published var isLoadingTrend = false
    @Published var isLoadingIncome = false
    @Published var isLoadingHealth = false

    private let recordService = RecordService.shared
    private var cancellables = Set<AnyCancellable>()

    var expenseCategoryData: [(String, Double)] {
        guard let stats = statistics else { return [] }
        return stats.categoryStats.map { ($0.key, NSDecimalNumber(decimal: $0.value).doubleValue) }
            .sorted { $0.1 > $1.1 }
    }

    func loadAllData() {
        loadStatistics()
        loadComparison()
        loadTrendStatistics()
        loadIncomeAnalysis()
        loadFinancialHealth()
    }

    func loadStatistics() {
        isLoading = true
        recordService.fetchStatisticsPublisher(period: selectedPeriod)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        logError("获取统计失败", error: error)
                    }
                },
                receiveValue: { [weak self] stats in
                    self?.statistics = stats
                }
            )
            .store(in: &cancellables)
    }

    func loadComparison() {
        recordService.fetchComparisonStatistics()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] comparison in
                    self?.comparison = comparison
                }
            )
            .store(in: &cancellables)
    }

    func loadTrendStatistics() {
        isLoadingTrend = true
        recordService.fetchTrendStatistics(period: selectedTrendPeriod)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingTrend = false
                    if case .failure(let error) = completion {
                        logError("获取趋势失败", error: error)
                    }
                },
                receiveValue: { [weak self] trend in
                    self?.trendStatistics = trend
                }
            )
            .store(in: &cancellables)
    }

    func loadIncomeAnalysis() {
        isLoadingIncome = true
        recordService.fetchIncomeAnalysis()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingIncome = false
                    if case .failure(let error) = completion {
                        logError("获取收入分析失败", error: error)
                    }
                },
                receiveValue: { [weak self] income in
                    self?.incomeAnalysis = income
                }
            )
            .store(in: &cancellables)
    }

    func loadFinancialHealth() {
        isLoadingHealth = true
        recordService.fetchFinancialHealth()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingHealth = false
                    if case .failure(let error) = completion {
                        logError("获取健康度失败", error: error)
                    }
                },
                receiveValue: { [weak self] health in
                    self?.financialHealth = health
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 增强统计卡片
struct EnhancedStatCard: View {
    let title: String
    let amount: Decimal
    let change: Double?
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

                // 环比变化
                if let change = change {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(String(format: "%.1f", abs(change)))%")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(change >= 0 ? Theme.expense : Theme.income)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((change >= 0 ? Theme.expense : Theme.income).opacity(0.1))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(AppFont.monoNumber(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - 储蓄率卡片
struct SavingsRateCard: View {
    let rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.bambooGreen.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "percent")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.bambooGreen)
                }
                Spacer()

                Text(rateStatus)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(rateColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(rateColor.opacity(0.1)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("储蓄率")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                Text("\(String(format: "%.1f", rate))%")
                    .font(AppFont.monoNumber(size: 18, weight: .bold))
                    .foregroundColor(rateColor)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: Theme.cfoShadow, radius: 10, x: 0, y: 5)
    }

    private var rateColor: Color {
        if rate >= 30 { return .green }
        else if rate >= 20 { return .blue }
        else if rate >= 10 { return .orange }
        else { return .red }
    }

    private var rateStatus: String {
        if rate >= 30 { return "优秀" }
        else if rate >= 20 { return "良好" }
        else if rate >= 10 { return "一般" }
        else { return "需改善" }
    }
}

// MARK: - 汇总项
struct SummaryItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - 收入卡片
struct IncomeCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Text("¥\(formatAmount(amount))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }
}

// MARK: - 收入项行
struct IncomeItemRow: View {
    let item: IncomeAnalysisItem

    var body: some View {
        HStack {
            // 图标和名称
            HStack(spacing: 8) {
                Text(CategoryMapper.icon(for: item.category))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(CategoryMapper.displayName(for: item.category))
                        .font(.subheadline)

                    if item.isFixed {
                        Text("固定收入")
                            .font(.caption2)
                            .foregroundColor(Theme.bambooGreen)
                    }
                }
            }

            Spacer()

            // 金额和占比
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(formatAmount(item.amount))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text("\(String(format: "%.1f", item.percent))%")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }
}

// MARK: - 健康度指标行
struct HealthMetricRow: View {
    let title: String
    let value: String
    let score: Double
    let status: HealthStatus
    let suggestion: String

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(Theme.text)

                    Spacer()

                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(statusColor)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
                .background(Theme.cardBackground)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.separator)
                                .frame(height: 6)

                            Capsule()
                                .fill(statusColor)
                                .frame(width: geo.size.width * min(score / 100, 1), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(Theme.cardBackground)
            }
        }
        .cornerRadius(CornerRadius.small)
    }

    private var statusColor: Color {
        switch status {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
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
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Text(CategoryMapper.icon(for: category))
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(CategoryMapper.displayName(for: category))
                        .font(AppFont.body(size: 15, weight: .medium))
                    Spacer()
                    Text("¥\(amount as NSDecimalNumber, formatter: currencyFormatter)")
                        .font(AppFont.monoNumber(size: 15, weight: .bold))
                }

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

// MARK: - 标签按钮
struct TabButton: View {
    let tab: StatisticsView.StatisticsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.bambooGreen : Theme.cardBackground)
                )
        }
    }
}

#Preview {
    NavigationView {
        StatisticsView()
    }
}
