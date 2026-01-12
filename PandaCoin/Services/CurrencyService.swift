//
//  CurrencyService.swift
//  PandaCoin
//
//  Created by kevin on 2025/1/12.
//

import Foundation
import Combine

// MARK: - 货币服务
class CurrencyService: ObservableObject {
    static let shared = CurrencyService()

    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 发布属性
    @Published var userSettings: UserCurrencySettings?
    @Published var supportedCurrencies: [CurrencyInfo] = CurrencyInfo.supportedCurrencies
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - 获取支持的货币列表
    func fetchSupportedCurrencies() -> AnyPublisher<[CurrencyInfo], APIError> {
        networkManager.request(
            endpoint: "/api/currency/supported",
            method: "GET",
            requiresAuth: false
        )
    }

    // MARK: - 获取用户货币设置
    func fetchUserSettings() -> AnyPublisher<UserCurrencySettings, APIError> {
        networkManager.request(
            endpoint: "/api/currency/settings",
            method: "GET"
        )
    }

    // MARK: - 更新用户货币设置
    func updateUserSettings(baseCurrency: String? = nil, locale: String? = nil) -> AnyPublisher<UserCurrencySettings, APIError> {
        let request = UpdateUserCurrencyRequest(baseCurrency: baseCurrency, locale: locale)
        return networkManager.request(
            endpoint: "/api/currency/settings",
            method: "PUT",
            body: request
        )
    }

    // MARK: - 获取汇率
    func getExchangeRate(from: String, to: String) -> AnyPublisher<RateDetail, APIError> {
        networkManager.request(
            endpoint: "/api/currency/rate?from=\(from)&to=\(to)",
            method: "GET"
        )
    }

    // MARK: - 货币转换
    func convert(amount: Decimal, from: String, to: String) -> AnyPublisher<CurrencyConversionResult, APIError> {
        networkManager.request(
            endpoint: "/api/currency/convert?amount=\(amount)&from=\(from)&to=\(to)",
            method: "GET"
        )
    }

    // MARK: - 刷新汇率
    func refreshRates() -> AnyPublisher<RefreshRatesResult, APIError> {
        networkManager.request(
            endpoint: "/api/currency/refresh-rates",
            method: "POST"
        )
    }

    // MARK: - 便捷方法

    /// 加载用户货币设置并缓存
    func loadUserSettings() {
        isLoading = true
        error = nil

        fetchUserSettings()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err.localizedDescription
                    logError("获取用户货币设置失败", error: err)
                }
            } receiveValue: { [weak self] settings in
                self?.userSettings = settings
                logInfo("用户货币设置: \(settings.baseCurrency)")
            }
            .store(in: &cancellables)
    }

    /// 更新基础货币
    func setBaseCurrency(_ currency: String) {
        isLoading = true
        error = nil

        updateUserSettings(baseCurrency: currency)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.error = err.localizedDescription
                    logError("更新货币设置失败", error: err)
                }
            } receiveValue: { [weak self] settings in
                self?.userSettings = settings
                logInfo("货币设置已更新: \(settings.baseCurrency)")
            }
            .store(in: &cancellables)
    }

    /// 获取当前基础货币
    var baseCurrency: String {
        userSettings?.baseCurrency ?? "CNY"
    }

    /// 获取当前货币信息
    var currentCurrencyInfo: CurrencyInfo? {
        userSettings?.currencyInfo ?? CurrencyInfo.find(byCode: "CNY")
    }

    /// 格式化金额（本地格式化，不调用API）
    func formatAmount(_ amount: Decimal, currency: String? = nil, locale: String? = nil) -> String {
        let currencyCode = currency ?? baseCurrency
        let localeIdentifier = locale ?? userSettings?.locale ?? "zh-CN"

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: localeIdentifier)

        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode) \(amount)"
    }

    /// 简单格式化金额（带货币符号）
    func formatSimple(_ amount: Decimal, currency: String? = nil) -> String {
        let currencyCode = currency ?? baseCurrency
        let currencyInfo = CurrencyInfo.find(byCode: currencyCode)
        let symbol = currencyInfo?.symbol ?? currencyCode

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let formattedNumber = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return "\(symbol)\(formattedNumber)"
    }
}

// MARK: - 刷新汇率结果
struct RefreshRatesResult: Codable {
    let success: Bool
    let updatedCount: Int?
    let message: String?
}

// MARK: - 货币格式化扩展
extension Decimal {
    /// 格式化为货币字符串
    func formatted(currency: String = "CNY", locale: String = "zh-CN") -> String {
        CurrencyService.shared.formatAmount(self, currency: currency, locale: locale)
    }

    /// 简单格式化（带符号）
    func formattedSimple(currency: String = "CNY") -> String {
        CurrencyService.shared.formatSimple(self, currency: currency)
    }
}
