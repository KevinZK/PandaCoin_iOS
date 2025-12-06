//
//  MainTabView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(L10n.TabBar.home, systemImage: "house.fill")
                }
                .tag(0)
            
            RecordsListView()
                .tabItem {
                    Label(L10n.TabBar.records, systemImage: "list.bullet")
                }
                .tag(1)
            
            BudgetView()
                .tabItem {
                    Label("预算", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            StatisticsView()
                .tabItem {
                    Label(L10n.TabBar.statistics, systemImage: "chart.bar.fill")
                }
                .tag(3)
            
            AccountsView()
                .tabItem {
                    Label(L10n.TabBar.accounts, systemImage: "creditcard.fill")
                }
                .tag(4)
        }
        .accentColor(Theme.bambooGreen)
    }
}

#Preview {
    MainTabView()
}
