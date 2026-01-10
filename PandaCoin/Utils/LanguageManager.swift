//
//  LanguageManager.swift
//  PandaCoin
//
//  Created by kevin on 2025/12/7.
//

import Foundation
import SwiftUI
import Combine

/// 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"           // 跟随系统
    case zhHans = "zh-Hans"          // 简体中文
    case en = "en"                   // English
    case ja = "ja"                   // 日本語
    case ko = "ko"                   // 한국어
    case de = "de"                   // Deutsch
    case fr = "fr"                   // Français
    case es = "es"                   // Español
    
    var id: String { rawValue }
    
    /// 语言显示名称
    var displayName: String {
        switch self {
        case .system: return L10n.Language.system
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }
    
    /// 用于显示的本地化名称
    var localizedName: String {
        switch self {
        case .system: return L10n.Language.system
        case .zhHans: return L10n.Language.chinese
        case .en: return L10n.Language.english
        case .ja: return L10n.Language.japanese
        case .ko: return L10n.Language.korean
        case .de: return L10n.Language.german
        case .fr: return L10n.Language.french
        case .es: return L10n.Language.spanish
        }
    }
}

/// 语言管理器
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let languageKey = "AppLanguage"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
            applyLanguage()
        }
    }
    
    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
        applyLanguage()
    }
    
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }
    
    private func applyLanguage() {
        if currentLanguage == .system {
            // 移除自定义语言设置，使用系统语言
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            // 设置自定义语言
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        
        // 通知重新加载本地化
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    /// 获取当前实际使用的语言代码
    var effectiveLanguageCode: String {
        if currentLanguage == .system {
            if #available(iOS 16.0, *) {
                return Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                return Locale.current.languageCode ?? "en"
            }
        }
        return currentLanguage.rawValue
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
    /// 净资产需要刷新（记账、资产变动等）
    static let netWorthNeedsRefresh = Notification.Name("netWorthNeedsRefresh")
}
