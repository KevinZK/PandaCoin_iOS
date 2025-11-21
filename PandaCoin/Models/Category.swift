//
//  Category.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

// MARK: - 分类模型
struct Category: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String     // emoji或SF Symbol名称
    let type: RecordType // 支出/收入
    let parentId: String? // 支持二级分类
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case type
        case parentId = "parent_id"
    }
}

// MARK: - 预设分类
struct DefaultCategories {
    // 支出分类
    static let expenseCategories = [
        ("餐饮", "🍜"),
        ("交通", "🚗"),
        ("购物", "🛍️"),
        ("娱乐", "🎮"),
        ("医疗", "💊"),
        ("住房", "🏠"),
        ("教育", "📚"),
        ("通讯", "📱"),
        ("运动", "⚽️"),
        ("美容", "💄"),
        ("旅行", "✈️"),
        ("宠物", "🐱"),
        ("其他", "📦")
    ]
    
    // 收入分类
    static let incomeCategories = [
        ("工资", "💰"),
        ("奖金", "🎁"),
        ("理财", "📈"),
        ("兼职", "💼"),
        ("红包", "🧧"),
        ("其他", "💵")
    ]
}
