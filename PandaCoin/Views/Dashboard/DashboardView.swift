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
    @StateObject private var transactionService = TransactionService()
    @StateObject private var authService = AuthService.shared
    
    @State private var netWorthValue: Decimal = 0
    @State private var unifiedEventsWrapper: ParsedEventsWrapper? = nil
    @State private var chartData: [(String, Double)] = [
        ("12/10", 2300),
        ("12/11", 1800),
        ("12/12", 2500),
        ("12/13", 2100)
    ]
    @State private var breathingPhase = false
    @State private var breathingAnimationStarted = false
    
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
    
    // 记账模式：经典(语音按钮) vs 对话(聊天)
    @State private var isChatMode = false
    @State private var pageIndex: Int = 0  // 用于 TabView 的页面索引
    
    // 拍照相关状态
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var selectedImage: UIImage?
    @State private var chatModeImage: UIImage?  // 对话模式下传递给 ChatRecordView 的图片
    @State private var isProcessingImage = false
    private let ocrService = LocalOCRService.shared
    @State private var ocrCancellables = Set<AnyCancellable>()
    
    // AI 解析状态
    @State private var isAIParsing = false
    @State private var isParsingFromImage = false  // 标记 AI 解析是否来自图片
    
    var body: some View {
        ZStack {
            // 动画渐变背景
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏（只有菜单按钮，不再有 SegmentControl）
                topNavigationBarSimple
                
                // 左右滑动切换的两种模式
                TabView(selection: $pageIndex) {
                    // 经典模式（语音按钮）
                    classicModeContent
                        .tag(0)
                    
                    // 对话模式（聊天）
                    chatModeContent
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))  // 隐藏系统的 page indicator
                .onChange(of: pageIndex) { newValue in
                    isChatMode = newValue == 1
                }
                
                HStack {
                    // 左侧：拍照按钮
                    mediaButton(
                        icon: "camera.fill",
                        label: "",
                        action: { showingCamera = true }
                    )
                    Spacer()
                    // 底部 PageControl
                    pageControlView
                    Spacer()
                    // 右侧：相册按钮
                    mediaButton(
                        icon: "photo.on.rectangle",
                        label: "",
                        action: { showingPhotoLibrary = true }
                    )
                    
                }
                .padding(.horizontal, 16)
                
            }
        }
        // 相机
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker(selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        // 相册
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPicker(selectedImage: $selectedImage)
        }
        // 监听图片选择 - 根据当前模式决定处理方式
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                if pageIndex == 0 {
                    // 经典模式：在当前页面处理（弹出确认卡片）
                    processImageDirectly(image)
                } else {
                    // 对话模式：传递给 ChatRecordView 处理（在聊天中显示）
                    chatModeImage = image
                }
                selectedImage = nil
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
        .sheet(isPresented: $showAccounts, onDismiss: {
            // 资产页面关闭后刷新净资产数据
            loadData()
        }) {
            NavigationView {
                AssetsView()
            }
            .navigationViewStyle(.stack)
            .accentColor(Theme.bambooGreen)
        }
        .sheet(isPresented: $showRecords, onDismiss: {
            // 记录页面关闭后刷新数据
            loadData()
        }) {
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
        .sheet(isPresented: $showCreditCards, onDismiss: {
            // 信用卡页面关闭后刷新数据
            loadData()
        }) {
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
        .onReceive(transactionService.$netWorth) { netWorth in
            // 从后端获取完整的净资产数据
            if let nw = netWorth {
                netWorthValue = Decimal(nw.net_worth)
            }
        }
    }
    
    // MARK: - 简化的顶部导航栏（只有菜单按钮）
    private var topNavigationBarSimple: some View {
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
                Button(role: .destructive, action: { authService.logout() }) {
                    Label(L10n.Auth.logout, systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 经典模式内容（用于 TabView）
    private var classicModeContent: some View {
        VStack(spacing: 0) {
            // 总资产显示
            totalAssetsSection
                .padding(.top, 20)
            
            Spacer()
            
            // 图表区域
            chartSection
                .padding(.vertical, 20)
            
            // 语音按钮区域（含拍照和相册按钮）
            voiceButtonWithMedia
                .padding(.bottom, 60)
        }
    }
    
    // MARK: - AI 解析 Loading 提示（居中简洁样式）
    private var aiParsingLoadingView: some View {
        VStack(spacing: 8) {
            // 熊猫表情
            Text("🐼")
                .font(.system(size: 15))
            
            // Loading 指示器 + 文字
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.9)
                    .tint(Theme.bambooGreen)
                
                Text(parsingStatusText)
                    .font(AppFont.body(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
    
    // 解析状态文案
    private var parsingStatusText: String {
        if isProcessingImage {
            return "正在识别票据..."
        } else if isParsingFromImage {
            return "正在识别票据..."
        } else {
            return "正在理解你说的话..."
        }
    }
    
    // MARK: - 对话模式内容（用于 TabView）
    private var chatModeContent: some View {
        VStack(spacing: 0) {
            // 净资产（放大版）
            VStack(spacing: 4) {
                Text(formatCurrency(netWorthValue))
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(Theme.text)
                
                Text(L10n.Dashboard.netAssets)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .tracking(1)
            }
            .padding(.vertical, 16)
            
            // 聊天区域（占满剩余空间）
            ChatRecordView(externalImage: $chatModeImage)
        }
    }
    
    // MARK: - 底部 PageControl
    private var pageControlView: some View {
        HStack(spacing: 12) {
            // 语音模式指示点
            Circle()
                .fill(pageIndex == 0 ? Theme.bambooGreen : Theme.textSecondary.opacity(0.3))
                .frame(width: pageIndex == 0 ? 20 : 8, height: 8)
                .animation(.spring(response: 0.3), value: pageIndex)
            
            // 对话模式指示点
            Circle()
                .fill(pageIndex == 1 ? Theme.bambooGreen : Theme.textSecondary.opacity(0.3))
                .frame(width: pageIndex == 1 ? 20 : 8, height: 8)
                .animation(.spring(response: 0.3), value: pageIndex)
        }
        .padding(.vertical, 12)
        .padding(.bottom, 20)  // 底部安全区域
    }
    
    // MARK: - 净资产区域
    private var totalAssetsSection: some View {
        VStack(spacing: Spacing.small) {
            Text(formatCurrency(netWorthValue))
                .font(.system(size: 48, weight: .thin, design: .serif))
                .foregroundColor(Theme.text)
            
            Text(L10n.Dashboard.netAssets)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Theme.textSecondary)
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
                    .foregroundColor(Theme.textSecondary)
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
                        .foregroundColor(Theme.textSecondary)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - 语音按钮状态
    @State private var isButtonPressed = false
    @State private var waveScales: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var waveAnimating = false
    
    // MARK: - 语音按钮（重新设计）
    // MARK: - 语音按钮区域（含拍照和相册按钮）
    private var voiceButtonWithMedia: some View {
        HStack(spacing: 24) {
            // 中间：语音按钮
            voiceButton
        }
    }
    
    // MARK: - 媒体按钮（拍照/相册）
    private func mediaButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                ZStack {
                    // 玻璃背景
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(
                                    Theme.bambooGreen.opacity(0.3),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(
                            color: Theme.bambooGreen.opacity(0.15),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                    
                    // 图标
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.text.opacity(0.7))
                }
            }
            .disabled(isProcessingImage)
            .opacity(isProcessingImage ? 0.5 : 1.0)
            
            // 标签
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    // MARK: - 语音按钮
    private var voiceButton: some View {
        VStack(spacing: Spacing.medium) {
            // 主按钮区域
            ZStack {
                // 多层波浪向外扩散效果（录音时显示）
                if speechService.isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Theme.bambooGreen.opacity(0.5 - Double(index) * 0.1),
                                lineWidth: 3 - CGFloat(index) * 0.5
                            )
                            .frame(width: 88, height: 88)
                            .scaleEffect(waveScales[index])
                            .opacity(Double(2.2 - waveScales[index]))
                    }
                }
                
                // 按下时的光晕效果
                if isButtonPressed && !speechService.isRecording {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.bambooGreen.opacity(0.3),
                                    Theme.bambooGreen.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .transition(.opacity)
                }
                
                // 主按钮 - 毛玻璃效果
                ZStack {
                    // 玻璃背景
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Theme.bambooGreen.opacity(speechService.isRecording ? 0.8 : 0.4),
                                            Theme.bambooGreen.opacity(speechService.isRecording ? 0.6 : 0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: speechService.isRecording ? 3 : 2
                                )
                        )
                        .shadow(
                            color: Theme.bambooGreen.opacity(speechService.isRecording ? 0.5 : 0.2),
                            radius: speechService.isRecording ? 20 : 8,
                            x: 0,
                            y: 4
                        )
                    
                    // 内部填充（录音时高亮）
                    Circle()
                        .fill(
                            speechService.isRecording
                                ? Theme.bambooGreen.opacity(0.15)
                                : Color.clear
                        )
                        .frame(width: 84, height: 84)
                    
                    // 图标
                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(
                            speechService.isRecording
                                ? Theme.bambooGreen
                                : Theme.text.opacity(0.7)
                        )
                        .scaleEffect(speechService.isRecording ? 1.15 : 1.0)
                }
                .scaleEffect(isButtonPressed ? 0.92 : (speechService.isRecording ? 1.05 : 1.0))
            }
            .frame(width: 180, height: 180)
            .contentShape(Circle().scale(0.5))  // 缩小触摸区域，防止误触
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isButtonPressed else { return }
                        
                        // 触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.easeOut(duration: 0.15)) {
                            isButtonPressed = true
                        }
                        
                        // 延迟启动录音，防止误触
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            guard isButtonPressed, !speechService.isRecording else { return }
                            do {
                                try speechService.startRecording()
                                startWaveAnimation()
                                
                                // 开始录音的触觉反馈
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.success)
                            } catch {
                                logError("语音识别启动失败", error: error)
                                if let speechError = error as? SpeechRecognitionError {
                                    if speechError == .needsSettingsAuthorization {
                                        showSettingsAlert()
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isButtonPressed = false
                        }
                        
                        guard speechService.isRecording else { return }
                        
                        let recognizedText = speechService.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        speechService.stopRecording()
                        stopWaveAnimation()
                        
                        // 结束录音的触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        // 如果没有识别到文字，不发送请求
                        guard !recognizedText.isEmpty else {
                            logInfo("语音识别未检测到文字，跳过 AI 解析")
                            return
                        }
                        
                        handleVoiceInput(recognizedText)
                    }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: speechService.isRecording)
            .animation(.easeInOut(duration: 0.2), value: isButtonPressed)
            
            if isAIParsing || isProcessingImage {
                aiParsingLoadingView
            } else {
                // 提示文字
                VStack(spacing: 4) {
                    Text(speechService.isRecording ? "松开结束" : "长按说话")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(speechService.isRecording ? Theme.bambooGreen : Theme.text)
                    
                    if !speechService.isRecording {
                        Text("告诉我今天的收支")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
            }
        }
    }
    
    // 波浪扩散动画
    private func startWaveAnimation() {
        guard !waveAnimating else { return }
        waveAnimating = true
        
        // 重置波浪
        waveScales = [1.0, 1.0, 1.0]
        
        // 启动三层波浪，每层延迟启动形成层层扩散效果
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                guard self.waveAnimating else { return }
                withAnimation(
                    .easeOut(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    self.waveScales[i] = 2.2
                }
            }
        }
    }
    
    private func stopWaveAnimation() {
        waveAnimating = false
        withAnimation(.easeOut(duration: 0.2)) {
            waveScales = [1.0, 1.0, 1.0]
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
        transactionService.fetchNetWorth()
    }
    
    // MARK: - 直接处理图片（OCR + AI 解析）
    private func processImageDirectly(_ image: UIImage) {
        guard !isProcessingImage else { return }
        isProcessingImage = true
        
        // 进行本地 OCR 识别
        ocrService.recognizeText(from: image)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [self] completion in
                    isProcessingImage = false

                    if case .failure(let error) = completion {
                        logError("图片识别失败", error: error)
                    }
                },
                receiveValue: { [self] result in
                    // OCR 成功，构建文本发送给 AI
                    if !result.isValidReceipt {
                        // 不是有效票据，提示用户
                        logInfo("不是有效票据")
                        isProcessingImage = false
                        return
                    }

                    // 构建 AI 解析文本
                    var parseText = "【票据识别】"

                    if let amount = result.extractedInfo.amount {
                        parseText += " 金额¥\(amount)"
                    }
                    if let merchant = result.extractedInfo.merchant {
                        parseText += " 商家:\(merchant)"
                    }
                    if let paymentMethod = result.extractedInfo.paymentMethod {
                        parseText += " 支付方式:\(paymentMethod)"
                    }

                    // 附加原始文字（帮助 AI 理解）
                    parseText += "\n原文: \(result.rawText.prefix(500))"

                    logInfo("📷 票据OCR结果: \(parseText)")

                    // 标记来自图片，然后发送给 AI 解析
                    isParsingFromImage = true
                    handleVoiceInput(parseText)

                    // 清理图片处理状态（AI 解析状态由 handleVoiceInput 管理）
                    isProcessingImage = false
                }
            )
            .store(in: &ocrCancellables)
    }
    
    private func handleVoiceInput(_ text: String) {
        logInfo("语音输入: \(text)")
        
        // 显示 loading
        isAIParsing = true
        
        // 调用后端 AI 统一解析接口（支持多种事件类型）
        recordService.parseVoiceInputUnified(text: text)
            .receive(on: DispatchQueue.main)
            .sink { [self] completion in
                // 隐藏 loading
                isAIParsing = false
                isParsingFromImage = false  // 重置图片来源标记
                
                if case .failure(let error) = completion {
                    logError("AI 解析失败", error: error)
                }
            } receiveValue: { [self] events in
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
        
        // 统一保存所有事件（传入 accountService 和 authService 以便刷新账户映射和使用默认账户）
        recordService.saveFinancialEvents(events, accountMap: accountMap, assetService: accountService, authService: authService)
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
