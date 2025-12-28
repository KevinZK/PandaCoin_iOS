//
//  AppSettings.swift
//  PandaCoin
//
//  应用设置管理器 - 管理用户偏好设置
//

import Foundation
import SwiftUI
import Combine

/// 应用设置管理器
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private init() {
        // 初始化设置
    }
}
