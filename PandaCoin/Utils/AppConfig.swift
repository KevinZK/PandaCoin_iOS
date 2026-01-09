//
//  AppConfig.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/05.
//

import Foundation

// MARK: - 环境配置
enum AppEnvironment {
    case development  // 开发环境（模拟器）
    case staging      // 真机调试环境
    case production   // 生产环境
    
    // 当前环境
    static var current: AppEnvironment {
        #if DEBUG
        // 在调试模式下，检测是否是真机
        #if targetEnvironment(simulator)
        return .development
        #else
        return .staging
        #endif
        #else
        return .production
        #endif
    }
}

// MARK: - 应用配置
struct AppConfig {
    // MARK: - API配置
    
    /// API基础URL
    static var apiBaseURL: String {
        switch AppEnvironment.current {
        case .development:
            // 模拟器使用localhost
            return "http://localhost:3001/api"
            
        case .staging:
            // 真机调试：使用Mac的局域网IP地址
            // 🔧 修改这里为你Mac的实际IP地址
            // 在Mac终端运行: ifconfig | grep "inet " | grep -v 127.0.0.1
            // 或者在系统设置 -> 网络 中查看
            return "http://192.168.199.142:3001/api"  // ⚠️ 替换为你的Mac IP
            
        case .production:
            // 生产环境：使用实际的服务器地址
            return "https://api.pandacoin.com/api"
        }
    }
    
    /// 当前环境名称
    static var environmentName: String {
        switch AppEnvironment.current {
        case .development:
            return "开发环境"
        case .staging:
            return "真机调试"
        case .production:
            return "生产环境"
        }
    }
    
    /// 是否启用日志
    static var loggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// API请求超时时间（秒）
    static let requestTimeout: TimeInterval = 30
    
    /// 是否允许HTTP连接（非HTTPS）
    static var allowInsecureConnections: Bool {
        AppEnvironment.current != .production
    }
}

// MARK: - 网络配置助手
extension AppConfig {
    /// 获取Mac本机IP地址提示信息
    static var localIPHint: String {
        """
        📱 真机调试配置说明：
        
        1. 确保iPhone和Mac连接到同一WiFi网络
        2. 在Mac终端运行以下命令获取IP地址：
           ifconfig | grep "inet " | grep -v 127.0.0.1
        3. 或在 系统设置 -> 网络 中查看Mac的IP地址
        4. 将IP地址更新到 AppConfig.swift 的 staging 环境配置中
        5. 确保后端服务器监听在 0.0.0.0 而不是 localhost
        
        当前配置的API地址: \(apiBaseURL)
        当前环境: \(environmentName)
        """
    }
    
    /// 打印当前配置信息
    static func printConfiguration() {
        print("""
        
        ═══════════════════════════════════════
        🐼 PandaCoin 配置信息
        ═══════════════════════════════════════
        环境: \(environmentName)
        API地址: \(apiBaseURL)
        日志: \(loggingEnabled ? "开启" : "关闭")
        超时: \(requestTimeout)秒
        允许HTTP: \(allowInsecureConnections ? "是" : "否")
        ═══════════════════════════════════════
        
        """)
    }
}



