//
//  TransactionService.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/6.
//

import Foundation
import Combine

// MARK: - Transaction Types
enum TransactionType: String, Codable, CaseIterable {
    case expense = "EXPENSE"
    case income = "INCOME"
    case transfer = "TRANSFER"
    case investBuy = "INVEST_BUY"
    case investSell = "INVEST_SELL"
    case repayment = "REPAYMENT"
    
    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .transfer: return "转账"
        case .investBuy: return "投资买入"
        case .investSell: return "投资卖出"
        case .repayment: return "信用卡还款"
        }
    }
}

// MARK: - Request Models
struct CreateTransactionRequest: Codable {
    let type: String
    let amount: Decimal
    let account_id: String
    let target_account_id: String?
    let investment_id: String?
    let quantity: Double?
    let unit_price: Double?
    let category: String
    let description: String?
    let date: String?
}

// MARK: - Response Models
struct TransactionResult: Codable {
    let record: TransactionRecord
    let account_changes: [AccountChange]
    let investment_changes: InvestmentChange?
    
    enum CodingKeys: String, CodingKey {
        case record
        case account_changes = "accountChanges"
        case investment_changes = "investmentChanges"
    }
}

struct TransactionRecord: Codable {
    let id: String
    let type: String
    let amount: Double
    let category: String
    let description: String?
    let date: String
}

struct AccountChange: Codable {
    let account_id: String
    let account_name: String
    let previous_balance: Double
    let new_balance: Double
    let change: Double
    
    enum CodingKeys: String, CodingKey {
        case account_id = "accountId"
        case account_name = "accountName"
        case previous_balance = "previousBalance"
        case new_balance = "newBalance"
        case change
    }
}

struct InvestmentChange: Codable {
    let investment_id: String
    let investment_name: String
    let previous_quantity: Double
    let new_quantity: Double
    let change: Double
    let cost_price: Double?
    
    enum CodingKeys: String, CodingKey {
        case investment_id = "investmentId"
        case investment_name = "investmentName"
        case previous_quantity = "previousQuantity"
        case new_quantity = "newQuantity"
        case change
        case cost_price = "costPrice"
    }
}

// MARK: - Net Worth Model
struct NetWorth: Codable {
    let total_assets: Double
    let total_liabilities: Double
    let net_worth: Double
    let breakdown: NetWorthBreakdown
    let accounts: [NetWorthAccount]
    let investments: [NetWorthInvestment]
    
    enum CodingKeys: String, CodingKey {
        case total_assets = "totalAssets"
        case total_liabilities = "totalLiabilities"
        case net_worth = "netWorth"
        case breakdown
        case accounts
        case investments
    }
}

struct NetWorthBreakdown: Codable {
    let bank_accounts: Double
    let cash_accounts: Double
    let digital_wallet_accounts: Double
    let savings_accounts: Double
    let retirement_accounts: Double
    let crypto_accounts: Double
    let property_value: Double
    let vehicle_value: Double
    let other_assets: Double
    let investment_value: Double
    let credit_card_debt: Double
    let loan_debt: Double
    let mortgage_debt: Double
    let other_liabilities: Double
    
    enum CodingKeys: String, CodingKey {
        case bank_accounts = "bankAccounts"
        case cash_accounts = "cashAccounts"
        case digital_wallet_accounts = "digitalWalletAccounts"
        case savings_accounts = "savingsAccounts"
        case retirement_accounts = "retirementAccounts"
        case crypto_accounts = "cryptoAccounts"
        case property_value = "propertyValue"
        case vehicle_value = "vehicleValue"
        case other_assets = "otherAssets"
        case investment_value = "investmentValue"
        case credit_card_debt = "creditCardDebt"
        case loan_debt = "loanDebt"
        case mortgage_debt = "mortgageDebt"
        case other_liabilities = "otherLiabilities"
    }
}

struct NetWorthAccount: Codable {
    let id: String
    let name: String
    let type: String
    let balance: Double
}

struct NetWorthInvestment: Codable {
    let id: String
    let name: String
    let type: String
    let quantity: Double
    let cost_price: Double
    let current_price: Double
    let market_value: Double
    let profit_loss: Double
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, quantity
        case cost_price = "costPrice"
        case current_price = "currentPrice"
        case market_value = "marketValue"
        case profit_loss = "profitLoss"
    }
}

// MARK: - Transaction Service
class TransactionService: ObservableObject {
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    @Published var netWorth: NetWorth?
    @Published var isLoading = false
    
    // MARK: - Create Transaction
    func createTransaction(
        type: TransactionType,
        amount: Decimal,
        accountId: String,
        category: String,
        description: String? = nil,
        targetAccountId: String? = nil,
        investmentId: String? = nil,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        date: Date? = nil
    ) -> AnyPublisher<TransactionResult, APIError> {
        let dateString = date.map { ISO8601DateFormatter().string(from: $0) }
        
        let request = CreateTransactionRequest(
            type: type.rawValue,
            amount: amount,
            account_id: accountId,
            target_account_id: targetAccountId,
            investment_id: investmentId,
            quantity: quantity,
            unit_price: unitPrice,
            category: category,
            description: description,
            date: dateString
        )
        
        return networkManager.request(
            endpoint: "/transactions",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Get Net Worth
    func fetchNetWorth() {
        isLoading = true
        
        networkManager.request(
            endpoint: "/transactions/net-worth",
            method: "GET",
            body: nil as EmptyBody?
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (completion: Subscribers.Completion<APIError>) in
            self?.isLoading = false
            if case .failure(let error) = completion {
                logError("获取净资产失败", error: error)
            }
        } receiveValue: { [weak self] (response: NetWorth) in
            self?.netWorth = response
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Delete Transaction
    func deleteTransaction(id: String) -> AnyPublisher<Void, APIError> {
        networkManager.request(
            endpoint: "/transactions/\(id)",
            method: "DELETE",
            body: nil as EmptyBody?
        )
        .map { (_: EmptyResponse) in () }
        .handleEvents(receiveOutput: { _ in
            NotificationCenter.default.post(name: .netWorthNeedsRefresh, object: nil)
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - Convenience Methods
    
    /// 普通支出
    func expense(amount: Decimal, accountId: String, category: String, description: String? = nil) -> AnyPublisher<TransactionResult, APIError> {
        createTransaction(type: .expense, amount: amount, accountId: accountId, category: category, description: description)
    }
    
    /// 普通收入
    func income(amount: Decimal, accountId: String, category: String, description: String? = nil) -> AnyPublisher<TransactionResult, APIError> {
        createTransaction(type: .income, amount: amount, accountId: accountId, category: category, description: description)
    }
    
    /// 转账
    func transfer(amount: Decimal, fromAccountId: String, toAccountId: String, description: String? = nil) -> AnyPublisher<TransactionResult, APIError> {
        createTransaction(
            type: .transfer,
            amount: amount,
            accountId: fromAccountId,
            category: "转账",
            description: description,
            targetAccountId: toAccountId
        )
    }
    
    /// 信用卡还款
    func repayment(amount: Decimal, fromBankAccountId: String, toCreditCardId: String) -> AnyPublisher<TransactionResult, APIError> {
        createTransaction(
            type: .repayment,
            amount: amount,
            accountId: fromBankAccountId,
            category: "还款",
            targetAccountId: toCreditCardId
        )
    }
    
    /// 投资买入
    func investBuy(
        amount: Decimal,
        cashAccountId: String,
        investmentId: String,
        quantity: Double,
        unitPrice: Double
    ) -> AnyPublisher<TransactionResult, APIError> {
        createTransaction(
            type: .investBuy,
            amount: amount,
            accountId: cashAccountId,
            category: "投资买入",
            investmentId: investmentId,
            quantity: quantity,
            unitPrice: unitPrice
        )
    }
    
    /// 投资卖出
    func investSell(
        amount: Decimal,
        cashAccountId: String,
        investmentId: String,
        quantity: Double,
        unitPrice: Double
    ) -> AnyPublisher<TransactionResult, APIError> {
        createTransaction(
            type: .investSell,
            amount: amount,
            accountId: cashAccountId,
            category: "投资卖出",
            investmentId: investmentId,
            quantity: quantity,
            unitPrice: unitPrice
        )
    }
}

// MARK: - Empty Body for GET/DELETE
struct EmptyBody: Codable {}
