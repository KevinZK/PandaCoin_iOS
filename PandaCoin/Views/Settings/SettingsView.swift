//
//  SettingsView.swift
//  PandaCoin
//
//  Created by kevin on 2025/12/7.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var appSettings = AppSettings.shared
    @State private var showLanguagePicker = false
    @State private var showHomeLayoutPicker = false
    
    var body: some View {
        List {
            // MARK: - 个人资料头部
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.cardGradient)
                            .frame(width: 64, height: 64)
                        Text("🐼")
                            .font(.system(size: 32))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("私人财务官用户")
                            .font(AppFont.body(size: 18, weight: .bold))
                        Text("PandaCoin 专业版")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.bambooGreen)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - 财务管理
            Section("财务管理") {
                NavigationLink(destination: AutoPaymentListView()) {
                    HStack {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "calendar.badge.clock").foregroundColor(.green).font(.system(size: 14))
                        }
                        
                        Text("自动还款")
                            .foregroundColor(Theme.text)
                        
                        Spacer()
                    }
                }
            }
            
            // MARK: - 偏好设置
            Section("偏好设置") {
                // 首页布局
                Button(action: { showHomeLayoutPicker = true }) {
                    HStack {
                        ZStack {
                            Circle().fill(Theme.bambooGreen.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "rectangle.on.rectangle").foregroundColor(Theme.bambooGreen).font(.system(size: 14))
                        }

                        Text("首页布局")
                            .foregroundColor(Theme.text)

                        Spacer()

                        Text(appSettings.homeLayoutMode.displayName)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }

                // 语言设置
                Button(action: { showLanguagePicker = true }) {
                    HStack {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.1)).frame(width: 30, height: 30)
                            Image(systemName: "globe").foregroundColor(.blue).font(.system(size: 14))
                        }

                        Text(L10n.Settings.language)
                            .foregroundColor(Theme.text)

                        Spacer()

                        Text(languageManager.currentLanguage.displayName)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                    }
                }
            }
            
            // MARK: - 关于与支持
            Section("关于与支持") {
                HStack {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.1)).frame(width: 30, height: 30)
                        Image(systemName: "info.circle").foregroundColor(.orange).font(.system(size: 14))
                    }
                    Text(L10n.Settings.about)
                    Spacer()
                    Text("v1.0.0")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.1)).frame(width: 30, height: 30)
                        Image(systemName: "heart.fill").foregroundColor(.purple).font(.system(size: 14))
                    }
                    Text("评价我们")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
            }
            
            // MARK: - 退出登录
            Section {
                Button(role: .destructive, action: {
                    AuthService.shared.logout()
                }) {
                    HStack {
                        Spacer()
                        Text(L10n.Auth.logout)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.Settings.settings)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.Common.done) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(selectedLanguage: $languageManager.currentLanguage)
        }
        .sheet(isPresented: $showHomeLayoutPicker) {
            HomeLayoutPickerView(selectedMode: $appSettings.homeLayoutMode)
        }
    }
}

// MARK: - 首页布局选择器视图
struct HomeLayoutPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMode: HomeLayoutMode

    var body: some View {
        NavigationView {
            List {
                ForEach(HomeLayoutMode.allCases) { mode in
                    Button(action: {
                        selectedMode = mode
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            // 图标
                            ZStack {
                                Circle()
                                    .fill(selectedMode == mode ? Theme.bambooGreen.opacity(0.15) : Theme.separator)
                                    .frame(width: 44, height: 44)
                                Image(systemName: mode.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(selectedMode == mode ? Theme.bambooGreen : Theme.textSecondary)
                            }

                            // 文字
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(AppFont.body(size: 16, weight: .medium))
                                    .foregroundColor(Theme.text)

                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Spacer()

                            // 选中标记
                            if selectedMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.bambooGreen)
                                    .font(.system(size: 22))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("首页布局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 语言选择器视图
struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: AppLanguage
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button(action: {
                        selectedLanguage = language
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.displayName)
                                    .foregroundColor(Theme.text)
                                
                                if language != .system {
                                    Text(language.localizedName)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Settings.language)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("设置页面 - CFO 风格") {
    NavigationView {
        SettingsView()
    }
}
