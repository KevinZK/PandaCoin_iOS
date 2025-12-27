//
//  AppSettings.swift
//  PandaCoin
//
//  应用设置管理器 - 管理用户偏好设置
//

import Foundation
import SwiftUI
import Combine

/// 首页布局模式
enum HomeLayoutMode: String, CaseIterable, Identifiable {
    case classic = "classic"    // 经典模式（语音按钮）
    case chat = "chat"          // 对话模式（聊天）

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .classic: return "经典模式"
        case .chat: return "对话模式"
        }
    }

    /// 描述
    var description: String {
        switch self {
        case .classic: return "语音按钮 + 资产图表"
        case .chat: return "与熊猫财务官对话记账"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .classic: return "mic.circle.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        }
    }

    /// 对应的页面索引
    var pageIndex: Int {
        switch self {
        case .classic: return 0
        case .chat: return 1
        }
    }
}

/// 应用设置管理器
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let homeLayoutKey = "HomeLayoutMode"

    /// 首页布局模式
    @Published var homeLayoutMode: HomeLayoutMode {
        didSet {
            saveSettings()
        }
    }

    private init() {
        // 从 UserDefaults 读取保存的设置
        if let savedMode = UserDefaults.standard.string(forKey: homeLayoutKey),
           let mode = HomeLayoutMode(rawValue: savedMode) {
            homeLayoutMode = mode
        } else {
            // 默认使用对话模式
            homeLayoutMode = .chat
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(homeLayoutMode.rawValue, forKey: homeLayoutKey)
        UserDefaults.standard.synchronize()
    }
}
