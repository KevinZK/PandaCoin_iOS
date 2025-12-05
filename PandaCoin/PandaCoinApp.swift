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
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
