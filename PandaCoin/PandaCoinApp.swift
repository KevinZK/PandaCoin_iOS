//
//  PandaCoinApp.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI

@main
struct PandaCoinApp: App {
    init() {
        // 打印配置信息
        AppConfig.printConfiguration()
        
        // 配置全局外观
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
    
    private func setupAppearance() {
        // 完全不使用 UINavigationBarAppearance
        // 让 SwiftUI 使用系统默认的导航栏行为
        // 只设置 tint 颜色
        UINavigationBar.appearance().tintColor = UIColor(Theme.bambooGreen)
        
        // 设置导航栏标题颜色（旧API，但更可靠）
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(Theme.text)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(Theme.text)
        ]
    }
}
