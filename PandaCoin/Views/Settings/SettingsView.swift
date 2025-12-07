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
    @State private var showLanguagePicker = false
    
    var body: some View {
        List {
            // MARK: - 语言设置
            Section {
                Button(action: { showLanguagePicker = true }) {
                    HStack {
                        Label(L10n.Settings.language, systemImage: "globe")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(languageManager.currentLanguage.displayName)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text(L10n.Settings.languageHint)
                    .font(.caption)
            }
            
            // MARK: - 关于
            Section {
                HStack {
                    Label(L10n.Settings.about, systemImage: "info.circle")
                    Spacer()
                    Text("v1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(L10n.Settings.settings)
        .navigationBarTitleDisplayMode(.inline)
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
                                    .foregroundColor(.primary)
                                
                                if language != .system {
                                    Text(language.localizedName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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

#Preview {
    NavigationView {
        SettingsView()
    }
}
