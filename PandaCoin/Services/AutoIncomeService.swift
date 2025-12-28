//
//  AutoIncomeService.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/28.
//

import Foundation
import Combine

class AutoIncomeService: ObservableObject {
    static let shared = AutoIncomeService()

    @Published var autoIncomes: [AutoIncome] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()

    // MARK: - 获取所有自动入账配置

    func fetchAutoIncomes() -> AnyPublisher<[AutoIncome], APIError> {
        isLoading = true
        errorMessage = nil

        return networkManager.request(
            endpoint: "/auto-incomes",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
        .handleEvents(
            receiveOutput: { [weak self] (incomes: [AutoIncome]) in
                DispatchQueue.main.async {
                    self?.autoIncomes = incomes
                    self?.isLoading = false
                }
            },
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        )
        .eraseToAnyPublisher()
    }

    // MARK: - 获取单个自动入账配置

    func fetchAutoIncome(id: String) -> AnyPublisher<AutoIncome, APIError> {
        networkManager.request(
            endpoint: "/auto-incomes/\(id)",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
    }

    // MARK: - 创建自动入账配置

    func createAutoIncome(_ request: CreateAutoIncomeRequest) -> AnyPublisher<AutoIncome, APIError> {
        networkManager.request(
            endpoint: "/auto-incomes",
            method: "POST",
            body: request,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (income: AutoIncome) in
            DispatchQueue.main.async {
                self?.autoIncomes.append(income)
                self?.autoIncomes.sort { $0.dayOfMonth < $1.dayOfMonth }
            }
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 更新自动入账配置

    func updateAutoIncome(id: String, request: UpdateAutoIncomeRequest) -> AnyPublisher<AutoIncome, APIError> {
        networkManager.request(
            endpoint: "/auto-incomes/\(id)",
            method: "PUT",
            body: request,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (income: AutoIncome) in
            DispatchQueue.main.async {
                if let index = self?.autoIncomes.firstIndex(where: { $0.id == id }) {
                    self?.autoIncomes[index] = income
                    self?.autoIncomes.sort { $0.dayOfMonth < $1.dayOfMonth }
                }
            }
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 删除自动入账配置

    func deleteAutoIncome(id: String) -> AnyPublisher<Void, APIError> {
        networkManager.request(
            endpoint: "/auto-incomes/\(id)",
            method: "DELETE",
            body: nil as String?,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (_: EmptyResponse) in
            DispatchQueue.main.async {
                self?.autoIncomes.removeAll { $0.id == id }
            }
        })
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 切换启用/禁用状态

    func toggleAutoIncome(id: String) -> AnyPublisher<AutoIncome, APIError> {
        networkManager.request(
            endpoint: "/auto-incomes/\(id)/toggle",
            method: "PATCH",
            body: nil as String?,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (income: AutoIncome) in
            DispatchQueue.main.async {
                if let index = self?.autoIncomes.firstIndex(where: { $0.id == id }) {
                    self?.autoIncomes[index] = income
                }
            }
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 手动执行入账

    func executeAutoIncome(id: String) -> AnyPublisher<AutoIncomeExecutionResult, APIError> {
        networkManager.request(
            endpoint: "/auto-incomes/\(id)/execute",
            method: "POST",
            body: nil as String?,
            requiresAuth: true
        )
    }

    // MARK: - 获取执行日志

    func fetchLogs(incomeId: String, limit: Int = 20) -> AnyPublisher<[AutoIncomeLog], APIError> {
        networkManager.request(
            endpoint: "/auto-incomes/\(incomeId)/logs?limit=\(limit)",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
    }
}
