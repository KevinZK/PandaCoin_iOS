//
//  SubscriptionView.swift
//  PandaCoin
//
//  Pro 会员订阅页面（付费墙）
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedProduct: Product?
    @State private var isEligibleForTrial = false
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.05),
                        Color(red: 0.1, green: 0.15, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部图标和标题
                        headerSection

                        // Pro 会员权益
                        benefitsSection

                        // 订阅选项
                        if !subscriptionService.products.isEmpty {
                            subscriptionOptionsSection
                        } else if subscriptionService.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        } else if subscriptionService.errorMessage != nil {
                            // 加载失败提示
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                Text("无法加载订阅产品")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(subscriptionService.errorMessage ?? "")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                Button("重试") {
                                    Task {
                                        await subscriptionService.loadProducts()
                                    }
                                }
                                .foregroundColor(Theme.bambooGreen)
                                .padding(.top, 8)
                            }
                            .padding()
                        }

                        // 订阅按钮
                        if !subscriptionService.products.isEmpty {
                            subscribeButton
                        }

                        // 恢复购买和条款
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - 顶部标题
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pro 徽章
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .orange.opacity(0.5), radius: 20, x: 0, y: 10)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text("升级 Pro 会员")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            if isEligibleForTrial {
                Text("首月免费试用")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(20)
            }
        }
    }

    // MARK: - 权益列表
    private var benefitsSection: some View {
        VStack(spacing: 12) {
            benefitRow(icon: "mic.fill", title: "语音记账", description: "说话即可完成记账")
            benefitRow(icon: "camera.fill", title: "拍照记账", description: "拍摄票据自动识别")
            benefitRow(icon: "creditcard.fill", title: "资产管理", description: "全面管理您的资产")
            benefitRow(icon: "chart.pie.fill", title: "预算管理", description: "智能预算规划")
            benefitRow(icon: "arrow.triangle.2.circlepath", title: "自动记账", description: "自动还款与入账")
            benefitRow(icon: "chart.bar.fill", title: "完整统计", description: "深度财务分析报告")
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.bambooGreen.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.bambooGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Theme.bambooGreen)
        }
    }

    // MARK: - 订阅选项
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionService.products, id: \.id) { product in
                subscriptionOptionCard(product: product)
            }
        }
    }

    private func subscriptionOptionCard(product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isYearly = product.id == SubscriptionProduct.yearly.rawValue
        let trialText = subscriptionService.formattedTrialPeriod(for: product)

        return Button(action: { selectedProduct = product }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isYearly ? "年度会员" : "月度会员")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        if isYearly {
                            Text("省17%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    if let trial = trialText, isEligibleForTrial {
                        Text(trial)
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    } else {
                        Text(subscriptionService.formattedPeriod(for: product))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    if isYearly {
                        // 计算月均价格
                        let monthlyEquivalent = (product.price as NSDecimalNumber).doubleValue / 12
                        Text("约 ¥\(String(format: "%.1f", monthlyEquivalent))/月")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.bambooGreen.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Theme.bambooGreen : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 订阅按钮
    private var subscribeButton: some View {
        Button(action: purchase) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(subscribeButtonText)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Theme.bambooGreen, Theme.bambooGreen.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Theme.bambooGreen.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .opacity(selectedProduct == nil ? 0.6 : 1)
    }

    private var subscribeButtonText: String {
        if isEligibleForTrial {
            return "开始免费试用"
        } else if let product = selectedProduct {
            return "订阅 \(product.displayPrice)"
        } else {
            return "选择订阅方案"
        }
    }

    // MARK: - 底部链接
    private var footerSection: some View {
        VStack(spacing: 16) {
            // 恢复购买
            Button(action: restorePurchases) {
                Text("恢复购买")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
            }

            // 条款说明
            VStack(spacing: 8) {
                Text("订阅将自动续费，可随时在设置中取消")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button("服务条款") {
                        // TODO: 打开服务条款
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                    Button("隐私政策") {
                        // TODO: 打开隐私政策
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions
    private func loadData() async {
        if subscriptionService.products.isEmpty {
            await subscriptionService.loadProducts()
        }

        // 检查试用资格
        isEligibleForTrial = await subscriptionService.isEligibleForIntroOffer()

        // 默认选择年度订阅
        if selectedProduct == nil {
            selectedProduct = subscriptionService.yearlyProduct ?? subscriptionService.monthlyProduct
        }
    }

    private func purchase() {
        guard let product = selectedProduct else { return }

        isPurchasing = true

        Task {
            do {
                let success = try await subscriptionService.purchase(product)
                if success {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isPurchasing = false
        }
    }

    private func restorePurchases() {
        Task {
            await subscriptionService.restorePurchases()

            if subscriptionService.isProMember {
                dismiss()
            } else if let error = subscriptionService.errorMessage {
                errorMessage = error
                showError = true
            }
        }
    }
}

// MARK: - 会员状态视图（用于 Settings）
struct ProMemberStatusView: View {
    @ObservedObject var subscriptionService = SubscriptionService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)

                Text("Pro 会员")
                    .font(.headline)
                    .foregroundColor(Theme.text)

                Spacer()

                if subscriptionService.isInTrialPeriod {
                    Text("试用中")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                } else {
                    Text("已激活")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }

            if let expirationDate = subscriptionService.subscriptionStatus.expirationDate {
                Text("有效期至: \(formatDate(expirationDate))")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

#Preview {
    SubscriptionView()
}
