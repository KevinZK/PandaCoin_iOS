//
//  AutoPaymentService.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/25.
//

import Foundation
import Combine

class AutoPaymentService: ObservableObject {
    static let shared = AutoPaymentService()
    
    @Published var autoPayments: [AutoPayment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - 获取所有自动扣款配置
    
    func fetchAutoPayments() -> AnyPublisher<[AutoPayment], APIError> {
        isLoading = true
        errorMessage = nil
        
        return networkManager.request(
            endpoint: "/auto-payments",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
        .handleEvents(
            receiveOutput: { [weak self] (payments: [AutoPayment]) in
                DispatchQueue.main.async {
                    self?.autoPayments = payments
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
    
    // MARK: - 获取单个自动扣款配置
    
    func fetchAutoPayment(id: String) -> AnyPublisher<AutoPayment, APIError> {
        networkManager.request(
            endpoint: "/auto-payments/\(id)",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
    }
    
    // MARK: - 创建自动扣款配置
    
    func createAutoPayment(_ request: CreateAutoPaymentRequest) -> AnyPublisher<AutoPayment, APIError> {
        networkManager.request(
            endpoint: "/auto-payments",
            method: "POST",
            body: request,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (payment: AutoPayment) in
            DispatchQueue.main.async {
                self?.autoPayments.append(payment)
                self?.autoPayments.sort { $0.dayOfMonth < $1.dayOfMonth }
            }
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - 更新自动扣款配置
    
    func updateAutoPayment(id: String, request: UpdateAutoPaymentRequest) -> AnyPublisher<AutoPayment, APIError> {
        networkManager.request(
            endpoint: "/auto-payments/\(id)",
            method: "PUT",
            body: request,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (payment: AutoPayment) in
            DispatchQueue.main.async {
                if let index = self?.autoPayments.firstIndex(where: { $0.id == id }) {
                    self?.autoPayments[index] = payment
                    self?.autoPayments.sort { $0.dayOfMonth < $1.dayOfMonth }
                }
            }
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - 删除自动扣款配置
    
    func deleteAutoPayment(id: String) -> AnyPublisher<Void, APIError> {
        networkManager.request(
            endpoint: "/auto-payments/\(id)",
            method: "DELETE",
            body: nil as String?,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (_: EmptyResponse) in
            DispatchQueue.main.async {
                self?.autoPayments.removeAll { $0.id == id }
            }
        })
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 切换启用状态
    
    func toggleAutoPayment(id: String) -> AnyPublisher<AutoPayment, APIError> {
        networkManager.request(
            endpoint: "/auto-payments/\(id)/toggle",
            method: "PATCH",
            body: nil as String?,
            requiresAuth: true
        )
        .handleEvents(receiveOutput: { [weak self] (payment: AutoPayment) in
            DispatchQueue.main.async {
                if let index = self?.autoPayments.firstIndex(where: { $0.id == id }) {
                    self?.autoPayments[index] = payment
                }
            }
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - 手动执行扣款
    
    func executeAutoPayment(id: String) -> AnyPublisher<AutoPaymentExecutionResult, APIError> {
        networkManager.request(
            endpoint: "/auto-payments/\(id)/execute",
            method: "POST",
            body: nil as String?,
            requiresAuth: true
        )
    }
    
    // MARK: - 获取执行日志
    
    func fetchLogs(paymentId: String, limit: Int = 20) -> AnyPublisher<[AutoPaymentLog], APIError> {
        networkManager.request(
            endpoint: "/auto-payments/\(paymentId)/logs?limit=\(limit)",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
    }
    
    // MARK: - 计算月供
    
    func calculateMonthlyPayment(
        principal: Double,
        annualRate: Double,
        termMonths: Int
    ) -> AnyPublisher<MonthlyPaymentCalculation, APIError> {
        networkManager.request(
            endpoint: "/auto-payments/utils/calculate-monthly-payment?principal=\(principal)&annualRate=\(annualRate)&termMonths=\(termMonths)",
            method: "GET",
            body: nil as String?,
            requiresAuth: true
        )
    }
    
    // MARK: - 本地计算月供（等额本息）
    
    static func calculateMonthlyPaymentLocally(
        principal: Double,
        annualRate: Double,
        termMonths: Int
    ) -> MonthlyPaymentCalculation {
        if annualRate == 0 {
            let monthly = principal / Double(termMonths)
            return MonthlyPaymentCalculation(
                monthlyPayment: monthly,
                totalPayment: principal,
                totalInterest: 0
            )
        }
        
        let monthlyRate = annualRate / 100 / 12
        let factor = pow(1 + monthlyRate, Double(termMonths))
        let monthlyPayment = (principal * monthlyRate * factor) / (factor - 1)
        let totalPayment = monthlyPayment * Double(termMonths)
        let totalInterest = totalPayment - principal
        
        return MonthlyPaymentCalculation(
            monthlyPayment: (monthlyPayment * 100).rounded() / 100,
            totalPayment: (totalPayment * 100).rounded() / 100,
            totalInterest: (totalInterest * 100).rounded() / 100
        )
    }
}
