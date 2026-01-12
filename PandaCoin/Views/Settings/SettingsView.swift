//
//  SettingsView.swift
//  PandaCoin
//
//  Created by kevin on 2025/12/7.
//

import SwiftUI
import AuthenticationServices
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var authService = AuthService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var currencyService = CurrencyService.shared
    @State private var showLanguagePicker = false
    @State private var showCurrencyPicker = false
    @State private var showDeleteAccountAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    // 需要登录的功能导航
    @State private var showAutoPayment = false
    @State private var showAutoIncome = false
    @State private var showLoginRequired = false
    @State private var loginRequiredFeature = ""

    // 订阅相关
    @State private var showSubscription = false

    var body: some View {
        List {
            // MARK: - 个人资料头部
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.cardGradient)
                            .frame(width: 64, height: 64)
                        Text("🐼")
                            .font(.system(size: 32))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if authService.isAuthenticated {
                            HStack(spacing: 8) {
                                Text(authService.currentUser?.name ?? "私人财务官用户")
                                    .font(AppFont.body(size: 18, weight: .bold))

                                // Pro 会员标签
                                if subscriptionService.isProMember {
                                    if subscriptionService.isInTrialPeriod {
                                        // 试用期标签
                                        HStack(spacing: 2) {
                                            Image(systemName: "gift.fill")
                                                .font(.system(size: 10))
                                            Text("试用中")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                    } else {
                                        // 正式会员标签
                                        HStack(spacing: 2) {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 10))
                                            Text("PRO")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.orange, Color.yellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            Text(authService.currentUser?.email ?? "PandaCoin 专业版")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.bambooGreen)
                        } else {
                            Text("未登录")
                                .font(AppFont.body(size: 18, weight: .bold))
                            Text("登录后解锁全部功能")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // MARK: - 会员状态区域（仅登录后显示）
            if authService.isAuthenticated {
                Section("会员") {
                    if subscriptionService.isProMember {
                        // 已订阅 - 显示会员状态
                        ProMemberStatusView(subscriptionService: subscriptionService)
                    } else {
                        // 未订阅 - 显示升级入口
                        Button(action: { showSubscription = true }) {
                            HStack {
                                ZStack {
                                    Circle().fill(Color.orange.opacity(0.1)).frame(width: 30, height: 30)
                                    Image(systemName: "crown.fill").foregroundColor(.orange).font(.system(size: 14))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("升级 Pro 会员")
                                        .foregroundColor(Theme.text)
                                    Text("解锁全部功能")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                Text("首月免费")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(8)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                            }
                        }
                    }
                }
            }

            // MARK: - 登录区域（未登录时显示）
            if !authService.isAuthenticated {
                Section("账号") {
                    // Apple Sign In 按钮
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleSignIn
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(10)

                    // Debug 一键登录
                    #if DEBUG
                    Button(action: debugAutoLogin) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.orange.opacity(0.1)).frame(width: 30, height: 30)
                                Image(systemName: "hammer.fill").foregroundColor(.orange).font(.system(size: 14))
                            }
                            Text("[DEBUG] 一键登录")
                                .foregroundColor(Theme.text)
                            Spacer()
                            if isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoading)
                    #endif

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            // MARK: - 财务管理
            Section("财务管理") {
                Button(action: { requireAuth("自动扣款") { showAutoPayment = true } }) {
                    HStack {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "calendar.badge.clock").foregroundColor(.green).font(.system(size: 14))
                        }

                        Text("自动扣款")
                            .foregroundColor(Theme.text)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }

                Button(action: { requireAuth("自动入账") { showAutoIncome = true } }) {
                    HStack {
                        ZStack {
                            Circle().fill(Theme.income.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "arrow.down.circle").foregroundColor(Theme.income).font(.system(size: 14))
                        }

                        Text("自动入账")
                            .foregroundColor(Theme.text)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }
            }

            // MARK: - 偏好设置
            Section("偏好设置") {
                // 货币设置
                Button(action: { requireAuth("货币设置") { showCurrencyPicker = true } }) {
                    HStack {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "dollarsign.circle").foregroundColor(.green).font(.system(size: 14))
                        }

                        Text("基础货币")
                            .foregroundColor(Theme.text)

                        Spacer()

                        Text(currencyService.currentCurrencyInfo?.displayName ?? "CNY")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }

                // 语言设置
                Button(action: { showLanguagePicker = true }) {
                    HStack {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "globe").foregroundColor(.blue).font(.system(size: 14))
                        }

                        Text(L10n.Settings.language)
                            .foregroundColor(Theme.text)

                        Spacer()

                        Text(languageManager.currentLanguage.displayName)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }
            }

            // MARK: - 关于与支持
            Section("关于与支持") {
                HStack {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.1)).frame(width: 30, height: 30)
                        Image(systemName: "info.circle").foregroundColor(.orange).font(.system(size: 14))
                    }
                    Text(L10n.Settings.about)
                    Spacer()
                    Text("v1.0.0")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }

                HStack {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.1)).frame(width: 30, height: 30)
                        Image(systemName: "heart.fill").foregroundColor(.purple).font(.system(size: 14))
                    }
                    Text("评价我们")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
            }

            // MARK: - 账号操作（已登录时显示）
            if authService.isAuthenticated {
                Section("账号") {
                    // 删除账号
                    Button(action: { showDeleteAccountAlert = true }) {
                        HStack {
                            ZStack {
                                Circle().fill(Color.red.opacity(0.1)).frame(width: 30, height: 30)
                                Image(systemName: "trash").foregroundColor(.red).font(.system(size: 14))
                            }
                            Text("删除账号")
                                .foregroundColor(Theme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.textSecondary.opacity(0.5))
                        }
                    }
                }

                Section {
                    // 退出登录
                    Button(role: .destructive, action: {
                        authService.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text(L10n.Auth.logout)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.Settings.settings)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.Common.done) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(selectedLanguage: $languageManager.currentLanguage)
        }
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerView(currencyService: currencyService)
        }
        .sheet(isPresented: $showAutoPayment) {
            NavigationView {
                AutoPaymentListView()
            }
        }
        .sheet(isPresented: $showAutoIncome) {
            NavigationView {
                AutoIncomeListView()
            }
        }
        .sheet(isPresented: $showLoginRequired) {
            LoginRequiredView(featureName: loginRequiredFeature)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .alert("删除账号", isPresented: $showDeleteAccountAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("删除账号后，所有数据将被永久删除且无法恢复。确定要删除吗？")
        }
    }

    // MARK: - 登录检查辅助函数
    private func requireAuth(_ feature: String, action: @escaping () -> Void) {
        if authService.isAuthenticated {
            action()
        } else {
            loginRequiredFeature = feature
            showLoginRequired = true
        }
    }

    // MARK: - Apple Sign In Handler
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "无法获取 Apple 登录凭证"
                return
            }

            let appleUserId = appleIDCredential.user
            let email = appleIDCredential.email
            var fullName: String? = nil
            if let nameComponents = appleIDCredential.fullName {
                let parts = [nameComponents.familyName, nameComponents.givenName].compactMap { $0 }
                if !parts.isEmpty {
                    fullName = parts.joined(separator: "")
                }
            }

            isLoading = true
            errorMessage = nil

            authService.appleLogin(
                identityToken: identityToken,
                appleUserId: appleUserId,
                email: email,
                fullName: fullName
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    // 登录成功，AuthService 会自动更新状态
                }
            )
            .store(in: &cancellables)

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple 登录失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Debug Auto Login
    #if DEBUG
    private func debugAutoLogin() {
        isLoading = true
        errorMessage = nil

        authService.login(
            email: DebugConfig.TestAccount.email,
            password: DebugConfig.TestAccount.password
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            },
            receiveValue: { _ in
                // 登录成功
            }
        )
        .store(in: &cancellables)
    }
    #endif

    // MARK: - Delete Account
    private func deleteAccount() {
        isLoading = true

        authService.deleteAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    // 账号已删除，AuthService 会自动登出
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - 语言选择器视图
struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: AppLanguage

    var body: some View {
        NavigationView {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button(action: {
                        selectedLanguage = language
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.displayName)
                                    .foregroundColor(Theme.text)

                                if language != .system {
                                    Text(language.localizedName)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }

                            Spacer()

                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Settings.language)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 货币选择器视图
struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var currencyService: CurrencyService
    @State private var selectedCurrency: String = "CNY"

    var body: some View {
        NavigationView {
            List {
                ForEach(CurrencyInfo.supportedCurrencies) { currency in
                    Button(action: {
                        selectedCurrency = currency.code
                        currencyService.setBaseCurrency(currency.code)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(currency.symbol)
                                        .font(.title2)
                                        .frame(width: 30)

                                    VStack(alignment: .leading) {
                                        Text(currency.nameCn)
                                            .foregroundColor(Theme.text)
                                        Text(currency.code)
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }

                            Spacer()

                            if currencyService.baseCurrency == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择基础货币")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedCurrency = currencyService.baseCurrency
                // 加载用户货币设置
                if currencyService.userSettings == nil {
                    currencyService.loadUserSettings()
                }
            }
        }
    }
}

#Preview("设置页面 - CFO 风格") {
    NavigationView {
        SettingsView()
    }
}
