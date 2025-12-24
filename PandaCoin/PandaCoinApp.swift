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
        // 配置导航栏样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.background)
        appearance.shadowColor = .clear
        
        // 设置大标题颜色（Large Title）
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Theme.text)
        ]
        // 设置普通标题颜色
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.text)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // 导航栏按钮颜色
        UINavigationBar.appearance().tintColor = UIColor(Theme.bambooGreen)
    }
}
