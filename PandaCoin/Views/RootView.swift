//
//  RootView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authService = AuthService.shared

    var body: some View {
        // 不再强制登录，直接显示主界面
        // 用户可以在 Settings 中选择登录
        DashboardView()
    }
}

#Preview {
    RootView()
}
