//
//  HoldingService.swift
//  PandaCoin
//
//  Created by kevin on 2026/01/03.
//

import Foundation
import Combine

class HoldingService: ObservableObject {
    static let shared = HoldingService()

    @Published var holdings: [Holding] = []
    @Published var isLoading = false

    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - 获取用户所有持仓
    func fetchHoldings() -> AnyPublisher<[Holding], APIError> {
        isLoading = true
        return networkManager.request(endpoint: "/holdings", method: "GET")
            .handleEvents(
                receiveOutput: { [weak self] (holdings: [Holding]) in
                    DispatchQueue.main.async {
                        self?.holdings = holdings
                        self?.isLoading = false
                    }
                },
                receiveCompletion: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - 获取指定投资账户的持仓
    func fetchInvestmentHoldings(investmentId: String) -> AnyPublisher<InvestmentHoldingsSummary, APIError> {
        return networkManager.request(
            endpoint: "/holdings/investment/\(investmentId)",
            method: "GET"
        )
    }

    // MARK: - 获取单个持仓详情
    func fetchHolding(id: String) -> AnyPublisher<Holding, APIError> {
        return networkManager.request(
            endpoint: "/holdings/\(id)",
            method: "GET"
        )
    }

    // MARK: - 获取持仓汇总
    func fetchSummary() -> AnyPublisher<TotalHoldingsSummary, APIError> {
        return networkManager.request(
            endpoint: "/holdings/summary",
            method: "GET"
        )
    }

    // MARK: - 买入新资产（创建持仓 + 首次买入）
    func buyNewHolding(
        investmentId: String,
        name: String,
        type: HoldingType,
        market: MarketType,
        quantity: Double,
        price: Double,
        tickerCode: String? = nil,
        displayName: String? = nil,
        fee: Double? = nil,
        date: Date? = nil,
        note: String? = nil,
        rawText: String? = nil,
        currency: String? = nil
    ) -> AnyPublisher<BuyHoldingResponse, APIError> {
        let dateString = date.map { ISO8601DateFormatter().string(from: $0) }
        let request = BuyNewHoldingRequest(
            investmentId: investmentId,
            name: name,
            displayName: displayName,
            type: type,
            market: market,
            tickerCode: tickerCode,
            quantity: quantity,
            price: price,
            fee: fee,
            date: dateString,
            note: note,
            rawText: rawText,
            currency: currency
        )

        return networkManager.request(
            endpoint: "/holdings/buy-new",
            method: "POST",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (response: BuyHoldingResponse) in
            DispatchQueue.main.async {
                self?.holdings.insert(response.holding, at: 0)
            }
            NotificationCenter.default.post(name: .netWorthNeedsRefresh, object: nil)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 买入（增加现有持仓）
    func buy(
        holdingId: String,
        quantity: Double,
        price: Double,
        fee: Double? = nil,
        date: Date? = nil,
        note: String? = nil,
        rawText: String? = nil
    ) -> AnyPublisher<BuyHoldingResponse, APIError> {
        let dateString = date.map { ISO8601DateFormatter().string(from: $0) }
        let request = HoldingTransactionRequest(
            holdingId: holdingId,
            type: .buy,
            quantity: quantity,
            price: price,
            fee: fee,
            date: dateString,
            note: note,
            rawText: rawText
        )

        return networkManager.request(
            endpoint: "/holdings/buy",
            method: "POST",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (response: BuyHoldingResponse) in
            DispatchQueue.main.async {
                if let index = self?.holdings.firstIndex(where: { $0.id == holdingId }) {
                    self?.holdings[index] = response.holding
                }
            }
            NotificationCenter.default.post(name: .netWorthNeedsRefresh, object: nil)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 卖出
    func sell(
        holdingId: String,
        quantity: Double,
        price: Double,
        fee: Double? = nil,
        date: Date? = nil,
        note: String? = nil,
        rawText: String? = nil
    ) -> AnyPublisher<BuyHoldingResponse, APIError> {
        let dateString = date.map { ISO8601DateFormatter().string(from: $0) }
        let request = HoldingTransactionRequest(
            holdingId: holdingId,
            type: .sell,
            quantity: quantity,
            price: price,
            fee: fee,
            date: dateString,
            note: note,
            rawText: rawText
        )

        return networkManager.request(
            endpoint: "/holdings/sell",
            method: "POST",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (response: BuyHoldingResponse) in
            DispatchQueue.main.async {
                if let index = self?.holdings.firstIndex(where: { $0.id == holdingId }) {
                    self?.holdings[index] = response.holding
                }
            }
            NotificationCenter.default.post(name: .netWorthNeedsRefresh, object: nil)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 获取交易记录
    func fetchTransactions(
        holdingId: String? = nil,
        investmentId: String? = nil
    ) -> AnyPublisher<[HoldingTransaction], APIError> {
        var endpoint = "/holdings/transactions"
        var queryItems: [String] = []

        if let holdingId = holdingId {
            queryItems.append("holdingId=\(holdingId)")
        }
        if let investmentId = investmentId {
            queryItems.append("investmentId=\(investmentId)")
        }

        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }

        return networkManager.request(
            endpoint: endpoint,
            method: "GET"
        )
    }

    // MARK: - 更新持仓信息
    func updateHolding(id: String, request: UpdateHoldingRequest) -> AnyPublisher<Holding, APIError> {
        return networkManager.request(
            endpoint: "/holdings/\(id)",
            method: "PATCH",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (holding: Holding) in
            DispatchQueue.main.async {
                if let index = self?.holdings.firstIndex(where: { $0.id == id }) {
                    self?.holdings[index] = holding
                }
            }
            NotificationCenter.default.post(name: .netWorthNeedsRefresh, object: nil)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 删除持仓
    func deleteHolding(id: String) -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/holdings/\(id)",
            method: "DELETE"
        )
        .map { (_: EmptyResponse) in () }
        .handleEvents(receiveOutput: { [weak self] _ in
            DispatchQueue.main.async {
                self?.holdings.removeAll { $0.id == id }
            }
            NotificationCenter.default.post(name: .netWorthNeedsRefresh, object: nil)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 根据名称查找持仓
    func findHolding(byName name: String) -> Holding? {
        return holdings.first { $0.name.lowercased().contains(name.lowercased()) }
    }

    // MARK: - 根据代码查找持仓
    func findHolding(byTickerCode code: String) -> Holding? {
        return holdings.first { $0.tickerCode?.lowercased() == code.lowercased() }
    }

    // MARK: - 获取指定投资账户的持仓列表
    func getHoldings(forInvestmentId investmentId: String) -> [Holding] {
        return holdings.filter { $0.investmentId == investmentId }
    }

    // MARK: - 计算投资账户持仓总市值
    func calculateInvestmentHoldingsValue(investmentId: String) -> Double {
        return getHoldings(forInvestmentId: investmentId)
            .reduce(0) { $0 + $1.marketValue }
    }

    // MARK: - 计算所有持仓总市值
    func calculateTotalHoldingsValue() -> Double {
        return holdings.reduce(0) { $0 + $1.marketValue }
    }
}
