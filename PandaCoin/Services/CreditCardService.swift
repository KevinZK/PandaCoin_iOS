//
//  CreditCardService.swift
//  PandaCoin
//
//  信用卡服务 - 管理信用卡CRUD和额度更新
//

import Foundation
import Combine

class CreditCardService: ObservableObject {
    static let shared = CreditCardService()
    
    @Published var creditCards: [CreditCard] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    // 本地存储 key
    private let localStorageKey = "credit_cards_cache"
    
    private init() {
        loadFromLocalStorage()
    }
    
    // MARK: - 获取所有信用卡
    func fetchCreditCards() {
        isLoading = true
        error = nil
        
        networkManager.request(endpoint: "/credit-cards", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion {
                        self?.error = err.localizedDescription
                        logError("获取信用卡列表失败", error: err)
                    }
                },
                receiveValue: { [weak self] (cards: [CreditCard]) in
                    self?.creditCards = cards
                    self?.saveToLocalStorage()
                    logInfo("✅ 获取信用卡列表成功: \(cards.count)张")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 创建信用卡
    func createCreditCard(
        name: String,
        institutionName: String,
        cardIdentifier: String,
        creditLimit: Double,
        currentBalance: Double? = nil,  // 待还金额
        repaymentDueDate: String?,
        currency: String = "CNY"
    ) -> AnyPublisher<CreditCard, APIError> {
        let request = CreateCreditCardRequest(
            name: name,
            institutionName: institutionName,
            cardIdentifier: cardIdentifier,
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            repaymentDueDate: repaymentDueDate,
            currency: currency
        )
        
        return networkManager.request(
            endpoint: "/credit-cards",
            method: "POST",
            body: request
        )
        .handleEvents(
            receiveOutput: { [weak self] (card: CreditCard) in
                DispatchQueue.main.async {
                    self?.creditCards.append(card)
                    self?.saveToLocalStorage()
                }
                logInfo("✅ 创建信用卡成功: \(card.displayName)")
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 更新信用卡
    func updateCreditCard(
        id: String,
        name: String? = nil,
        institutionName: String? = nil,
        cardIdentifier: String? = nil,
        creditLimit: Double? = nil,
        currentBalance: Double? = nil,
        repaymentDueDate: String? = nil,
        currency: String? = nil
    ) -> AnyPublisher<CreditCard, APIError> {
        let request = UpdateCreditCardRequest(
            name: name,
            institutionName: institutionName,
            cardIdentifier: cardIdentifier,
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            repaymentDueDate: repaymentDueDate,
            currency: currency
        )
        
        return networkManager.request(
            endpoint: "/credit-cards/\(id)",
            method: "PATCH",
            body: request
        )
        .handleEvents(
            receiveOutput: { [weak self] (updatedCard: CreditCard) in
                DispatchQueue.main.async {
                    if let index = self?.creditCards.firstIndex(where: { $0.id == id }) {
                        self?.creditCards[index] = updatedCard
                        self?.saveToLocalStorage()
                    }
                }
                logInfo("✅ 更新信用卡成功: \(updatedCard.displayName)")
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 删除信用卡
    func deleteCreditCard(id: String) -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/credit-cards/\(id)",
            method: "DELETE"
        )
        .map { (_: EmptyResponse) in () }
        .handleEvents(
            receiveOutput: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.creditCards.removeAll { $0.id == id }
                    self?.saveToLocalStorage()
                }
                logInfo("✅ 删除信用卡成功")
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 根据 cardIdentifier 查找信用卡
    func findCard(byIdentifier identifier: String) -> CreditCard? {
        return creditCards.first { $0.cardIdentifier == identifier }
    }
    
    // MARK: - 根据 cardIdentifier 更新余额
    func updateBalance(
        cardIdentifier: String,
        amount: Double,
        transactionType: String  // "EXPENSE" or "PAYMENT"
    ) -> AnyPublisher<CreditCard, APIError> {
        guard let card = findCard(byIdentifier: cardIdentifier) else {
            return Fail(error: APIError.serverError("找不到卡片: \(cardIdentifier)"))
                .eraseToAnyPublisher()
        }
        
        var newBalance = card.currentBalance
        if transactionType == "EXPENSE" {
            newBalance += amount
        } else if transactionType == "PAYMENT" {
            newBalance = max(0, newBalance - amount)
        }
        
        return updateCreditCard(
            id: card.id,
            currentBalance: newBalance
        )
    }
    
    // MARK: - 本地存储
    private func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(creditCards) {
            UserDefaults.standard.set(data, forKey: localStorageKey)
        }
    }
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: localStorageKey),
           let cards = try? JSONDecoder().decode([CreditCard].self, from: data) {
            self.creditCards = cards
        }
    }
    
    // MARK: - 从 CreditCardParsed 创建或更新信用卡
    func saveCreditCardFromParsed(_ parsed: CreditCardParsed) -> AnyPublisher<CreditCard, APIError> {
        // 如果有 cardIdentifier，尝试查找已有卡片
        if let identifier = parsed.cardIdentifier, !identifier.isEmpty {
            if let existingCard = findCard(byIdentifier: identifier) {
                // 更新已有卡片
                return updateCreditCard(
                    id: existingCard.id,
                    name: parsed.name.isEmpty ? nil : parsed.name,
                    institutionName: parsed.institutionName,
                    creditLimit: parsed.creditLimit,
                    currentBalance: Double(truncating: parsed.outstandingBalance as NSNumber),  // 传递待还金额
                    repaymentDueDate: parsed.repaymentDueDate
                )
            }
        }
        
        // 创建新卡片
        return createCreditCard(
            name: parsed.name,
            institutionName: parsed.institutionName ?? "",
            cardIdentifier: parsed.cardIdentifier ?? "",
            creditLimit: parsed.creditLimit ?? 0,
            currentBalance: Double(truncating: parsed.outstandingBalance as NSNumber),  // 传递待还金额
            repaymentDueDate: parsed.repaymentDueDate,
            currency: parsed.currency
        )
    }
    
    // MARK: - 创建信用卡消费记录
    func createTransaction(_ request: CreateCreditCardTransactionRequest) -> AnyPublisher<CreateCreditCardTransactionResponse, APIError> {
        logInfo("✅ 创建信用卡消费: 卡号=\(request.cardIdentifier), 金额=\(request.amount), 类型=\(request.type)")
        
        return networkManager.request(
            endpoint: "/credit-cards/transactions",
            method: "POST",
            body: request
        )
        .handleEvents(
            receiveOutput: { [weak self] (response: CreateCreditCardTransactionResponse) in
                // 更新本地信用卡数据
                DispatchQueue.main.async {
                    if let index = self?.creditCards.firstIndex(where: { $0.id == response.creditCard.id }) {
                        self?.creditCards[index] = response.creditCard
                        self?.saveToLocalStorage()
                    }
                }
                logInfo("✅ 信用卡消费记录创建成功")
            }
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取信用卡消费记录
    func getTransactions(creditCardId: String, month: String? = nil) -> AnyPublisher<CreditCardTransactionsResponse, APIError> {
        var endpoint = "/credit-cards/\(creditCardId)/transactions"
        if let month = month {
            endpoint += "?month=\(month)"
        }
        
        return networkManager.request(
            endpoint: endpoint,
            method: "GET"
        )
    }
}
