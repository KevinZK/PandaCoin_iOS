//
//  DashboardView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine
import Charts

// MARK: - 首页仪表盘（重新设计）
struct DashboardView: View {
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var accountService = AccountService()
    @StateObject private var recordService = RecordService()
    @StateObject private var authService = AuthService.shared
    
    @State private var totalAssets: Decimal = 0
    @State private var showVoiceConfirmation = false
    @State private var parsedRecords: [AIRecordParsed] = []
    @State private var chartData: [(String, Double)] = [
        ("12/10", 2300),
        ("12/11", 1800),
        ("12/12", 2500),
        ("12/13", 2100)
    ]
    
    // 导航状态
    @State private var showAccounts = false
    @State private var showRecords = false
    @State private var showStatistics = false
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // 动画渐变背景
            AnimatedGradientBackground()
                .ignoresSafeArea()
            ScrollView {
                
                VStack(spacing: 0) {
                    // 自定义导航栏
                    HStack {
                        Spacer()
                        
                        Menu {
                            Button(action: { showAccounts = true }) {
                                Label(L10n.TabBar.accounts, systemImage: "creditcard")
                            }
                            
                            Button(action: { showRecords = true }) {
                                Label(L10n.TabBar.records, systemImage: "list.bullet")
                            }
                            
                            Button(action: { showStatistics = true }) {
                                Label(L10n.TabBar.statistics, systemImage: "chart.pie")
                            }
                            
                            Divider()
                            
                            Button(action: { showSettings = true }) {
                                Label("设置", systemImage: "gearshape")
                            }
                            
                            Button(role: .destructive, action: {
                                authService.logout()
                            }) {
                                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 22))
                                .foregroundColor(.black.opacity(0.7))
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 总资产显示
                    totalAssetsSection
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    // 图表区域
                    chartSection
                        .padding(.horizontal, Spacing.large)
                    
                    Spacer()
                    
                    // 语音输入按钮
                    voiceButton
                        .padding(.bottom, 100)
                }
            }
            
        }
        .sheet(isPresented: $showVoiceConfirmation) {
            VoiceRecordConfirmationView(
                records: parsedRecords,
                onConfirm: { confirmedRecords in
                    saveRecords(confirmedRecords)
                }
            )
        }
        .sheet(isPresented: $showAccounts) {
            NavigationView {
                AccountsView()
            }
        }
        .sheet(isPresented: $showRecords) {
            NavigationView {
                RecordsListView()
            }
        }
        .sheet(isPresented: $showStatistics) {
            NavigationView {
                StatisticsView()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Text("设置页面")
                    .navigationTitle("设置")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                showSettings = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - 总资产区域
    private var totalAssetsSection: some View {
        VStack(spacing: Spacing.small) {
            Text(formatCurrency(totalAssets))
                .font(.system(size: 48, weight: .thin, design: .serif))
                .foregroundColor(.black.opacity(0.85))
            
            Text("Total Assets")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.5))
                .tracking(2)
        }
    }
    
    // MARK: - 图表区域
    private var chartSection: some View {
        VStack(spacing: Spacing.medium) {
            // 简单的收支趋势图
            Chart(chartData, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value("Amount", item.1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.6), .green.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Date", item.0),
                    y: .value("Amount", item.1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(Color.black.opacity(0.4))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 200)
            
            // 分页指示器
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == 0 ? Color.green.opacity(0.8) : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
    
    // MARK: - 语音按钮
    private var voiceButton: some View {
        VStack(spacing: Spacing.small) {
            // 熊猫语音按钮
            Button(action: {
                do {
                    try speechService.startRecording()
                } catch {
                    logError("语音识别启动失败", error: error)
                }
            }) {
                ZStack {
                    // 外圈阴影
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.gray.opacity(0.3),
                                    Color.gray.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                    
                    // 主按钮
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.4, blue: 0.4),
                                    Color(red: 0.5, green: 0.5, blue: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                    
                    // 熊猫图标
                    Text("🐼")
                        .font(.system(size: 50))
                }
            }
            
            Text("Voice Input")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.5))
                .tracking(1)
        }
    }
    
    // MARK: - 辅助方法
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let number = NSDecimalNumber(decimal: amount)
        if let formatted = formatter.string(from: number) {
            return "¥\(formatted)"
        }
        return "¥0.00"
    }
    
    private func loadData() {
        accountService.fetchAccounts()
        recordService.fetchRecords()
        
        // 计算总资产
        let total = accountService.accounts.reduce(0.0) { sum, account in
            sum + account.balance
        }
        totalAssets = Decimal(string: "\(total)") ?? 0
    }
    
    private func handleVoiceInput(_ text: String) {
        logInfo("语音输入: \(text)")
        
        // 使用模拟数据
        parsedRecords = mockParseVoice(text)
        showVoiceConfirmation = true
    }
    
    private func mockParseVoice(_ text: String) -> [AIRecordParsed] {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
            .compactMap { Decimal(string: $0) }
        
        if numbers.isEmpty {
            return []
        }
        
        return numbers.map { amount in
            AIRecordParsed(
                type: .expense,
                amount: amount,
                category: "餐饮",
                accountName: "支付宝",
                description: text,
                date: Date(),
                confidence: 0.95
            )
        }
    }
    
    private func saveRecords(_ records: [AIRecordParsed]) {
        showVoiceConfirmation = false
        logInfo("保存\(records.count)条记录")
        
        // TODO: 调用API保存记录
        loadData()
    }
}

#Preview {
    DashboardView()
}
