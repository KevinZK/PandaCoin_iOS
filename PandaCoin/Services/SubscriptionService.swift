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

    static let inactive = SubscriptionStatus(
        isActive: false,
        productId: nil,
        expirationDate: nil,
        isInTrialPeriod: false,
        willAutoRenew: false
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

    // MARK: - 更新订阅状态
    func updateSubscriptionStatus() async {
        var foundActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // 检查是否为我们的订阅产品
                if productIds.contains(transaction.productID) {
                    purchasedProductIDs.insert(transaction.productID)

                    // 获取订阅详情
                    if let expirationDate = transaction.expirationDate {
                        let isInTrial = transaction.offerType == .introductory

                        subscriptionStatus = SubscriptionStatus(
                            isActive: true,
                            productId: transaction.productID,
                            expirationDate: expirationDate,
                            isInTrialPeriod: isInTrial,
                            willAutoRenew: transaction.revocationDate == nil
                        )
                        foundActiveSubscription = true
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        if !foundActiveSubscription {
            subscriptionStatus = .inactive
            purchasedProductIDs.removeAll()
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
