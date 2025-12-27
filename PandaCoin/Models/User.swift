//
//  User.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let avatar: String?
    let createdAt: Date
    let updatedAt: Date
    let defaultExpenseAccountId: String?
    let defaultExpenseAccountType: String?  // "ACCOUNT" 或 "CREDIT_CARD"
    let defaultIncomeAccountId: String?
    let defaultIncomeAccountType: String?  // "ACCOUNT"（收入只能进入账户，不能进入信用卡）

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case avatar
        case createdAt
        case updatedAt
        case defaultExpenseAccountId
        case defaultExpenseAccountType
        case defaultIncomeAccountId
        case defaultIncomeAccountType
    }
}

// MARK: - 认证相关
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String?
}

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String?
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken
        case tokenType
        case user
    }
}

// MARK: - 默认账户相关
enum DefaultAccountType: String, Codable {
    case account = "ACCOUNT"
    case creditCard = "CREDIT_CARD"
}

struct SetDefaultAccountRequest: Codable {
    let accountId: String
    let accountType: String
}

struct DefaultExpenseAccountResponse: Codable {
    let type: String?
    let account: Asset?
    let creditCard: CreditCard?
}

struct RecommendedAccountResponse: Codable {
    let matches: [CreditCard]
    let recommended: CreditCard?
}
