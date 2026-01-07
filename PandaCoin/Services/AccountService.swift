//
//  AccountService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine

class AssetService: ObservableObject {
    static let shared = AssetService()
    
    @Published var accounts: [Asset] = []
    @Published var isLoading = false
    
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    // MARK: - 获取所有资产
    func fetchAccounts() {
        isLoading = true
        
        networkManager.request(endpoint: "/assets", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("获取资产失败: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] (accounts: [Asset]) in
                    self?.accounts = accounts
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 获取所有资产（返回 Publisher）
    func fetchAssets() -> AnyPublisher<[Asset], APIError> {
        return networkManager.request(endpoint: "/assets", method: "GET")
            .handleEvents(receiveOutput: { [weak self] (assets: [Asset]) in
                DispatchQueue.main.async {
                    self?.accounts = assets
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - 创建资产
    func createAccount(name: String, type: AssetType, balance: Decimal) -> AnyPublisher<Asset, APIError> {
        let request = AssetRequest(name: name, type: type, balance: balance, currency: "CNY")
        return networkManager.request(
            endpoint: "/assets",
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
            endpoint: "/assets/\(id)",
            method: "PATCH",
            body: request
        )
        .eraseToAnyPublisher()
    }
    
    // MARK: - 更新资产（完整对象）
    func updateAsset(_ asset: Asset) -> AnyPublisher<Asset, APIError> {
        let request = UpdateAccountRequest(
            name: asset.name,
            balance: asset.balance,
            cardIdentifier: asset.cardIdentifier
        )
        return networkManager.request(
            endpoint: "/assets/\(asset.id)",
            method: "PATCH",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (updatedAsset: Asset) in
            // 更新本地缓存（必须在主线程）
            DispatchQueue.main.async {
                if let index = self?.accounts.firstIndex(where: { $0.id == updatedAsset.id }) {
                    self?.accounts[index] = updatedAsset
                }
            }
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - 删除资产
    func deleteAccount(id: String) -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/assets/\(id)",
            method: "DELETE"
        )
        .map { (_: EmptyResponse) in () }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 获取资产名称列表
    func getAccountNames() -> [String] {
        return accounts.map { $0.name }
    }
    
    // MARK: - 根据名称查找资产
    func findAccount(byName name: String) -> Asset? {
        return accounts.first { $0.name == name }
    }
}
