//
//  DashboardView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine
import PhotosUI

// MARK: - 首页仪表盘
struct DashboardView: View {
    @ObservedObject private var accountService = AssetService.shared
    @StateObject private var transactionService = TransactionService()
    @StateObject private var authService = AuthService.shared

    @State private var netWorthValue: Decimal = 0

    // 导航状态
    @State private var showAccounts = false
    @State private var showRecords = false
    @State private var showStatistics = false
    @State private var showBudget = false
    @State private var showCreditCards = false
    @State private var showSettings = false

    // 登录/订阅提示
    @State private var showLoginRequired = false
    @State private var showSubscription = false
    @State private var loginRequiredFeature = ""
    @StateObject private var subscriptionService = SubscriptionService.shared

    // 键盘输入栏显示状态
    @State private var showInputBar = false
    // 语音录音状态
    @State private var isRecording = false

    // 拍照相关状态
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var chatModeImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        ZStack {
            // 动画渐变背景
            AnimatedGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏
                topNavigationBarSimple

                // 对话模式内容
                chatModeContent

                // 底部功能按钮栏
                bottomActionBar
            }
        }
        // 相机
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker(selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        // 监听相册选择 - 使用纯 SwiftUI PhotosPicker
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            }
        }
        // 监听图片选择 - 传递给 ChatRecordView 处理
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                chatModeImage = image
                selectedImage = nil
            }
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
        .sheet(isPresented: $showLoginRequired) {
            LoginRequiredView(featureName: loginRequiredFeature)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .onAppear {
            loadData()
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // 用户登录后自动加载数据
                loadData()
            } else {
                // 用户登出后清空数据
                netWorthValue = 0
            }
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
                Button(action: { requireAuth("资产管理") { showAccounts = true } }) {
                    Label(L10n.TabBar.accounts, systemImage: "creditcard")
                }
                Button(action: { requireAuth("信用卡") { showCreditCards = true } }) {
                    Label("信用卡", systemImage: "creditcard.fill")
                }
                Button(action: { requireAuth("账单记录") { showRecords = true } }) {
                    Label(L10n.TabBar.records, systemImage: "list.bullet")
                }
                Button(action: { showStatistics = true }) {
                    Label(L10n.TabBar.statistics, systemImage: "chart.pie")
                }
                Button(action: { requireAuth("预算管理") { showBudget = true } }) {
                    Label(L10n.TabBar.budget, systemImage: "chart.bar.doc.horizontal")
                }
                Divider()
                Button(action: { showSettings = true }) {
                    Label(L10n.TabBar.settings, systemImage: "gearshape")
                }
                if authService.isAuthenticated {
                    Button(role: .destructive, action: { authService.logout() }) {
                        Label(L10n.Auth.logout, systemImage: "rectangle.portrait.and.arrow.right")
                    }
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

    // MARK: - 权限检查辅助函数（登录 + 订阅）
    private func requireAuth(_ feature: String, action: @escaping () -> Void) {
        // 首先检查是否登录
        guard authService.isAuthenticated else {
            loginRequiredFeature = feature
            showLoginRequired = true
            return
        }

        // 然后检查是否为 Pro 会员
        guard subscriptionService.isProMember else {
            showSubscription = true
            return
        }

        action()
    }
    
    // MARK: - 对话模式内容
    private var chatModeContent: some View {
        VStack(spacing: 0) {
            // 净资产显示
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

            // 聊天区域
            ChatRecordView(externalImage: $chatModeImage, showInputBar: $showInputBar, isRecording: $isRecording)
        }
    }

    // MARK: - 底部功能按钮栏
    private var bottomActionBar: some View {
        HStack(spacing: 0) {
            // 拍照按钮
            actionButton(icon: "camera.fill", isActive: false) {
                requireAuth("拍照记账") { showingCamera = true }
            }

            Spacer()

            // 语音按钮（带波浪动画）
            VoiceActionButton(isRecording: $isRecording, onTap: {
                if !authService.isAuthenticated {
                    loginRequiredFeature = "语音记账"
                    showLoginRequired = true
                } else if !subscriptionService.isProMember {
                    showSubscription = true
                }
            })

            Spacer()

            // 键盘按钮
            actionButton(icon: showInputBar ? "keyboard.chevron.compact.down" : "keyboard", isActive: showInputBar) {
                requireAuth("键盘记账") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showInputBar.toggle()
                    }
                }
            }

            Spacer()

            // 相册按钮 - 使用纯 SwiftUI PhotosPicker
            if authService.isAuthenticated && subscriptionService.isProMember {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Theme.bambooGreen.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Theme.bambooGreen.opacity(0.1), radius: 4, x: 0, y: 2)

                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.text.opacity(0.7))
                    }
                }
            } else {
                actionButton(icon: "photo.on.rectangle", isActive: false) {
                    if !authService.isAuthenticated {
                        loginRequiredFeature = "图片记账"
                        showLoginRequired = true
                    } else {
                        showSubscription = true
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .padding(.bottom, 16)
    }

    // MARK: - 功能按钮
    @ViewBuilder
    private func actionButton(icon: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Theme.bambooGreen.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Theme.bambooGreen, lineWidth: 2)
                        )
                        .shadow(color: Theme.bambooGreen.opacity(0.3), radius: 8, x: 0, y: 3)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Theme.bambooGreen.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: Theme.bambooGreen.opacity(0.15), radius: 6, x: 0, y: 3)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isActive ? Theme.bambooGreen : Theme.text.opacity(0.7))
            }
        }
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
        // 只有登录后才加载数据
        guard authService.isAuthenticated else { return }
        accountService.fetchAccounts()
        transactionService.fetchNetWorth()
    }
}

// MARK: - 语音按钮（带波浪动画）
struct VoiceActionButton: View {
    @Binding var isRecording: Bool
    var onTap: (() -> Void)? = nil  // 点击前的回调（用于登录检查）

    @State private var waveScales: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var isAnimating = false
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    var body: some View {
        ZStack {
            // 多层波浪效果（录音时）
            if isRecording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            Theme.bambooGreen.opacity(0.4 - Double(index) * 0.1),
                            lineWidth: 2
                        )
                        .frame(width: 50, height: 50)
                        .scaleEffect(waveScales[index])
                        .opacity(Double(2.0 - waveScales[index]))
                }
            }

            // 主按钮
            Button(action: toggleRecording) {
                ZStack {
                    if isRecording {
                        Circle()
                            .fill(Theme.expense)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Theme.expense, lineWidth: 2)
                            )
                            .shadow(color: Theme.expense.opacity(0.4), radius: 10, x: 0, y: 3)
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Theme.bambooGreen.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: Theme.bambooGreen.opacity(0.15), radius: 6, x: 0, y: 3)
                    }

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isRecording ? .white : Theme.text.opacity(0.7))
                }
            }
            .scaleEffect(isRecording ? 1.05 : 1.0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        .onChange(of: isRecording) { newValue in
            if newValue {
                startWaveAnimation()
            } else {
                stopWaveAnimation()
            }
        }
    }

    private func toggleRecording() {
        // 未登录或未订阅时点击，触发检查回调
        if !isRecording && (!authService.isAuthenticated || !subscriptionService.isProMember) {
            onTap?()
            return
        }

        let impactFeedback = UIImpactFeedbackGenerator(style: isRecording ? .light : .medium)
        impactFeedback.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isRecording.toggle()
        }
    }

    private func startWaveAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        waveScales = [1.0, 1.0, 1.0]

        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                guard self.isAnimating else { return }
                withAnimation(
                    .easeOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
                ) {
                    self.waveScales[i] = 1.8
                }
            }
        }
    }

    private func stopWaveAnimation() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.2)) {
            waveScales = [1.0, 1.0, 1.0]
        }
    }
}

#Preview {
    DashboardView()
}
