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
        Group {
            if authService.isAuthenticated {
                DashboardView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    RootView()
}
