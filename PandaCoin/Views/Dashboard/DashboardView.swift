//
//  DashboardView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine
#if canImport(Charts)
import Charts
#endif

// MARK: - 统一事件包装器
struct ParsedEventsWrapper: Identifiable {
    let id = UUID()
    let events: [ParsedFinancialEvent]
}

// MARK: - 首页仪表盘（重新设计）
struct DashboardView: View {
    @StateObject private var speechService = SpeechRecognitionService()
    @ObservedObject private var accountService = AssetService.shared
    @StateObject private var recordService = RecordService()
    @StateObject private var authService = AuthService.shared
    
    @State private var totalAssets: Decimal = 0
    @State private var unifiedEventsWrapper: ParsedEventsWrapper? = nil
    @State private var chartData: [(String, Double)] = [
        ("12/10", 2300),
        ("12/11", 1800),
        ("12/12", 2500),
        ("12/13", 2100)
    ]
    @State private var breathingPhase = false
    @State private var breathingAnimationStarted = false
    @State private var wavePhases: [CGFloat] = [1.0, 1.0, 1.0]
    
    private var indexedChartData: [(index: Int, label: String, value: Double)] {
        chartData.enumerated().map { (index, element) in
            (index: index, label: element.0, value: element.1)
        }
    }
    
    private let maxVisiblePoints: Int = 6
    
    private var displayedChartData: [(index: Int, label: String, value: Double)] {
        guard indexedChartData.count > maxVisiblePoints else {
            return indexedChartData
        }
        return Array(indexedChartData.suffix(maxVisiblePoints))
    }
    
    private var extendedChartData: [(index: Double, label: String, value: Double)] {
        guard let first = displayedChartData.first, let last = displayedChartData.last else { return [] }
        
        var data = displayedChartData.map { (index: Double($0.index), label: $0.label, value: $0.value) }
        
        // 在首尾添加额外的数据点，用于延伸线条
        // 使用 -0.5 和 count-0.5 作为延伸点，配合 Domain 设置实现全屏效果
        // 值保持与首尾点一致，形成平滑延伸
        data.insert((index: Double(first.index) - 0.5, label: "", value: first.value), at: 0)
        data.append((index: Double(last.index) + 0.5, label: "", value: last.value))
        
        return data
    }
    
    private var chartDomain: ClosedRange<Double> {
        guard let minIndex = displayedChartData.map({ $0.index }).min(),
              let maxIndex = displayedChartData.map({ $0.index }).max() else {
            return 0...1
        }
        
        // 扩大 Domain 范围，使实际数据点向内收缩，留出 breathing space
        // 0.5 的偏移量对应延伸数据点的位置
        return (Double(minIndex) - 0.5)...(Double(maxIndex) + 0.5)
    }
    
    // 导航状态
    @State private var showAccounts = false
    @State private var showRecords = false
    @State private var showStatistics = false
    @State private var showBudget = false
    @State private var showCreditCards = false
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
                            
                            Button(action: { showCreditCards = true }) {
                                Label("信用卡", systemImage: "creditcard.fill")
                            }
                            
                            Button(action: { showRecords = true }) {
                                Label(L10n.TabBar.records, systemImage: "list.bullet")
                            }
                            
                            Button(action: { showStatistics = true }) {
                                Label(L10n.TabBar.statistics, systemImage: "chart.pie")
                            }
                            
                            Button(action: { showBudget = true }) {
                                Label(L10n.TabBar.budget, systemImage: "chart.bar.doc.horizontal")
                            }
                            
                            Divider()
                            
                            Button(action: { showSettings = true }) {
                                Label(L10n.TabBar.settings, systemImage: "gearshape")
                            }
                            
                            Button(role: .destructive, action: {
                                authService.logout()
                            }) {
                                Label(L10n.Auth.logout, systemImage: "rectangle.portrait.and.arrow.right")
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
                    
                    Spacer()
                    
                    // 语音输入按钮
                    voiceButton
                        .padding(.bottom, 100)
                }
            }
            
        }
        .sheet(item: $unifiedEventsWrapper) { wrapper in
            UnifiedConfirmationView(
                events: wrapper.events,
                onConfirm: { confirmedEvents in
                    saveUnifiedEvents(confirmedEvents)
                }
            )
        }
        .sheet(isPresented: $showAccounts) {
            NavigationView {
                AssetsView()
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
        .sheet(isPresented: $showBudget) {
            NavigationView {
                BudgetView()
            }
        }
        .sheet(isPresented: $showCreditCards) {
            NavigationView {
                CreditCardListView()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsView()
            }
        }
        .onAppear {
            loadData()
            startBreathingAnimation()
        }
        .onReceive(accountService.$accounts) { accounts in
            // 账户数据加载完成后计算总资产
            let total = accounts.reduce(Decimal(0)) { $0 + $1.balance }
            totalAssets = total
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
            if displayedChartData.isEmpty {
                Text("暂无数据")
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.gray)
            } else {
                if #available(iOS 16.0, *) {
                    Chart {
                        // 线条和区域使用扩展数据源（包含延伸点）
                        ForEach(extendedChartData, id: \.index) { item in
                            LineMark(
                                x: .value("Index", item.index),
                                y: .value("Amount", item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green.opacity(0.8), .green.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Index", item.index),
                                y: .value("Amount", item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                        
                        // 数据点和标签只使用真实数据源
                        ForEach(displayedChartData, id: \.index) { item in
                            PointMark(
                                x: .value("Index", Double(item.index)),
                                y: .value("Amount", item.value)
                            )
                            .symbol {
                                ZStack {
                                    // 呼吸光晕
                                    Circle()
                                        .fill(Theme.income.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .scaleEffect(breathingPhase ? 1.2 : 0.8)
                                        .opacity(breathingPhase ? 1.0 : 0.5)
                                    
                                    // 实心点
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 12, height: 12)
                                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                                        .overlay(
                                            Circle()
                                                .stroke(Theme.income, lineWidth: 2)
                                        )
                                }
                            }
                            .annotation(position: .bottom, alignment: .center, spacing: 10) {
                                Text(formatChartAmount(item.value))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.income)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: Theme.income.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartXScale(domain: chartDomain)
                    .chartPlotStyle { plotArea in
                        plotArea
                            .frame(height: 220)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("图表功能需要 iOS 16.0 或更高版本")
                        .foregroundColor(.gray)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                }
            }
            
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
            ZStack {
                // 波浪动画（录音时显示）
                if speechService.isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.6),
                                        Color.green.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(wavePhases[index])
                            .opacity(2.5 - wavePhases[index])
                            .animation(
                                Animation.easeOut(duration: 1.2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.2),
                                value: wavePhases[index]
                            )
                    }
                }
                
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
                            colors: speechService.isRecording ? [
                                Color.green.opacity(0.8),
                                Color.green.opacity(0.6)
                            ] : [
                                Color(red: 0.4, green: 0.4, blue: 0.4),
                                Color(red: 0.5, green: 0.5, blue: 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                    .scaleEffect(speechService.isRecording ? 1.05 : 1.0)
                
                // 熊猫图标
                Text("🐼")
                    .font(.system(size: 50))
                    .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
            }
            .id("voice_button")  // 添加稳定ID
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 5.0, perform: {
                print("✅ 长按完成！")
            }, onPressingChanged: { isPressing in
                if isPressing {
                    guard !speechService.isRecording else { return }
                    do {
                        try speechService.startRecording()
                        startWaveAnimation()
                    } catch {
                        logError("语音识别启动失败", error: error)
                        if let speechError = error as? SpeechRecognitionError {
                            if speechError == .needsSettingsAuthorization {
                                showSettingsAlert()
                            }
                        }
                    }
                } else {
                    print("长按结束")
                    guard speechService.isRecording else { return }
                    
                    let recognizedText = speechService.recognizedText
                    speechService.stopRecording()
                    stopWaveAnimation()
                    handleVoiceInput(recognizedText)
                }
            })
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speechService.isRecording)
            
            Text(speechService.isRecording ? "Recording..." : "Voice Input")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.5))
                .tracking(1)
        }
    }
    
    // MARK: - 辅助方法
    private func startBreathingAnimation() {
        guard !breathingAnimationStarted else { return }
        breathingAnimationStarted = true
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            breathingPhase.toggle()
        }
    }
    
    private func startWaveAnimation() {
        // 重置所有波浪
        wavePhases = [1.0, 1.0, 1.0]
        
        // 延迟启动动画，确保视图已渲染
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 0..<3 {
                self.wavePhases[i] = 2.0
            }
        }
    }
    
    private func stopWaveAnimation() {
        for i in 0..<3 {
            wavePhases[i] = 1.0
        }
    }
    
    private func showSettingsAlert() {
        // TODO: 显示设置提醒
        logInfo("需要在设置中打开语音识别权限")
    }
    
    private func formatChartAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        
        let number = NSNumber(value: value)
        let formatted = formatter.string(from: number) ?? "\(Int(value))"
        return "¥\(formatted)"
    }
    
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
    }
    
    private func handleVoiceInput(_ text: String) {
        logInfo("语音输入: \(text)")
        
        // 调用后端 AI 统一解析接口（支持多种事件类型）
        recordService.parseVoiceInputUnified(text: text)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    logError("AI 解析失败", error: error)
                }
            } receiveValue: { events in
                logInfo("设置 unifiedEventsWrapper: \(events.count)条事件")
                if !events.isEmpty {
                    self.unifiedEventsWrapper = ParsedEventsWrapper(events: events)
                }
            }
            .store(in: &recordService.cancellables)
    }
    
    // MARK: - 统一保存事件（支持多类型）
    private func saveUnifiedEvents(_ events: [ParsedFinancialEvent]) {
        unifiedEventsWrapper = nil
        logInfo("用户确认保存\(events.count)条事件")
        
        // 构建账户名称到ID的映射
        var accountMap: [String: String] = [:]
        for account in accountService.accounts {
            accountMap[account.name] = account.id
        }
        
        // 调试日志
        logInfo("📊 账户映射: \(accountMap.keys.joined(separator: ", "))")
        for event in events {
            logInfo("📌 事件类型: \(event.eventType.rawValue)")
        }
        
        // 统一保存所有事件
        recordService.saveFinancialEvents(events, accountMap: accountMap)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    logError("保存事件失败", error: error)
                }
            } receiveValue: { count in
                logInfo("✅ 成功保存\(count)条事件")
                self.loadData()
            }
            .store(in: &recordService.cancellables)
    }
}

#Preview {
    DashboardView()
}
