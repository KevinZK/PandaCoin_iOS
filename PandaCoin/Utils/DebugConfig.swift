//
//  DebugConfig.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation

#if DEBUG
/// Debug模式配置
enum DebugConfig {
    
    // MARK: - 测试账号
    enum TestAccount {
        static let email = "test@pandacoin.com"
        static let password = "123456"
        static let name = "测试用户"
    }
    
    // MARK: - API配置
    enum API {
        // 是否使用模拟数据
        static let useMockData = false
        
        // 请求延迟（秒）
        static let requestDelay: TimeInterval = 0
        
        // 是否打印详细日志
        static let verboseLogging = true
    }
    
    // MARK: - UI配置
    enum UI {
        // 是否显示Debug信息
        static let showDebugInfo = true
        
        // 是否启用网格辅助线
        static let showGridOverlay = false
    }
    
    // MARK: - 功能开关
    enum Features {
        // 是否跳过引导页
        static let skipOnboarding = true
        
        // 是否自动登录
        static let autoLogin = false
        
        // 是否启用AI模拟数据
        static let useAIMockData = true
    }
}
#endif
