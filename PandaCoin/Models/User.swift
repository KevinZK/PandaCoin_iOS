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
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case avatar
        case createdAt  // 后端返回的是驼峰命名
        case updatedAt  // 后端返回的是驼峰命名
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
