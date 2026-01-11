//
//  AuthService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine
import AuthenticationServices

// MARK: - Apple Login Request
struct AppleLoginRequest: Codable {
    let identityToken: String
    let appleUserId: String
    let email: String?
    let fullName: String?
}

// MARK: - Apple Auth Response
struct AppleAuthResponse: Codable {
    let user: User
    let accessToken: String
    let tokenType: String
    let isNewUser: Bool
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var defaultExpenseAccount: DefaultExpenseAccountResponse?
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 检查是否已登录
        isAuthenticated = networkManager.accessToken != nil
        if isAuthenticated {
            // 先同步 Apple 订阅到后端，再获取用户数据
            Task { @MainActor in
                await SubscriptionService.shared.syncAfterLogin()
                self.fetchCurrentUser()
                self.fetchDefaultExpenseAccount()
            }
        }
    }
    
    // MARK: - 注册
    func register(email: String, password: String, name: String?) -> AnyPublisher<AuthResponse, APIError> {
        let request = RegisterRequest(email: email, password: password, name: name)
        
        return networkManager.request(
            endpoint: "/auth/register",
            method: "POST",
            body: request,
            requiresAuth: false
        )
        .handleEvents(receiveOutput: { [weak self] (response: AuthResponse) in
            self?.handleAuthSuccess(response)
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - 登录
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        let request = LoginRequest(email: email, password: password)

        return networkManager.request(
            endpoint: "/auth/login",
            method: "POST",
            body: request,
            requiresAuth: false
        )
        .handleEvents(receiveOutput: { [weak self] (response: AuthResponse) in
            self?.handleAuthSuccess(response)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - Apple Sign In
    func appleLogin(identityToken: String, appleUserId: String, email: String?, fullName: String?) -> AnyPublisher<AppleAuthResponse, APIError> {
        let request = AppleLoginRequest(
            identityToken: identityToken,
            appleUserId: appleUserId,
            email: email,
            fullName: fullName
        )

        return networkManager.request(
            endpoint: "/auth/apple",
            method: "POST",
            body: request,
            requiresAuth: false
        )
        .handleEvents(receiveOutput: { [weak self] (response: AppleAuthResponse) in
            self?.handleAppleAuthSuccess(response)
        })
        .eraseToAnyPublisher()
    }

    // MARK: - 删除账号
    func deleteAccount() -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/auth/account",
            method: "DELETE"
        )
        .handleEvents(receiveOutput: { [weak self] (_: EmptyResponse) in
            self?.logout()
        })
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 获取当前用户
    func fetchCurrentUser() {
        networkManager.request(endpoint: "/auth/me", method: "GET")
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.logout()
                    }
                },
                receiveValue: { [weak self] (user: User) in
                    self?.currentUser = user
                    // 同步订阅状态到 SubscriptionService
                    Task { @MainActor in
                        SubscriptionService.shared.syncFromUserData(
                            isProMember: user.isProMember ?? false,
                            isInTrialPeriod: user.isInTrialPeriod ?? false
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 登出
    func logout() {
        networkManager.logout()
        isAuthenticated = false
        currentUser = nil
        defaultExpenseAccount = nil
    }
    
    // MARK: - 默认支出账户
    
    /// 获取默认支出账户
    func fetchDefaultExpenseAccount() {
        networkManager.optionalRequest(endpoint: "/auth/default-expense-account", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] (response: DefaultExpenseAccountResponse?) in
                    self?.defaultExpenseAccount = response
                }
            )
            .store(in: &cancellables)
    }
    
    /// 设置默认支出账户
    func setDefaultExpenseAccount(accountId: String, accountType: DefaultAccountType) -> AnyPublisher<Void, APIError> {
        let request = SetDefaultAccountRequest(accountId: accountId, accountType: accountType.rawValue)
        
        return networkManager.request(
            endpoint: "/auth/default-expense-account",
            method: "PUT",
            body: request
        )
        .handleEvents(receiveOutput: { [weak self] (_: SetDefaultAccountRequest) in
            self?.fetchDefaultExpenseAccount()
            self?.fetchCurrentUser()
        })
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    /// 清除默认支出账户
    func clearDefaultExpenseAccount() -> AnyPublisher<Void, APIError> {
        return networkManager.request(
            endpoint: "/auth/default-expense-account",
            method: "DELETE"
        )
        .handleEvents(receiveOutput: { [weak self] (_: EmptyResponse) in
            self?.defaultExpenseAccount = nil
            self?.fetchCurrentUser()
        })
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    /// 获取推荐账户（基于机构名称）
    func getRecommendedAccount(institutionName: String) -> AnyPublisher<RecommendedAccountResponse, APIError> {
        let encodedName = institutionName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? institutionName
        return networkManager.request(
            endpoint: "/auth/recommended-account?institutionName=\(encodedName)",
            method: "GET"
        )
    }
    
    /// 检查指定账户是否为默认账户
    func isDefaultExpenseAccount(accountId: String, type: DefaultAccountType) -> Bool {
        guard let user = currentUser else { return false }
        return user.defaultExpenseAccountId == accountId &&
               user.defaultExpenseAccountType == type.rawValue
    }
    
    // MARK: - Private
    private func handleAuthSuccess(_ response: AuthResponse) {
        networkManager.accessToken = response.accessToken
        currentUser = response.user
        isAuthenticated = true
        fetchDefaultExpenseAccount()
        // 登录后先同步 Apple 订阅，再获取完整用户数据
        Task { @MainActor in
            await SubscriptionService.shared.syncAfterLogin()
            self.fetchCurrentUser()
        }
    }

    private func handleAppleAuthSuccess(_ response: AppleAuthResponse) {
        networkManager.accessToken = response.accessToken
        currentUser = response.user
        isAuthenticated = true
        fetchDefaultExpenseAccount()
        // 登录后先同步 Apple 订阅，再获取完整用户数据
        Task { @MainActor in
            await SubscriptionService.shared.syncAfterLogin()
            self.fetchCurrentUser()
        }
    }
}
