//
//  AccountService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine

class AssetService: ObservableObject {
    @Published var accounts: [Asset] = []
    @Published var isLoading = false
    
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - 获取所有账户
    func fetchAccounts() {
        isLoading = true
        
        networkManager.request(endpoint: "/accounts", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("获取账户失败: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] (accounts: [Asset]) in
                    self?.accounts = accounts
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 创建账户
    func createAccount(name: String, type: AssetType, balance: Decimal) -> AnyPublisher<Asset, APIError> {
        let request = AssetRequest(name: name, type: type, balance: balance, currency: "CNY")
        return networkManager.request(
            endpoint: "/accounts",
            method: "POST",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (account: Asset) in
            self?.accounts.append(account)
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - 更新资产
    func updateAsset(id: String, name: String, balance: Decimal) -> AnyPublisher<Asset, APIError> {
        let request = UpdateAccountRequest(name: name, balance: balance)
        return networkManager.request(
            endpoint: "/accounts/\(id)",
            method: "PATCH",
            body: request
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 删除账户
    func deleteAccount(id: String) -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/accounts/\(id)",
            method: "DELETE"
        )
        .map { (_: EmptyResponse) in () }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取账户名称列表
    func getAccountNames() -> [String] {
        return accounts.map { $0.name }
    }
    
    // MARK: - 根据名称查找账户
    func findAccount(byName name: String) -> Asset? {
        return accounts.first { $0.name == name }
    }
}
