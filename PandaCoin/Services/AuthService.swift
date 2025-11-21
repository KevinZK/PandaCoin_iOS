//
//  AuthService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Combine

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 检查是否已登录
        isAuthenticated = networkManager.accessToken != nil
        if isAuthenticated {
            fetchCurrentUser()
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
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 登出
    func logout() {
        networkManager.logout()
        isAuthenticated = false
        currentUser = nil
    }
    
    // MARK: - Private
    private func handleAuthSuccess(_ response: AuthResponse) {
        networkManager.accessToken = response.accessToken
        currentUser = response.user
        isAuthenticated = true
    }
}
