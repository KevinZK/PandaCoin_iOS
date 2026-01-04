//
//  SubscriptionService.swift
//  PandaCoin
//
//  订阅管理服务 - 使用 StoreKit 2
//

import Foundation
import StoreKit
import Combine

// MARK: - 订阅产品 ID
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.finboo.pay1"
    case yearly = "com.finboo.pay2"

    var displayName: String {
        switch self {
        case .monthly: return "月度会员"
        case .yearly: return "年度会员"
        }
    }
}

// MARK: - 订阅状态
struct SubscriptionStatus {
    let isActive: Bool
    let productId: String?
    let expirationDate: Date?
    let isInTrialPeriod: Bool
    let willAutoRenew: Bool
    let source: SubscriptionSource  // 订阅来源

    enum SubscriptionSource {
        case none
        case apple      // 来自 Apple StoreKit
        case backend    // 来自后端（管理员设置）
    }

    static let inactive = SubscriptionStatus(
        isActive: false,
        productId: nil,
        expirationDate: nil,
        isInTrialPeriod: false,
        willAutoRenew: false,
        source: .none
    )
}

// MARK: - 订阅服务
@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // 订阅组 ID（需要在 App Store Connect 中配置）
    static let subscriptionGroupId = "com.finboo.pro"

    // 产品 ID 列表
    private let productIds: [String] = SubscriptionProduct.allCases.map { $0.rawValue }

    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionStatus: SubscriptionStatus = .inactive
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isStatusLoaded: Bool = false  // 订阅状态是否已加载完成

    // MARK: - Computed Properties

    /// 是否为 Pro 会员
    var isProMember: Bool {
        subscriptionStatus.isActive
    }

    /// 是否在试用期
    var isInTrialPeriod: Bool {
        subscriptionStatus.isInTrialPeriod
    }

    /// 等待订阅状态加载完成（最多等待 3 秒）
    func waitForStatusLoaded() async {
        if isStatusLoaded { return }

        // 最多等待 3 秒
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            if isStatusLoaded { return }
        }
        print("⚠️ [Subscription] 等待状态加载超时")
    }

    /// 从用户数据同步订阅状态（由 AuthService 调用）
    func syncFromUserData(isProMember: Bool, isInTrialPeriod: Bool) {
        print("🔄 [Subscription] 从用户数据同步: isProMember=\(isProMember), isInTrialPeriod=\(isInTrialPeriod)")

        if isProMember {
            subscriptionStatus = SubscriptionStatus(
                isActive: true,
                productId: nil,
                expirationDate: nil,
                isInTrialPeriod: isInTrialPeriod,
                willAutoRenew: true,
                source: .backend
            )
        } else {
            subscriptionStatus = .inactive
        }

        isStatusLoaded = true
        print("✅ [Subscription] 状态同步完成: isProMember=\(self.isProMember)")
    }

    /// 月度产品
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthly.rawValue }
    }

    /// 年度产品
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.yearly.rawValue }
    }

    // MARK: - Transaction Updates Listener
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization
    private init() {
        // 启动交易监听
        updateListenerTask = listenForTransactions()

        // 初始加载
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 监听交易更新
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.verifyAndFinish(result)
                    await transaction?.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // 在主线程验证交易
    private func verifyAndFinish(_ result: VerificationResult<Transaction>) async throws -> Transaction? {
        let transaction = try checkVerified(result)
        await updateSubscriptionStatus()
        return transaction
    }

    // MARK: - 加载产品
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: productIds)
            // 按价格排序（月度在前）
            products = storeProducts.sorted { $0.price < $1.price }
            print("Loaded \(products.count) products: \(products.map { $0.id })")

            if products.isEmpty {
                errorMessage = "未找到订阅产品，请确保已在 App Store Connect 配置产品 ID: \(productIds.joined(separator: ", "))"
            }
        } catch {
            errorMessage = "无法加载产品信息: \(error.localizedDescription)"
            print("Failed to load products: \(error)")
        }

        isLoading = false
    }

    // MARK: - 更新订阅状态（检查 Apple 订阅并同步）
    func updateSubscriptionStatus() async {
        print("🔍 [Subscription] 开始检查订阅状态...")

        // 检查 Apple StoreKit 订阅并同步到后端
        await syncAppleSubscriptionsToBackend()

        // 刷新用户数据获取最新订阅状态（订阅状态现在通过用户数据返回）
        AuthService.shared.fetchCurrentUser()

        print("✅ [Subscription] 订阅状态检查完成")
    }

    // MARK: - 同步订阅到后端
    private func syncSubscriptionToBackend(productId: String, transactionId: String, isInTrial: Bool, expirationDate: Date) async {
        guard let token = NetworkManager.shared.accessToken else {
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/subscription/sync-apple") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "appleProductId": productId,
            "appleTransactionId": transactionId,
            "isInTrial": isInTrial,
            "expirationDate": ISO8601DateFormatter().string(from: expirationDate)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📤 [Subscription] 同步到后端: status=\(httpResponse.statusCode)")
            }
        } catch {
            print("❌ [Subscription] 同步到后端失败: \(error)")
        }
    }

    // MARK: - 购买订阅
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // 同步订阅到后端
                if let expirationDate = transaction.expirationDate {
                    let isInTrial = transaction.offerType == .introductory
                    await syncSubscriptionToBackend(
                        productId: transaction.productID,
                        transactionId: String(transaction.id),
                        isInTrial: isInTrial,
                        expirationDate: expirationDate
                    )
                }

                // 刷新用户数据（会自动同步订阅状态）
                AuthService.shared.fetchCurrentUser()

                await transaction.finish()
                isLoading = false
                return true

            case .pending:
                errorMessage = "购买正在处理中，请稍后查看"
                isLoading = false
                return false

            case .userCancelled:
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "购买失败: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }

    // MARK: - 检查免费试用资格
    func isEligibleForIntroOffer() async -> Bool {
        // 检查用户是否有资格获得介绍性优惠（免费试用）
        guard let product = monthlyProduct ?? yearlyProduct,
              let subscription = product.subscription else {
            return false
        }

        return await subscription.isEligibleForIntroOffer
    }

    // MARK: - 获取产品的介绍性优惠
    func introductoryOffer(for product: Product) -> Product.SubscriptionOffer? {
        product.subscription?.introductoryOffer
    }

    // MARK: - 恢复购买
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()

            // 检查 Apple 订阅并同步到后端
            await syncAppleSubscriptionsToBackend()

            // 刷新用户数据获取最新订阅状态
            AuthService.shared.fetchCurrentUser()

            // 等待一下让用户数据刷新
            try? await Task.sleep(nanoseconds: 500_000_000)

            if !isProMember {
                errorMessage = "未找到可恢复的订阅"
            }
        } catch {
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 同步 Apple 订阅到后端
    private func syncAppleSubscriptionsToBackend() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if productIds.contains(transaction.productID),
                   let expirationDate = transaction.expirationDate {
                    let isInTrial = transaction.offerType == .introductory

                    await syncSubscriptionToBackend(
                        productId: transaction.productID,
                        transactionId: String(transaction.id),
                        isInTrial: isInTrial,
                        expirationDate: expirationDate
                    )
                }
            } catch {
                print("❌ [Subscription] 同步 Apple 订阅失败: \(error)")
            }
        }
    }

    // MARK: - 验证交易
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - 格式化价格
    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    // MARK: - 格式化订阅周期
    func formattedPeriod(for product: Product) -> String {
        guard let subscription = product.subscription else { return "" }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            return value == 1 ? "每天" : "每\(value)天"
        case .week:
            return value == 1 ? "每周" : "每\(value)周"
        case .month:
            return value == 1 ? "每月" : "每\(value)个月"
        case .year:
            return value == 1 ? "每年" : "每\(value)年"
        @unknown default:
            return ""
        }
    }

    // MARK: - 格式化试用期
    func formattedTrialPeriod(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }

        let unit = offer.period.unit
        let value = offer.period.value

        switch unit {
        case .day:
            return "\(value)天免费试用"
        case .week:
            return "\(value)周免费试用"
        case .month:
            return "\(value)个月免费试用"
        case .year:
            return "\(value)年免费试用"
        @unknown default:
            return nil
        }
    }
}

// MARK: - Store Errors
enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "交易验证失败"
        case .productNotFound:
            return "未找到产品"
        case .purchaseFailed:
            return "购买失败"
        }
    }
}
