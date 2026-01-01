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

// MARK: - 后端订阅响应
struct BackendSubscriptionResponse: Codable {
    let userId: String
    let status: String
    let plan: String?
    let trialStartDate: String?
    let trialEndDate: String?
    let subscriptionStartDate: String?
    let subscriptionEndDate: String?
    let isProMember: Bool
    let isInTrialPeriod: Bool
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

    // MARK: - Computed Properties

    /// 是否为 Pro 会员
    var isProMember: Bool {
        subscriptionStatus.isActive
    }

    /// 是否在试用期
    var isInTrialPeriod: Bool {
        subscriptionStatus.isInTrialPeriod
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

    // MARK: - 更新订阅状态（综合后端和 Apple）
    func updateSubscriptionStatus() async {
        print("🔍 [Subscription] 开始检查订阅状态...")

        // 1. 先检查后端订阅状态（管理员可以直接设置）
        let backendStatus = await fetchBackendSubscriptionStatus()
        if backendStatus.isActive {
            print("✅ [Subscription] 后端订阅有效: isInTrial=\(backendStatus.isInTrialPeriod)")
            subscriptionStatus = backendStatus
            return
        }

        // 2. 后端无有效订阅，检查 Apple StoreKit
        var foundActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                print("📦 [Subscription] 发现 Apple 交易: productID=\(transaction.productID), offerType=\(String(describing: transaction.offerType)), expirationDate=\(String(describing: transaction.expirationDate))")

                // 检查是否为我们的订阅产品
                if productIds.contains(transaction.productID) {
                    purchasedProductIDs.insert(transaction.productID)

                    // 获取订阅详情
                    if let expirationDate = transaction.expirationDate {
                        let isInTrial = transaction.offerType == .introductory

                        print("✅ [Subscription] Apple 有效订阅: isInTrial=\(isInTrial), expirationDate=\(expirationDate)")

                        subscriptionStatus = SubscriptionStatus(
                            isActive: true,
                            productId: transaction.productID,
                            expirationDate: expirationDate,
                            isInTrialPeriod: isInTrial,
                            willAutoRenew: transaction.revocationDate == nil,
                            source: .apple
                        )
                        foundActiveSubscription = true

                        // 同步到后端
                        await syncSubscriptionToBackend(
                            productId: transaction.productID,
                            transactionId: String(transaction.id),
                            isInTrial: isInTrial,
                            expirationDate: expirationDate
                        )
                    }
                }
            } catch {
                print("❌ [Subscription] 验证交易失败: \(error)")
            }
        }

        if !foundActiveSubscription {
            print("⚪ [Subscription] 未找到有效订阅")
            subscriptionStatus = .inactive
            purchasedProductIDs.removeAll()
        } else {
            print("🎉 [Subscription] 订阅状态: isProMember=\(isProMember), isInTrialPeriod=\(isInTrialPeriod)")
        }
    }

    // MARK: - 从后端获取订阅状态
    private func fetchBackendSubscriptionStatus() async -> SubscriptionStatus {
        guard let token = NetworkManager.shared.accessToken else {
            print("⚪ [Subscription] 未登录，跳过后端检查")
            return .inactive
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/subscription/status") else {
            return .inactive
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ [Subscription] 后端返回非 200 状态")
                return .inactive
            }

            let decoder = JSONDecoder()
            let backendResponse = try decoder.decode(BackendSubscriptionResponse.self, from: data)

            print("📡 [Subscription] 后端订阅状态: status=\(backendResponse.status), isProMember=\(backendResponse.isProMember)")

            if backendResponse.isProMember {
                // 解析到期时间
                var expirationDate: Date? = nil
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                if backendResponse.isInTrialPeriod, let trialEnd = backendResponse.trialEndDate {
                    expirationDate = dateFormatter.date(from: trialEnd)
                } else if let subEnd = backendResponse.subscriptionEndDate {
                    expirationDate = dateFormatter.date(from: subEnd)
                }

                return SubscriptionStatus(
                    isActive: true,
                    productId: nil,
                    expirationDate: expirationDate,
                    isInTrialPeriod: backendResponse.isInTrialPeriod,
                    willAutoRenew: true,
                    source: .backend
                )
            }

            return .inactive
        } catch {
            print("❌ [Subscription] 获取后端订阅状态失败: \(error)")
            return .inactive
        }
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
                await updateSubscriptionStatus()
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
            await updateSubscriptionStatus()

            if !isProMember {
                errorMessage = "未找到可恢复的订阅"
            }
        } catch {
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }

        isLoading = false
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
